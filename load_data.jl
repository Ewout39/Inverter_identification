function extract_loading!()
    loaded_data = Dict{Int, Any}()
    column_names_P = ["PLoad_$(i)" for i in 1:330]
    column_names_Q = ["QLoad_$(i)" for i in 1:330]
    column_names = vcat(column_names_P, column_names_Q)
    building_list = Int[]
    load_data = _DF.DataFrame((column_name => [0.0 for _ in 1:35136] for column_name in column_names)...)
    k = 1
    i = 1
    while i <= 330
        data = nothing
        if !(k in [6, 10, 30, 32, 59, 81, 82, 94, 104, 105, 141, 144, 185, 188, 193, 202, 206, 212, 221, 264, 283, 284, 287, 294, 307, 347, 351, 353, 370, 383, 398, 406, 412, 451, 452, 476, 478, 485, 505, 510, 530, 549, 554, 561, 571, 580, 658, 676, 679, 695, 697, 710, 727, 734, 738, 740, 753, 770, 795, 808, 809, 842, 846, 852, 866, 872, 890, 893])
            filepath = "c:\\Users\\u0181580\\OneDrive - KU Leuven\\2e_master\\thesis\\datasets\\1000_houses_dataset\\Code_data\\powerdf_clean_test\\$(k).csv"
            try
                data = CSV.read(filepath, _DF.DataFrame, delim=',')
            catch e
                #@warn "File not found: $filepath"
                filepath = "C:\\Users\\u0181580\\OneDrive - KU Leuven\\2e_master\\thesis\\datasets\\1000_houses_dataset\\Code_data\\powerdf_clean_train\\$(k-581).csv"
                data = CSV.read(filepath, _DF.DataFrame, delim=',')
            end
            if (sum(data[:, :P])*0.25 >= 2000 && sum(data[:,:P])*0.25 <= 12000) && data[1, :PV] == 0 #Slovak = 3321kWh/yr https://www.odyssee-mure.eu/publications/efficiency-by-sector/households/electricity-consumption-dwelling.html
                range = 14593:15660
                zero_fraction = mean(data[range, :P] .== 0)
                if zero_fraction <= 0.2
                    loaded_data[i] = data
                    for j in 6:35141
                        load_data[j-5, "PLoad_$(i)"] = loaded_data[i][j, :P]
                        load_data[j-5, "QLoad_$(i)"] = loaded_data[i][j, :Q]
                    end
                    i += 1
                    push!(building_list, k)
                end
            end
        end
        k += 1
    end
    return load_data, building_list #kW and kVAr
end

