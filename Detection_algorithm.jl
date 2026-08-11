#Data loading
function extract_measured_synthetic_data!(filename)
    load_data = Dict{Int, Any}()
    k = 1
    key = 1
    for k in 1:330
        filepath = "$(filename)/$(k).csv"
        data = CSV.read(filepath, _DF.DataFrame, delim=',')
        load_data[key] = data
        key += 1
    end
    return load_data
end

loaded_data = extract_measured_synthetic_data!("Smart_Meter_data_Fluvius_low_PF_varying_setpoints")
country = "Belgium"
train_range = 1:672
test_range = 673:2976
#Detection of PV
function sunlight_hours(solar_irradiance, loaded_data, range, threshold1, threshold2)
    timestep_list_pv = []
    timestep_list_no_pv = []
    building_list = []
    sunlight_hours = []
    non_sunlight_hours = []
    for (i, irradiance) in enumerate(solar_irradiance)
        if irradiance > threshold1
            push!(timestep_list_pv, i)
        elseif irradiance > threshold2
            push!(timestep_list_no_pv, i)
        end
        if irradiance > 0.05
            push!(sunlight_hours, i)
        end
        if irradiance < 0.01
            push!(non_sunlight_hours, i)
        end
    end
    for (key, data) in loaded_data
        p_columns = filter(col -> startswith(String(col), "P_tot"), names(data))
        phase = parse(Int, match(r"\d+$", String(p_columns[1])).match)
        Ptot = data[:, Symbol("P_tot$(phase)")]*1e4
        idx = intersect(range, timestep_list_pv)
        idx_no_pv = intersect(range, timestep_list_no_pv)
        Ptot_pv = Ptot[idx]
        Ptot_no_pv = Ptot[idx_no_pv]
        mean_P_nopv = mean(Ptot_no_pv)
        mean_P_pv = mean(Ptot_pv)
        if 2*mean_P_pv < mean_P_nopv
            push!(building_list, key)
        end
    end
    return sunlight_hours, non_sunlight_hours, building_list
end
solar_irradiance_year = extract_solar_irradiance!(country) #data loaded in kW/m2 from PVGIS.com (originally per hour/ cubic interpolated to 15min)
solar_irradiance = solar_irradiance_year[14593:23424]
sunlight_timesteps, non_sunlight_timesteps, building_list = sunlight_hours(solar_irradiance, loaded_data,1:2976, 0.2, 0.1) #kW/m2
println(length(building_list))
building_keys_int = sort(collect(building_list))
building_keys = _DF.DataFrame(building=building_keys_int)

#Extract data for PV buildings
function separate_PV_households!(loaded_data, building_keys)
    PV_data = Dict{Int, Any}()
    for (key, data) in loaded_data
        if key in building_keys
            PV_data[key] = Dict{String, Any}()
            PV_data[key]["PV_setpoint"] = data[1, :PV_setpoint]
            p_columns = filter(col -> startswith(String(col), "P_pv"), names(data))
            phase = parse(Int, match(r"\d+$", String(p_columns[1])).match)
            PV_data[key]["phase"] = phase
            PV_data[key]["Qtot"] = data[:, Symbol("Q_tot$(phase)")]
            PV_data[key]["Ptot"] = data[:, Symbol("P_tot$(phase)")]
            PV_data[key]["Stot"] = sqrt.(PV_data[key]["Ptot"].^2 .+ PV_data[key]["Qtot"].^2)
            PV_data[key]["V1"] = data[:, :V1]
            PV_data[key]["V2"] = data[:, :V2]
            PV_data[key]["V3"] = data[:, :V3]
            PV_data[key]["V4"] = data[:, :V4]
            PV_data[key]["V1_noiseless"] = data[:, :V1_noiseless]
            PV_data[key]["V2_noiseless"] = data[:, :V2_noiseless]
            PV_data[key]["V3_noiseless"] = data[:, :V3_noiseless]
            PV_data[key]["V4_noiseless"] = data[:, :V4_noiseless]
            #PV_data[key]["Q/P"] = PV_data[key]["Qtot"] ./ PV_data[key]["Ptot"]
            #PV_data[key]["Q/V"] = PV_data[key]["Qtot"] ./ PV_data[key]["V$(phase)"]
            #PV_data[key]["P/S"] = PV_data[key]["Ptot"] ./ (PV_data[key]["Ptot"].^2 .+ PV_data[key]["Qtot"].^2).^(0.5)
            #PV_data[key]["P/V"] = PV_data[key]["Ptot"] ./ PV_data[key]["V$(phase)"]
            PV_data[key]["P_pv"] = data[:, Symbol("P_pv$(phase)")]
            PV_data[key]["Q_pv"] = data[:, Symbol("Q_pv$(phase)")]
            PV_data[key]["S_rated"] = data[1, Symbol("S_rated")]
            #PV_data[key]["Q_pv/P_pv"] = PV_data[key]["Q_pv"] ./ PV_data[key]["P_pv"]
        end
    end
    return PV_data