function Yearly_consumption_profiles!()
    #Around 7% of Belgian households have heat pumps installed in 2024 https://ehpa.org/news-and-resources/press-releases/heat-pump-sales-14-times-greater-in-lead-countries/
    #around 10% of Belgian households have electric vehicles in 2025 https://alternative-fuels-observatory.ec.europa.eu/general-information/news/belgium-ev-growth-continues-2025-2026-set-break-new-records
    #heatpump 33, both 33, EV: 50
    yearly_consumption_noPV = _DF.DataFrame(EAN_ID = Int[], Yearly_consumption_kWh = Float64[], Type = String[])
    yearly_consumption_EV_noPV = _DF.DataFrame(EAN_ID = Int[], Yearly_consumption_kWh = Float64[], Type = String[])
    yearly_consumption_WP_noPV = _DF.DataFrame(EAN_ID = Int[], Yearly_consumption_kWh = Float64[], Type = String[])
    yearly_consumption_WP_EV_noPV = _DF.DataFrame(EAN_ID = Int[], Yearly_consumption_kWh = Float64[], Type =  String[])

    datapath_noPV = DATA_DIR*"/P6269_Open_Data_geen_ZP.csv"
    datapath_EV_noPV = DATA_DIR*"/P6269_Open_Data_EV_geen_ZP.csv"
    datapath_WP_noPV = DATA_DIR*"/P6269_Open_Data_WP_geen_ZP.csv"
    datapath_WP_EV_noPV = DATA_DIR*"/P6269_Open_Data_WP_EV_geen_ZP.csv"
    df_noPV = CSV.read(datapath_noPV, _DF.DataFrame)
    df_EV_noPV = CSV.read(datapath_EV_noPV, _DF.DataFrame)
    df_WP_noPV = CSV.read(datapath_WP_noPV, _DF.DataFrame)
    df_WP_EV_noPV = CSV.read(datapath_WP_EV_noPV, _DF.DataFrame)
    gdf = _DF.groupby(df_noPV, :EAN_ID)
    gdf_EV = _DF.groupby(df_EV_noPV, :EAN_ID)
    gdf_WP = _DF.groupby(df_WP_noPV, :EAN_ID)
    gdf_WP_EV = _DF.groupby(df_WP_EV_noPV, :EAN_ID)
    for (i, group) in enumerate(gdf)
        yearly_consumption = sum(group[:, :Volume_Afname_KWh] .- group[:, :Volume_Injectie_KWh]) #kWh/year
        type = group[!, :Contract_Categorie][1]
        push!(yearly_consumption_noPV, (EAN_ID = group[1, :EAN_ID], Yearly_consumption_kWh = yearly_consumption, Type = type))
    end
    for (i, group) in enumerate(gdf_EV)
        yearly_consumption = sum(group[:, :Volume_Afname_KWh] .- group[:, :Volume_Injectie_KWh]) #kWh/year
        type = group[!, :Contract_Categorie][1]
        push!(yearly_consumption_EV_noPV, (EAN_ID = group[1, :EAN_ID], Yearly_consumption_kWh = yearly_consumption, Type = type))
    end
    for (i, group) in enumerate(gdf_WP)
        yearly_consumption = sum(group[:, :Volume_Afname_KWh] .- group[:, :Volume_Injectie_KWh]) #kWh/year
        type = group[!, :Contract_Categorie][1]
        push!(yearly_consumption_WP_noPV, (EAN_ID = group[1, :EAN_ID], Yearly_consumption_kWh = yearly_consumption, Type = type))
    end
    for (i, group) in enumerate(gdf_WP_EV)
        yearly_consumption = sum(group[:, :Volume_Afname_KWh] .- group[:, :Volume_Injectie_KWh]) #kWh/year
        type = group[!, :Contract_Categorie][1]
        push!(yearly_consumption_WP_EV_noPV, (EAN_ID = group[1, :EAN_ID], Yearly_consumption_kWh = yearly_consumption, Type = type))
    end
    return yearly_consumption_noPV, yearly_consumption_EV_noPV, yearly_consumption_WP_noPV, yearly_consumption_WP_EV_noPV  
end

function yearly_consumption(df)
    _DF.combine(_DF.groupby(df, :EAN_ID)) do g
        _DF.DataFrame(
            EAN_ID = g.EAN_ID[1],
            Yearly_consumption_kWh = sum(g.Volume_Afname_KWh .- g.Volume_Injectie_KWh), 
            Afname = [g.Volume_Afname_KWh],
            Injectie = [g.Volume_Injectie_KWh])
    end
end

function extract_Fluvius_profiles!(DATA_DIR; seed=42)
    Random.seed!(seed)

    filter_range(df) = filter(r -> 2500 ≤ r.Yearly_consumption_kWh ≤ 12000, df)
    df_noPV      = CSV.read(joinpath(DATA_DIR, "P6269_Open_Data_geen_ZP.csv"), _DF.DataFrame)
    df_EV        = CSV.read(joinpath(DATA_DIR, "P6269_Open_Data_EV_geen_ZP.csv"), _DF.DataFrame)
    df_WP        = CSV.read(joinpath(DATA_DIR, "P6269_Open_Data_WP_geen_ZP.csv"), _DF.DataFrame)
    df_WP_EV     = CSV.read(joinpath(DATA_DIR, "P6269_Open_Data_WP_EV_geen_ZP.csv"), _DF.DataFrame)

    yc_noPV      = yearly_consumption(df_noPV)
    yc_EV        = yearly_consumption(df_EV)
    yc_WP        = yearly_consumption(df_WP)
    yc_WP_EV     = yearly_consumption(df_WP_EV)

    yc_noPV_f    = filter_range(yc_noPV)
    yc_EV_f      = filter_range(yc_EV)
    yc_WP_f      = filter_range(yc_WP)
    yc_WP_EV_f   = filter_range(yc_WP_EV)

    @assert _DF.nrow(yc_noPV_f)  >= 100 "Not enough noPV buildings"
    @assert _DF.nrow(yc_EV_f)    >= 90  "Not enough EV buildings"
    @assert _DF.nrow(yc_WP_f)    >= 70  "Not enough WP buildings"
    @assert _DF.nrow(yc_WP_EV_f) >= 70  "Not enough WP+EV buildings"

    function sample_rows(df, n::Int)
        idx = sample(1:_DF.nrow(df), n; replace=false)
        return df[idx, :]
    end

    sample_noPV  = sample_rows(yc_noPV_f, 100)
    sample_EV    = sample_rows(yc_EV_f, 90)
    sample_WP    = sample_rows(yc_WP_f, 70)
    sample_WP_EV = sample_rows(yc_WP_EV_f, 70)


    selected_all = vcat(sample_noPV, sample_EV, sample_WP, sample_WP_EV)
    return (
        noPV = sample_noPV,
        EV = sample_EV,
        WP = sample_WP,
        WP_EV = sample_WP_EV,
        all = selected_all
    )
end

function extract_Swiss_profiles!(DATA_DIR)
    good_profiles = []
    column_names_P = ["PLoad_$(i)" for i in 1:330]
    column_names_Q = ["QLoad_$(i)" for i in 1:330]
    column_names = vcat(column_names_P, column_names_Q)
    load_profiles = _DF.DataFrame((column_name => [0.0 for _ in 1:35136] for column_name in column_names)...)
    df_metadata = CSV.read(joinpath(DATA_DIR, "metadata.csv"), _DF.DataFrame)
    for row in eachrow(df_metadata)
        meter_type = row[Symbol("0_installation_type")]
        meter_id = Int(row[Symbol("0_meter_id")])
        if meter_type == "Single-family house"
            push!(good_profiles, meter_id)
        end
    end
    for row in eachrow(df_metadata)
        meter_type = row[Symbol("0_installation_type")]
        meter_id = Int(row[Symbol("0_meter_id")])
        if meter_type == "Apartment"
            push!(good_profiles, meter_id)
        end
    end
    i = 1
    for id in good_profiles
        if i == 331
            break
        end
        df_smart_meter = CSV.read(joinpath(DATA_DIR, "$(id).csv"), _DF.DataFrame)
        df_smart_meter.timestamp_utc = DateTime.(df_smart_meter.timestamp_utc,dateformat"yyyy-mm-dd HH:MM:SS+00:00")
        df_2024 = df_smart_meter[year.(df_smart_meter.timestamp_utc) .== 2023, :]
        range = 14500:23500
        if (any(ismissing, df_2024[range, "kWh_to_installation"])) || (any(ismissing, df_2024[range, "kWh_to_grid"])) || (any(ismissing, df_2024[range, "kvarh_to_installation"])) || (any(ismissing, df_2024[range,"kvarh_to_grid"]))
            continue
        elseif (any(isnan, df_2024[range, "kWh_to_installation"])) || (any(isnan, df_2024[range, "kWh_to_grid"])) || (any(isnan, df_2024[range, "kvarh_to_installation"])) || (any(isnan, df_2024[range,"kvarh_to_grid"]))
            continue
        end
        if sum(df_2024[range, "kWh_to_grid"] .> 0.025) > 10 #skips PV buildings
            continue
        end
        net_consumption_kWh = replace(coalesce.(df_2024[:,"kWh_to_installation"], 0.0), NaN => 0.0) .- replace(coalesce.(df_2024[:,"kWh_to_grid"], 0.0), NaN => 0.0)
        net_consumption_kvarh = replace(coalesce.(df_2024[:,"kvarh_to_installation"], 0.0), NaN => 0.0) .- replace(coalesce.(df_2024[:,"kvarh_to_grid"], 0.0), NaN => 0.0)
        if (2500 <= sum(net_consumption_kWh)) && (sum(net_consumption_kWh) <= 12000) #ensures buildings have acceptable annual consumption
            for j in 1:length(net_consumption_kWh)
                load_profiles[j, "PLoad_$(i)"] = net_consumption_kWh[j] *4
                load_profiles[j, "QLoad_$(i)"] = net_consumption_kvarh[j] *4
            end
            i += 1
        end
    end
    return load_profiles, df_metadata