end

PV_households_data = separate_PV_households!(loaded_data, building_keys_int)

#Clustering to distinguish between Volt-based or PF-based control
function elbow_method(X, max_k) #Might have to run this like 50 times each to make sure the it is not luck
    costs = Float64[]
    for k in 1:max_k
        r = kmeans_restart!(X, k)
        push!(costs, sum(r.costs))
    end
    ks = collect(1:max_k)
    k_norm = (ks .- minimum(ks)) ./ (maximum(ks) - minimum(ks))
    cost_norm = (costs .- minimum(costs)) ./ (maximum(costs) - minimum(costs))
    p1 = [k_norm[1], cost_norm[1]]
    p2 = [k_norm[end], cost_norm[end]]
    distances = Float64[]
    for i in eachindex(k_norm)
        p = [k_norm[i], cost_norm[i]]
        # distance from point to line
        num = abs((p2[2]-p1[2])*p[1] - (p2[1]-p1[1])*p[2] + p2[1]*p1[2] - p2[2]*p1[1])
        den = sqrt((p2[2]-p1[2])^2 + (p2[1]-p1[1])^2)
        push!(distances, num / den)
    end
    best_k = argmax(distances)
    println(best_k)
    return costs, best_k
end

function feature_extraction_3!(PV_households_data, range, sunlight_timesteps)
    PF_PQ = Float64[]
    PF_QV = Float64[]
    PF_PQV = Float64[]
    PF_PV = Float64[]
    house = Int[]
    for (key, data) in PV_households_data
        push!(house, key)
        P_net = data["Ptot"]*1e4
        #export_index = findall(P_net .<= quantile(P_net, 0.33)) #33% of the data during Summer should approx. to sunlight hours
        export_index = sunlight_timesteps[P_net[sunlight_timesteps] .< quantile(P_net[sunlight_timesteps], 0.7)]
        phase = data["phase"]
        #idx = intersect(intersect(range, export_index), sunlight_timesteps)
        idx = intersect(range, export_index)
        data_P1 = Float64.(data["Ptot"][idx].*1e4)
        data_Q1 = Float64.(data["Qtot"][idx]*1e4)
        data_V1 = Float64.(data["V$(phase)"][idx])

        #P-Q correlation during low P values (high PV activity)
        push!(PF_PQV, cor(data_P1, data_Q1))

        #P-V correlation during low P values (high PV activity)
        push!(PF_PV, cor(data_P1, data_V1))

        #Q-V correlation during low P values (high PV activity)
        idx_Q = findall(data_Q1 .<= quantile(data_Q1, 0.3)) #Looks at the lowest 50% of Q (makes VoltVar stand out)
        data_Q = data_Q1[idx_Q]
        data_V_Q = data_V1[idx_Q]
        push!(PF_QV, cor(data_Q, data_V_Q))
        
        #Q-P correlation during low P values (high PV activity)
        data_P_Q = data_P1[idx_Q] #Looks at lowest 25% of Q (makes PF distinct from VoltWatt, as PF Q-values should be much higher during high PV-activety)
        push!(PF_PQ, cor(data_P_Q, data_Q))
    end
    corr_matrix = hcat(PF_PQ, PF_QV, PF_PV, PF_PQV)'
    corr_matrix[isnan.(corr_matrix)] .= 0.0
    df = _DF.DataFrame(corr_matrix, Symbol.(house))
    return df