end

function split_random_balanced(samples; n_groups=6, seed=42, group_size=55)
    Random.seed!(seed)
    noPV  = shuffle(samples.noPV)
    EV    = shuffle(samples.EV)
    WP    = shuffle(samples.WP)
    WP_EV = shuffle(samples.WP_EV)

    ranges = Dict(
        :EV => (11,14),
        :WP => (7,9),
        :WP_EV => (7,9)
    )

    groups = _DF.DataFrame[]

    remaining = Dict(
        :EV => copy(EV),
        :WP => copy(WP),
        :WP_EV => copy(WP_EV),
        :noPV => copy(noPV)
    )

    for g in 1:n_groups
        group_rows = _DF.DataFrame()
        for (cat, (minc, maxc)) in ranges
            avail = remaining[cat]
            count = rand(minc:maxc)
            count = min(count, _DF.nrow(avail))
            if count > 0
                append!(group_rows, avail[1:count, [:EAN_ID, :Afname, :Injectie]])
                remaining[cat] = avail[(count+1):end, :]
            end
        end

        remaining_slots = group_size - _DF.nrow(group_rows)
        avail_noPV = remaining[:noPV]
        take_noPV = min(remaining_slots, _DF.nrow(avail_noPV))
        if take_noPV > 0
            append!(group_rows, avail_noPV[1:take_noPV, [:EAN_ID, :Afname, :Injectie]])
            remaining[:noPV] = avail_noPV[(take_noPV+1):end, :]
        end

        remaining_slots = group_size - _DF.nrow(group_rows)
        if remaining_slots > 0
            leftover_rows = vcat(remaining[:EV], remaining[:WP], remaining[:WP_EV], remaining[:noPV])
            if _DF.nrow(leftover_rows) > 0
                take_leftover = min(remaining_slots, _DF.nrow(leftover_rows))
                append!(group_rows, leftover_rows[1:take_leftover, [:EAN_ID, :Afname, :Injectie]])
            end
        end

        shuffle!(group_rows)

        push!(groups, group_rows)
    end

    return groups
end

function recombine_groups_with_Q!(groups; Weibull = false)
    n_buildings = 330 
    n_rows = 35136

    buildings_ordered = vcat(groups...)

    column_names_P = ["PLoad_$(i)" for i in 1:n_buildings]
    column_names_Q = ["QLoad_$(i)" for i in 1:n_buildings]
    column_names = vcat(column_names_P, column_names_Q)
    load_data = _DF.DataFrame( (name => zeros(Float64, n_rows) for name in column_names)... )
    PF = Dict()
    for (i, ean) in enumerate(buildings_ordered.EAN_ID)
        Pvals = buildings_ordered.Afname[i] .- buildings_ordered.Injectie[i] #kWh per 15min
        @assert length(Pvals) == n_rows "Mismatch for EAN $(ean): $(length(Pvals))"
        load_data[!, "PLoad_$(i)"] = Pvals.*4 #kW

        Random.seed!(1000 + i)
        if Weibull
            alpha = 2
            beta = 4
            w_norm = rand(_DST.Beta(alpha, beta), n_rows)
            pf = 0.998 .- w_norm .* (0.998 - 0.8)
        else
            pf = rand(n_rows) .* (0.998 - 0.9) .+ 0.9  # random pf per timestep between 0.9 and 0.998
        end
        PF[i] = pf
        Qvals = Pvals.* 4 .* tan.(acos.(pf))
        load_data[!, "QLoad_$(i)"] = Qvals
    end

    return load_data, PF
end

function load_data!(dataset; weibull=false)
    if dataset == "Belgium"
        noPV, EV, WP, WP_EV, df_all = extract_Fluvius_profiles!(DATA_DIR)
        data = split_random_balanced((noPV=noPV, EV=EV, WP=WP, WP_EV=WP_EV), n_groups=6)
        load_profiles, PF = recombine_groups_with_Q!(data, Weibull=weibull)
        building_list = Int[]
        metadata = _DF.DataFrame()
    elseif dataset == "Slovakia"
        load_profiles, building_list = extract_loading!()
        PF = Dict()
        metadata = _DF.DataFrame()
    elseif dataset == "Swiss"
        load_profiles, metadata = extract_Swiss_profiles!(DATA_DIR_SWISS)
        building_list = Int[]
        PF = Dict()
    end
    return load_profiles, building_list, PF, metadata
end

function extract_solar_irradiance!(dataset)
    solar_irradiance_1h = _DF.DataFrame("Irradiance_kW_m2" => [0.0 for _ in 1:8784])
    solar_irradiance = _DF.DataFrame("Irradiance_kW_m2" => [0.0 for _ in 1:35136])
    if dataset == "Belgium"
        filepath = DATA_DIR * "/Irradiance_Profile_Belgium.csv"
    elseif dataset == "Slovakia"
        filepath = DATA_DIR * "/Irradiance_Profile_Slovakia.csv"
    elseif dataset == "Swiss"
        filepath = DATA_DIR * "/Irradiance_Profile_Swiss.csv"
    end
    data = CSV.read(filepath, _DF.DataFrame)
    for j in 1:(8792-8)
        solar_irradiance_1h[j, "Irradiance_kW_m2"] = parse(Float64, data[j+8, :Column10])

    end
    x = 1:length(solar_irradiance_1h[!, "Irradiance_kW_m2"])
    y = solar_irradiance_1h[!, "Irradiance_kW_m2"]
    itp = CubicSplineInterpolation(x, y)
    x_new = LinRange(1, length(y), 8784*4)
    solar_irradiance[!, "Irradiance_kW_m2"] = itp.(x_new)
    for i in 1:length(solar_irradiance[!, "Irradiance_kW_m2"])
        if solar_irradiance[i, "Irradiance_kW_m2"] < 0
            solar_irradiance[i, "Irradiance_kW_m2"] = 0.0
        end
    end
    return solar_irradiance[!, "Irradiance_kW_m2"]
end

function create_solar_profiles!(solar_irradiance, load_profiles, panel_peak_power)
    Nr_panels = []
    S_inverter = []
    P_daily = []
    column_names = ["Psolar_$(i)" for i in 1:330]
    solar_profile = _DF.DataFrame((column_name => [0.0 for _ in 1:35136] for column_name in column_names)...)
    for i in 1:330
        load_profile = load_profiles[!, "PLoad_$(i)"]
        yearly_consumption = sum(load_profile)*0.25 #kWh/year
        daily_consumption = yearly_consumption/365 #kWh/day
        push!(P_daily, (daily_consumption, yearly_consumption))
        peak_sun_hours = sum(solar_irradiance)*0.25/365 #kWh/m2/day=>h/day (Peak sun hours are the number of hours per day when the solar irradiance averages 1 kW/m2)
        #println(peak_sun_hours) #3.9788 h/day
        performance_factor = 0.8
        system_size = daily_consumption / (performance_factor*peak_sun_hours) #kW
        if system_size > 4.8 && yearly_consumption < 7000
            system_size = 4.8 #kW, to limit the system size to a realistic one for single phase residential buildings https://www.fluvius.be/nl/groene-energie/zonnepanelen/technische-aspecten/omvormer
        elseif system_size > 7.2
            system_size = 7.2
        end
        nr_panels = ceil(system_size / panel_peak_power) #number of panels needed
        S_inv = nr_panels * panel_peak_power
        for j in 1:35136
            PV_output = nr_panels * panel_peak_power * (solar_irradiance[j]/1) * performance_factor #KW, Irradiance in KW per m2 divided by 1 kW/m2 to get the relative irradiance, then multiplied by the performance factor to account for losses
            if PV_output > system_size
                PV_output = system_size
            end
            solar_profile[j, "Psolar_$(i)"] = PV_output
        end
        push!(Nr_panels, nr_panels)
        push!(S_inverter, S_inv)
    end
    return Nr_panels, solar_profile, P_daily, S_inverter