end

function kmeans_restart!(X, k; runs=50)
    best_result = nothing
    best_cost = Inf
    for _ in 1:runs
        r = kmeans(X, k)
        costs = r.costs
        total_cost = sum(costs)
        if total_cost < best_cost
            best_result = r
            best_cost = total_cost
        end
    end
    return best_result
end

function clustering!(PV_households_data, range, sunlight_timesteps; Nr_clusters=2)
    feat_df = feature_extraction_3!(PV_households_data, range, sunlight_timesteps)
    X = Matrix(feat_df)
    result = kmeans_restart!(X, Nr_clusters, runs=50)
    clusters = result.assignments
    pv_labels = [PV_households_data[parse(Int,key)]["PV_setpoint"] for key in names(feat_df)]
    df = _DF.DataFrame(key=names(feat_df), cluster=clusters, PV_setpoint=pv_labels)
    counts = _DF.combine(_DF.groupby(df, [:cluster, :PV_setpoint]), _DF.nrow => :count)
    table = _DF.unstack(counts, :PV_setpoint, :count)
    building_assignment = _DF.DataFrame(key=names(feat_df), cluster=clusters, likelihood = result.costs, PV_setpoint=pv_labels)
    lowest_cost_keys_per_cluster = Vector{Vector{Any}}(undef, Nr_clusters)
    for c in 1:Nr_clusters
        cluster_rows = building_assignment[building_assignment.cluster .== c, :]
        sorted_rows = sort(cluster_rows, :likelihood)
        n_select = floor(Int, size(sorted_rows, 1) / 2)
        keys = sorted_rows.key[1:n_select]
        lowest_cost_keys_per_cluster[c] = keys
    end

    return table, result, building_assignment, lowest_cost_keys_per_cluster
end