end

function initialize_empty_dict!()
    Result_dict = Dict{String, Dict{String, Any}}()
    return Result_dict
end

function add_to_dict!(Result_dict, res, repitition, math, PV_load)
    a_key = "Repitition_$(repitition)"
    alpha_dict = get!(Result_dict, a_key, Dict("Busses"=>Dict(), "Branches"=>Dict(), "Loads"=>Dict(), "Gen"=>Dict()))
    for (key, values) in res["solution"]["bus"]
        bus_key = string(key)
        bus_dict = get!(alpha_dict["Busses"], bus_key) do
            Dict(
                "V1" => Float64[],
                "V2" => Float64[],
                "V3" => Float64[],
                "V4" => Float64[],
            )
        end
        push!(bus_dict["V1"], sqrt(values["vr"][1]^2 + values["vi"][1]^2))
        push!(bus_dict["V2"], sqrt(values["vr"][2]^2 + values["vi"][2]^2))
        push!(bus_dict["V3"], sqrt(values["vr"][3]^2 + values["vi"][3]^2))
        push!(bus_dict["V4"], sqrt(values["vr"][4]^2 + values["vi"][4]^2))
    end
    for (key, values) in res["solution"]["branch"]
        branch_key = string(key)
        branch_dict = get!(alpha_dict["Branches"], branch_key) do
            Dict("line_loading_P1" => Float64[],
                 "line_loading_P2" => Float64[],
                 "line_loading_P3" => Float64[])
        end
        push!(branch_dict["line_loading_P1"], values["line_loading"][1])
        push!(branch_dict["line_loading_P2"], values["line_loading"][2])
        push!(branch_dict["line_loading_P3"], values["line_loading"][3])
    end
    for (key, values) in math["load"]
        load_index = values["index"]
        if load_index <= 55
            load_key = string(key)
            load_dict = get!(alpha_dict["Loads"], load_key) do
                Dict(
                    "P$(values["connections"][1])" => Float64[],
                    "Q$(values["connections"][1])" => Float64[],
                    "P_pv$(values["connections"][1])" => Float64[],
                    "P_pv_original$(values["connections"][1])" => Float64[],
                    "Q_pv$(values["connections"][1])" => Float64[],
                    "P_tot$(values["connections"][1])" => Float64[],
                    "Q_tot$(values["connections"][1])" => Float64[],
                    "S_rated" => Float64[],
                    "Phase" => Int[],
                    "key_PV" => Int[],
                    "PV_setpoint" => String[],
                    "PV_curve" => Vector{Vector{Tuple{Real,Real}}}(),
                    "bus_number" => Int[]
                )
            end
            push!(load_dict["P$(values["connections"][1])"], res["solution"]["load"][key]["pd"][1])
            push!(load_dict["Q$(values["connections"][1])"], res["solution"]["load"][key]["qd"][1])
            push!(load_dict["bus_number"], values["load_bus"])
            push!(load_dict["Phase"], values["connections"][1])
        else
            load_idx = values["non_PV_load_number"]
            load_key = string(load_idx)
            load_dict = get!(alpha_dict["Loads"], load_key) do
                Dict(
                    "P$(values["connections"][1])" => Float64[],
                    "Q$(values["connections"][1])" => Float64[],
                    "P_pv$(values["connections"][1])" => Float64[],
                    "P_pv_original$(values["connections"][1])" => Float64[],
                    "Q_pv$(values["connections"][1])" => Float64[],
                    "P_tot$(values["connections"][1])" => Float64[],
                    "Q_tot$(values["connections"][1])" => Float64[],
                    "S_rated" => Float64[],
                    "Phase" => Int[],
                    "key_PV" => Int[],
                    "PV_setpoint" => String[],
                    "PV_curve" => Vector{Vector{Tuple{Real,Real}}}(),
                    "bus_number" => Int[]
                )
            end
            push!(load_dict["P_pv_original$(values["connections"][1])"], values["pd_start"][1])
            push!(load_dict["P_pv$(values["connections"][1])"], res["solution"]["load"][key]["pd"][1])
            push!(load_dict["Q_pv$(values["connections"][1])"], res["solution"]["load"][key]["qd"][1])
            push!(load_dict["S_rated"], values["S_rated"])
            push!(load_dict["PV_setpoint"], values["PV_setpoint"])
            if values["PV_setpoint"] == "PF_fixed"
                push!(load_dict["PV_curve"], [(1.0, values["PF_value"])])
            elseif values["PV_setpoint"] == "WattVAr"
                vector = collect(zip(values["WattVAr_breakpoints"], values["WattVAr_Q_values"]))
                push!(load_dict["PV_curve"], vector)
            elseif values["PV_setpoint"] == "VoltWatt"
                vector = collect(zip(values["VW_breakpoints"], values["VW_P_values"]))
                push!(load_dict["PV_curve"], vector)
            elseif values["PV_setpoint"] == "VoltVAr"
                vector = collect(zip(values["VV_breakpoints"], values["VV_Q_values"]))
                push!(load_dict["PV_curve"], vector)
            end
            push!(load_dict["key_PV"], load_index)
        end
    end
    for (key, values) in math["load"]
        load_key = string(key)
        if values["index"] <= 55
            load_key = string(key)
            load_dict = get!(alpha_dict["Loads"], load_key) do
                    Dict(
                        "P$(values["connections"][1])" => Float64[],
                        "Q$(values["connections"][1])" => Float64[],
                        "P_pv$(values["connections"][1])" => Float64[],
                        "P_pv_original$(values["connections"][1])" => Float64[],
                        "Q_pv$(values["connections"][1])" => Float64[],
                        "P_tot$(values["connections"][1])" => Float64[],
                        "Q_tot$(values["connections"][1])" => Float64[],
                        "S_rated" => Float64[],
                        "Phase" => Int[],
                        "key_PV" => Int[],
                        "PV_setpoint" => String[],
                        "bus_number" => Int[]
                    )
            end
            P_tot = 0
            Q_tot = 0
            if load_key in PV_load
                P_tot = load_dict["P$(values["connections"][1])"][end] + load_dict["P_pv$(values["connections"][1])"][end]
                Q_tot = load_dict["Q$(values["connections"][1])"][end] + load_dict["Q_pv$(values["connections"][1])"][end]
            else
                P_tot = load_dict["P$(values["connections"][1])"][end]
                Q_tot = load_dict["Q$(values["connections"][1])"][end]
            end
            push!(load_dict["P_tot$(values["connections"][1])"], P_tot)
            push!(load_dict["Q_tot$(values["connections"][1])"], Q_tot)
        end
    end
    for (key, values) in res["solution"]["gen"]
        gen_key = string(key)
        gen_dict = get!(alpha_dict["Gen"], gen_key) do
            Dict(
                "P1" => Float64[],
                "P2" => Float64[],
                "P3" => Float64[],
                "Q1" => Float64[],
                "Q2" => Float64[],
                "Q3" => Float64[],
            )
        end
        push!(gen_dict["P1"], values["pg"][1])
        push!(gen_dict["P2"], values["pg"][2])
        push!(gen_dict["P3"], values["pg"][3])
        push!(gen_dict["Q1"], values["qg"][1])
        push!(gen_dict["Q2"], values["qg"][2])
        push!(gen_dict["Q3"], values["qg"][3]) 
    end