function extract_PF_cluster1(lowest_cost_keys_per_cluster, PV_households_data, test_range, sunlight_timesteps; export_threshold=0.6)
    R2_score_total = []
    building_law = _DF.DataFrame(building = Int[], cluster = Int[], R2_PQ = Float64[], R2_VQ = Float64[], R2_PV = Float64[], control_law = String[], true_control_law = String[])
    Random.seed!(1234)
    for cluster_idx in eachindex(lowest_cost_keys_per_cluster)
        cluster = lowest_cost_keys_per_cluster[cluster_idx]
        R2_PQ = []
        R2_VQ = []
        R2_VP = []
        for key in cluster
            key = parse(Int, key)
            data = PV_households_data[key]
            true_control_law = data["PV_setpoint"]
            P_net = data["Ptot"]*1e4
            phase = data["phase"]
            V = data["V$(phase)"]
            export_index = sunlight_timesteps[P_net[sunlight_timesteps] .< quantile(P_net[sunlight_timesteps], export_threshold)]
            test_idx = intersect(test_range, export_index)
            data_P_test = Float64.(data["Ptot"][test_idx].*1e4)
            data_Q_test = Float64.(data["Qtot"][test_idx].*1e4)
            data_V_test = V[test_idx]
            
            #Calculate R2_PQ (fixed PF control)
            P_Q_dataframe_test = _DF.DataFrame(
                P = data_P_test,
                Q = data_Q_test
            )
            model = lm(@formula(Q~P), P_Q_dataframe_test)
            Qhat = GLM.predict(model, P_Q_dataframe_test)
            r2_PQ = 1 - sum((data_Q_test .- Qhat).^2)/sum((data_Q_test .- mean(data_Q_test)).^2)
            push!(R2_PQ, r2_PQ)

            #Calculate R2_VQ (VoltVar control)
            model = loess(data_V_test, data_Q_test, span=0.5)
            Qhat = Loess.predict(model, data_V_test)
            r2_VQ = 1 - sum((data_Q_test .- Qhat).^2)/sum((data_Q_test .- mean(data_Q_test)).^2)
            push!(R2_VQ, r2_VQ)

            #Calculate R2_PQ (VoltWatt control)
            model = loess(data_V_test, data_P_test, span = 0.5)
            Phat = Loess.predict(model, data_V_test)
            r2_VP = 1 - sum((data_P_test .- Phat).^2)/sum((data_P_test .- mean(data_P_test)).^2)
            push!(R2_VP, r2_VP)
            score = [r2_PQ, r2_VQ, r2_VP]
            control_law = ["PF", "VoltVar", "VoltWatt"][argmax(score)]
            push!(building_law, (key, cluster_idx, r2_PQ, r2_VQ, r2_VP, control_law, true_control_law))
        end
        push!(R2_score_total, (cluster_idx, median(R2_PQ), median(R2_VQ), median(R2_VP)))
    end
    PF_group = []
    non_PF_group = []
    confidence = []
    for (cluster_idx, R2_PF, R2_VV, R2_VW) in R2_score_total
        confidence_score_PF = R2_PF - max(R2_VV, R2_VW)
        confidence_score_volt = max(R2_VV, R2_VW) - R2_PF
        if R2_PF > max(R2_VV, R2_VW) && confidence_score_PF > 0.1
            push!(PF_group, cluster_idx)
            push!(confidence, (cluster_idx, confidence_score_PF))
        elseif confidence_score_volt > 0.1
            push!(non_PF_group, cluster_idx)
            push!(confidence, (cluster_idx, confidence_score_volt))
        else
            cluster_laws = building_law.control_law[building_law.cluster .== x, :]
            likely_law = mode(cluster_laws)
            if likely_law == "PF"
                push!(PF_group, cluster_idx)
                push!(confidence, (cluster_idx, confidence_score_PF))
            else
                push!(non_PF_group, cluster_idx)
                push!(confidence, (cluster_idx, confidence_score_volt))
            end
        end
    end
    return non_PF_group, confidence, R2_score_total, building_law
end

Costs, Nr_clusters = elbow_method(Matrix(feature_extraction_3!(PV_households_data, train_range, sunlight_timesteps)), 10)
table, result, building_assignment, lowest_cost_keys_per_cluster = clustering!(PV_households_data, test_range, sunlight_timesteps; Nr_clusters=Nr_clusters)
not_PF_cluster, confidence, all_score, building_law = extract_PF_cluster1(lowest_cost_keys_per_cluster, PV_households_data, test_range, sunlight_timesteps)

#Curvefitting to distinguish between VoltVAr and VoltWatt control
function fit_models_P4(signal, range, sunlight_timesteps; high_V_threshold_for_P=0.8, high_V_threshold=0.6, low_V_threshold=0.4)
    Ptot = signal["Ptot"]
    Qtot = signal["Qtot"]
    V = signal["V$(signal["phase"])"]

    high_idx_P = intersect(findall(V .> quantile(V, high_V_threshold_for_P)), sunlight_timesteps)
    high_idx_Q = intersect(findall(V .> quantile(V, high_V_threshold)), sunlight_timesteps)
    low_idx_Q = intersect(findall(V .< quantile(V, low_V_threshold)), sunlight_timesteps)

    Q1_lower = Qtot[intersect(range, low_idx_Q)]*1e4
    V1_lower = V[intersect(range, low_idx_Q)]
    idx_Q_lower = findall(Q1_lower .<= quantile(Q1_lower, 0.3))
    Q2_lower_a = Q1_lower[idx_Q_lower]
    V2_lower_a = V1_lower[idx_Q_lower]
    V2_lower = Float64[]
    Q2_lower = Float64[]
    for v in unique(V2_lower_a)
        idx = findall(==(v), V2_lower_a)
        sorted_idx = idx[sortperm(Q2_lower_a[idx])]
        nkeep = ceil(Int, length(sorted_idx) / 2)
        keep_idx = sorted_idx[1:nkeep]

        append!(V2_lower, V2_lower_a[keep_idx])
        append!(Q2_lower, Q2_lower_a[keep_idx])
    end

    P1_higher = Ptot[intersect(range, high_idx_P)]*1e4
    Q1_higher = Qtot[intersect(range, high_idx_Q)]*1e4
    V1_higher = V[intersect(range, high_idx_Q)]
    V1_higher_P = V[intersect(range, high_idx_P)]
    idx_Q_higher = findall(Q1_higher .>= quantile(Q1_higher, 0.7))
    idx_P_higher = findall(P1_higher .<= quantile(P1_higher, 0.2))
    P2_higher = P1_higher[idx_P_higher]
    Q2_higher_a = Q1_higher[idx_Q_higher]
    V2_higher_a = V1_higher[idx_Q_higher]
    V2_higher = Float64[]
    Q2_higher = Float64[]
    for v in unique(V2_higher_a)
        idx = findall(==(v), V2_higher_a)
        sorted_idx = idx[sortperm(Q2_higher_a[idx])]
        nkeep = ceil(Int, length(sorted_idx) / 5)
        keep_idx = sorted_idx[1:nkeep]

        append!(V2_higher, V2_higher_a[keep_idx])
        append!(Q2_higher, Q2_higher_a[keep_idx])
    end


    V3_higher = V1_higher_P[idx_P_higher]
    NP = length(P2_higher)
    NQ = length(Q2_higher) + length(Q2_lower)
    wQ = 2*(NQ + NP) / NQ
    wP = (NQ + NP) / NP

    model1_lower = loess(V2_lower, Q2_lower, span=0.5) #Seemed the best span (higher span is more smoothing, while lower span is more variability in fits)
    model1_higher = loess(V2_higher, Q2_higher, span=0.5)
    Qhat_VV_lower = predict(model1_lower, V2_lower)
    Qhat_VV_higher = predict(model1_higher, V2_higher)
    res_VV_lower = Q2_lower - Qhat_VV_lower
    res_VV_lower_norm = res_VV_lower ./ std(Q2_lower)
    res_VV_higher = Q2_higher - Qhat_VV_higher
    res_VV_higher_norm = res_VV_higher ./ std(Q2_higher)
    res_VV_Q_norm = vcat(res_VV_lower_norm, res_VV_higher_norm)

    Phat_VV_higher = fill(mean(P2_higher), length(P2_higher))
    res_VV_P_higher = P2_higher - Phat_VV_higher
    res_VV_P_norm = res_VV_P_higher ./ std(P2_higher)
    RMSE_VV = sqrt((wQ*sum(res_VV_Q_norm.^2) + wP*sum(res_VV_P_norm.^2)) / (wQ*NQ + wP*NP))

    Qhat_VW_lower = fill(mean(Q2_lower), length(Q2_lower))
    Qhat_VW_higher = fill(mean(Q2_higher), length(Q2_higher))
    res_VW_lower = Q2_lower - Qhat_VW_lower
    res_VW_lower_norm = res_VW_lower ./ std(Q2_lower)
    res_VW_higher = Q2_higher - Qhat_VW_higher
    res_VW_higher_norm = res_VW_higher ./ std(Q2_higher)
    res_VW_Q_norm = vcat(res_VW_lower_norm, res_VW_higher_norm)

    model2_higher = loess(V3_higher, P2_higher, span=0.5)
    Phat_VW_higher = predict(model2_higher, V3_higher)
    res_VW_P_higher = P2_higher - Phat_VW_higher
    res_VW_P_norm = res_VW_P_higher ./ std(P2_higher)
    res_all_VW = vcat(2 .* res_VW_Q_norm, res_VW_P_norm)
    RMSE_VW = sqrt((wQ*sum(res_VW_Q_norm.^2) + wP*sum(res_VW_P_norm.^2)) / (wQ*NQ + wP*NP))

    return RMSE_VV, RMSE_VW