end

function create_directory!()
    dirpath = "C:\\Users\\u0181580\\OneDrive - KU Leuven\\PHD\\Julia\\Inverter_identification\\Smart_Meter_data"
    mkpath(dirpath)
    return dirpath
end

function store_data_results!(Result_dict)
    for (key, repitition_data) in Result_dict
        repitition = parse(Int, split(key, "_")[2])
        for (key_lds, load) in repitition_data["Loads"]
            phase = load["Phase"][1]
            load_number_orig = parse(Int, key_lds)
            noise_keys = ["P_tot$(phase)", "Q_tot$(phase)"]
            df = _DF.DataFrame()
            for (load_key, values) in load
                if length(load["PV_setpoint"]) > 0
                    data_to_store = ["S_rated", "PV_setpoint", "P_pv$(phase)", "Q_pv$(phase)", "P$(phase)", "Q$(phase)", "P_tot$(phase)", "Q_tot$(phase)", "PV_curve"]
                else
                    data_to_store = ["P$(phase)", "Q$(phase)", "P_tot$(phase)", "Q_tot$(phase)"]
                end
                if load_key in data_to_store
                    if load_key in noise_keys
                        values_noisy = add_noise!(load, load_key, load_number_orig)
                        df[!, load_key] = values_noisy
                        df[!, "$(load_key)_noiseless"] = values
                    else
                        df[!, load_key] = values
                    end
                end
                if load_key == "bus_number"
                    bus = repitition_data["Busses"][string(values[1])]
                    V1_noisy = add_noise!(bus, "V1", values[1])
                    V2_noisy = add_noise!(bus, "V2", values[1])
                    V3_noisy = add_noise!(bus, "V3", values[1])
                    V4_noisy = add_noise!(bus, "V4", values[1])
                    df[!, "V1"] = V1_noisy
                    df[!, "V2"] = V2_noisy
                    df[!, "V3"] = V3_noisy
                    df[!, "V4"] = V4_noisy
                    df[!, "V1_noiseless"] = bus["V1"]
                    df[!, "V2_noiseless"] = bus["V2"]
                    df[!, "V3_noiseless"] = bus["V3"]
                    df[!, "V4_noiseless"] = bus["V4"]
                end
            end
            load_number = 55*(repitition-1) + load_number_orig
            CSV.write(joinpath(dirpath, "$(load_number).csv"), df)
        end
    end