end

function distinction_based_on_RMSE(household_data, building_index, cluster_index, range, sunlight_timesteps)
    estimated_list = []
    result_list = []
    total_VV = 0
    total_VW = 0
    score_VV = 0
    score_VW = 0
    total_score = 0
    total_buildings = 0
    rmse_dict = Dict{Int, Vector{Float64}}()
    first_keys = building_index[in.(building_index.cluster, Ref(cluster_index)), :]
    keys_to_include = first_keys.key
    wrongly_estimated_houses = []
    for (key, value) in household_data
        if string(key) in keys_to_include
            total_buildings += 1
            if value["PV_setpoint"] == "VoltVAr"
                total_VV += 1
            elseif value["PV_setpoint"] == "VoltWatt"
                total_VW += 1
            end
            rmse_VV, rmse_VW = fit_models_P4(value, range, sunlight_timesteps)
            rmse_dict[key] = [rmse_VV, rmse_VW]
            if rmse_VW < rmse_VV
                push!(estimated_list, (key, "VoltWatt"))
            elseif rmse_VV < rmse_VW
                push!(estimated_list, (key, "VoltVAr"))
            else
                push!(estimated_list, (key, "Unclear"))
            end
        end
    end
    for (key, setpoint) in estimated_list
        actual_setpoint = [household_data[key]["PV_setpoint"]]
        push!(result_list, (key, setpoint, actual_setpoint))
        if setpoint in actual_setpoint
            total_score += 1
            if setpoint == "VoltVAr"
                score_VV += 1
            elseif setpoint == "VoltWatt"
                score_VW += 1
            end
        else
            push!(wrongly_estimated_houses, key)
            println("Household $key: Estimated setpoint = $setpoint, Actual setpoint = $actual_setpoint", " RMSEs: ", rmse_dict[key])
        end
    end
    println("Total score: ", total_score, " out of ", total_buildings)
    println("Score VV: ", score_VV, "/", total_VV)
    println("Score VW: ", score_VW, "/", total_VW)
    return wrongly_estimated_houses
end

wrongly_estimated_houses = distinction_based_on_RMSE(PV_households_data, building_assignment, not_PF_cluster, test_range, sunlight_timesteps)

#Test to see why wrongly estimated buildings are wrong
function plot_wrongly_identified_buildings(PV_households_data, house, sunlight_timesteps, non_sunlight_timesteps)
    PV_setpoint = PV_households_data[house]["PV_setpoint"]
    plot1 = plot(xlabel = "Voltage", ylabel = "Reactive Power", title="Household $(house) $(PV_setpoint)", label=false)
    plot2 = plot(xlabel = "Voltage", ylabel = "Active Power", title="Household $(house) $(PV_setpoint)", label=false)
    plot3 = plot(xlabel = "Voltage", ylabel = "Reactive Power", title="PV Household $(house) $(PV_setpoint)", label=false)
    plot4 = plot(xlabel = "Voltage", ylabel = "Active Power", title="PV Household $(house) $(PV_setpoint)", label=false)
    phase = PV_households_data[house]["phase"]
    S_rated = PV_households_data[house]["S_rated"]
    P = PV_households_data[house]["Ptot"][sunlight_timesteps]*1e4
    Q = PV_households_data[house]["Qtot"][sunlight_timesteps]*1e4
    P_pv = PV_households_data[house]["P_pv"][sunlight_timesteps]*1e4
    Q_pv = PV_households_data[house]["Q_pv"][sunlight_timesteps]*1e4
    Q_noPV = PV_households_data[house]["Qtot"][non_sunlight_timesteps]*1e4
    Q_pv_noPV = PV_households_data[house]["Q_pv"][non_sunlight_timesteps]*1e4
    scatter!(plot1,PV_households_data[house]["V$(phase)"][intersect(1:2976, sunlight_timesteps)], Q)
    scatter!(plot1, PV_households_data[house]["V$(phase)"][intersect(1:2976, non_sunlight_timesteps)], Q_noPV, alpha = 0.5, label="Non-sunlight")
    scatter!(plot2,PV_households_data[house]["V$(phase)"][intersect(1:2976, sunlight_timesteps)], P)
    scatter!(plot3,PV_households_data[house]["V$(phase)"][intersect(1:2976, sunlight_timesteps)], Q_pv)
    scatter!(plot3, PV_households_data[house]["V$(phase)"][intersect(1:2976, non_sunlight_timesteps)], Q_pv_noPV, alpha = 0.5, label="Non-sunlight")
    scatter!(plot4,PV_households_data[house]["V$(phase)"][intersect(1:2976, sunlight_timesteps)], P_pv)
    display(plot1)
    display(plot2)
    display(plot3)
    display(plot4)
end

plot_wrongly_identified_buildings(PV_households_data, 309, sunlight_timesteps, non_sunlight_timesteps)

function correlation_plots_PF_identification(PV_households_data, range, PV_setpoint; export_threshold=0.2, high_V_threshold=0.7, low_V_threshold=0.3)
    corr_total = []
    PQ_corr = []
    PV_corr = []
    QV_corr = []
    PQV_corr = []
    plot1 = plot(xlabel = "house", ylabel = "correlation of $(PV_setpoint)", label=false)
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == PV_setpoint
            data = PV_households_data[key]
            P_net = data["Ptot"]*1e4
            phase = data["phase"]
            V = data["V$(phase)"]
            export_index = findall(P_net .< quantile(P_net, export_threshold))
            high_idx = findall(V .> quantile(V, high_V_threshold))
            low_idx = findall(V .< quantile(V, low_V_threshold))
            net_timestamps = vcat(low_idx, high_idx)
            idx1 = intersect(range, net_timestamps)
            idx = intersect(idx1, export_index) #Looks at points when voltage is extreme within the month where there is sufficient PV_production
            data_P1 = Float64.(data["Ptot"][idx].*1e4)
            data_Q1 = Float64.(data["Qtot"][idx]*1e4)
            data_V1 = Float64.(V[idx])
            idx_Q = findall(data_Q1 .<= quantile(data_Q1, 0.1)) #Looks at lowest 10% of Q values
            idx_P = findall(data_P1 .<= quantile(data_P1, 0.2)) #Looks at lowest 20% of P values
            data_Q = data_Q1[idx_Q]
            data_P = data_P1[idx_P]
            data_V_P = data_V1[idx_P]
            data_V_Q = data_V1[idx_Q]
            data_P_Q = data_P1[idx_Q]
            data_PV = data_P1
            data_QV = data_Q1
            push!(PV_corr, cor(data_V_P, data_P))
            push!(QV_corr, cor(data_V_Q, data_Q))
            push!(PQ_corr, cor(data_P_Q, data_Q))
            push!(PQV_corr, cor(data_PV, data_QV))
        end
    end
    plot!(plot1, 1:length(PV_corr), PV_corr, label="P/V")
    plot!(plot1, 1:length(QV_corr), QV_corr, label="Q/V")
    plot!(plot1, 1:length(PQ_corr), PQ_corr, label="Q/P")
    plot!(plot1, 1:length(PQV_corr), PQV_corr, label="(P/V)/(Q/V)")
    push!(corr_total, (median(abs.(PQ_corr)), median(abs.(PV_corr)), median(abs.(QV_corr)), median(abs.(PQV_corr))))
    println(corr_total)
    display(plot1)
end

correlation_plots_PF_identification(PV_households_data, test_range, "VoltVAr")
correlation_plots_PF_identification(PV_households_data, test_range, "VoltWatt")
correlation_plots_PF_identification(PV_households_data, test_range, "PF_fixed")
correlation_plots_PF_identification(PV_households_data, test_range, "WattVAr")