end

function add_noise!(load, noise_key, load_bus)
    max_volt_error = 0.005 #%
    max_p_error = 0.01 #%
    max_q_error = 2*max_p_error #%
    if noise_key in ["V1", "V2", "V3", "V4"]
        seed = 250
    else
        seed = 50
        phase = load["Phase"][1]
    end
    randRNG = [Random.seed!(seed+load_bus+100*i) for i in 1:length(load[noise_key])]

    σ_v_mult = 1/3*max_volt_error 
    σ_p_mult = 1/3*max_p_error    
    σ_q_mult = 1/3*max_q_error    

    if noise_key in ["V1", "V2", "V3", "V4"]
        v_dst = [_DST.Normal{Float64}(res, σ_v_mult*res) for res in load[noise_key]]   #probability distribution
        vm_meas = [Random.rand(randRNG[i], d) for (i,d) in enumerate(v_dst)]
        return vm_meas
    elseif noise_key == "P_tot$(phase)"
        pd_dst = [_DST.Normal{Float64}(res, σ_p_mult*res) for res in load[noise_key]]  #probability distribution
        pd_meas = [Random.rand(randRNG[i], d) for (i,d) in enumerate(pd_dst)]
        return pd_meas
    elseif noise_key == "Q_tot$(phase)"
        qd_dst = [_DST.Normal{Float64}(res, σ_q_mult*res) for res in load[noise_key]] #probability distribution
        qd_meas = [Random.rand(randRNG[i], d) for (i,d) in enumerate(qd_dst)]
        return qd_meas   
    end
end