function correlation_plots_VV_identification(PV_households_data, range, PV_setpoint, sunlight_timesteps; export_threshold=0.33, high_V_threshold_P= 0.9, high_V_threshold=0.8, low_V_threshold=0.2)
    corr_total = []
    QV_corr_low = []
    QV_corr_high = []
    PV_corr_high = []
    plot1 = plot(xlabel = "house", ylabel = "correlation of $(PV_setpoint)", label=false)
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == PV_setpoint
            data = PV_households_data[key]
            P_net = data["Ptot"]*1e4
            phase = data["phase"]
            V = data["V$(phase)"]
            export_index = intersect(findall(P_net .< quantile(P_net, export_threshold)), sunlight_timesteps)
            export_index_low_V = intersect(findall(P_net .< quantile(P_net, 0.7)), sunlight_timesteps)
            high_idx_Q = intersect(range, intersect(export_index, findall(V .> quantile(V, high_V_threshold))))
            low_idx_Q = intersect(range, intersect(export_index_low_V, findall(V .< quantile(V, low_V_threshold))))
            high_idx_P = intersect(range, intersect(export_index, findall(V .> quantile(V, high_V_threshold_P))))

            data_P_high1 = Float64.(data["Ptot"][high_idx_P].*1e4)
            data_V_high1 = Float64.(V[high_idx_P])
            V2_higher_P = Float64[]
            P2_higher = Float64[]
            for v in unique(data_V_high1)
                idx = findall(==(v), data_V_high1)
                sorted_idx = idx[sortperm(data_P_high1[idx])]
                nkeep = ceil(Int, length(sorted_idx) / 5)
                keep_idx = sorted_idx[1:nkeep]

                append!(V2_higher_P, data_V_high1[keep_idx])
                append!(P2_higher, data_P_high1[keep_idx])
            end
            push!(PV_corr_high, cor(V2_higher_P, P2_higher))

            data_Q_high1 = Float64.(data["Qtot"][high_idx_Q]*1e4)
            data_V_highQ1 = Float64.(V[high_idx_Q])
            V2_higher_Q = Float64[]
            Q2_higher = Float64[]
            for v in unique(data_V_highQ1)
                idx = findall(==(v), data_V_highQ1)
                sorted_idx = idx[sortperm(data_Q_high1[idx], rev=true)]
                nkeep = ceil(Int, length(sorted_idx) / 1)
                keep_idx = sorted_idx[1:nkeep]

                append!(V2_higher_Q, data_V_highQ1[keep_idx])
                append!(Q2_higher, data_Q_high1[keep_idx])
            end
            push!(QV_corr_high, cor(V2_higher_Q, Q2_higher))

            data_Q_low1 = Float64.(data["Qtot"][low_idx_Q]*1e4)
            data_V_lowQ1 = Float64.(V[low_idx_Q])
            V2_lower_Q = Float64[]
            Q2_lower = Float64[]
            for v in unique(data_V_lowQ1)
                idx = findall(==(v), data_V_lowQ1)
                sorted_idx = idx[sortperm(data_Q_low1[idx])]
                nkeep = ceil(Int, length(sorted_idx) / 5)
                keep_idx = sorted_idx[1:nkeep]

                append!(V2_lower_Q, data_V_lowQ1[keep_idx])
                append!(Q2_lower, data_Q_low1[keep_idx])
            end
            push!(QV_corr_low, cor(V2_lower_Q, Q2_lower))
        end
    end
    plot!(plot1, 1:length(PV_corr_high), PV_corr_high, label="P/V (High V)")
    plot!(plot1, 1:length(QV_corr_high), QV_corr_high, label="Q/V (High V)")
    plot!(plot1, 1:length(QV_corr_low), QV_corr_low, label="Q/V (Low V)")
    push!(corr_total, (median(abs.(QV_corr_high)), median(abs.(PV_corr_high)), median(abs.(QV_corr_low))))
    println(corr_total)
    display(plot1)
end

correlation_plots_VV_identification(PV_households_data, test_range, "VoltVAr", sunlight_timesteps)
correlation_plots_VV_identification(PV_households_data, test_range, "VoltWatt", sunlight_timesteps)
