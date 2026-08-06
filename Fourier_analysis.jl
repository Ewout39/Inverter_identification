#Data extraction
loaded_data = extract_measured_synthetic_data!()

sunlight_timesteps = sunlight_hours(solar_irradiance, 0.1, 2) #kW/m2

function separate_PV_households!(loaded_data)
    PV_data = Dict{Int, Any}()
    for (key, data) in loaded_data
        if "PV_setpoint" in names(data)
            PV_data[key] = Dict{String, Any}()
            PV_data[key]["PV_setpoint"] = data[1, :PV_setpoint]
            PV_data[key]["S_rated"] = data[1, :S_rated]
            p_columns = filter(col -> startswith(String(col), "P_pv"), names(data))
            phase = parse(Int, match(r"\d+$", String(p_columns[1])).match)
            PV_data[key]["phase"] = phase
            PV_data[key]["Qtot"] = data[:, Symbol("Q_tot$(phase)")]
            PV_data[key]["Ptot"] = data[:, Symbol("P_tot$(phase)")]
            PV_data[key]["S_tot"] = sqrt.(PV_data[key]["Ptot"].^2 .+ PV_data[key]["Qtot"].^2)
            PV_data[key]["V1"] = data[:, :V1]
            PV_data[key]["V2"] = data[:, :V2]
            PV_data[key]["V3"] = data[:, :V3]
            PV_data[key]["V4"] = data[:, :V4]
            PV_data[key]["Q/P"] = PV_data[key]["Qtot"] ./ PV_data[key]["Ptot"]
            PV_data[key]["Q/V"] = PV_data[key]["Qtot"] ./ PV_data[key]["V$(phase)"]
            PV_data[key]["P/S"] = PV_data[key]["Ptot"] ./ (PV_data[key]["Ptot"].^2 .+ PV_data[key]["Qtot"].^2).^(0.5)
            PV_data[key]["P/V"] = PV_data[key]["Ptot"] ./ PV_data[key]["V$(phase)"]
            PV_data[key]["P_pv"] = data[:, Symbol("P_pv$(phase)")]
            PV_data[key]["Q_pv"] = data[:, Symbol("Q_pv$(phase)")]
            PV_data[key]["Q_pv/P_pv"] = PV_data[key]["Q_pv"] ./ PV_data[key]["P_pv"]
            PV_data[key]["P_load"] = data[:, Symbol("P$(phase)")]
            PV_data[key]["Q_load"] = data[:, Symbol("Q$(phase)")]
        end
    end
    return PV_data
end

PV_households_data = separate_PV_households!(loaded_data)

total_nans_PS = sum(sum(isnan, household_data["P/S"]) for (_, household_data) in PV_households_data)
total_nans_QP = sum(sum(isnan, household_data["Q/P"]) for (_, household_data) in PV_households_data)
total_nans_QP_pv = sum(sum(isnan, household_data["Q_pv/P_pv"]) for (_, household_data) in PV_households_data)
total_inf_PS = sum(sum(isinf, household_data["P/S"]) for (_, household_data) in PV_households_data)
total_inf_QP = sum(sum(isinf, household_data["Q/P"]) for (_, household_data) in PV_households_data)
total_inf_QP_pv = sum(sum(isinf, household_data["Q_pv/P_pv"]) for (_, household_data) in PV_households_data)

function interpolate_nans(v::Vector{Float64})
    n = length(v)
    result = copy(v)  # avoid modifying original
    i = 1
    while i <= n
        if isnan(result[i])
            # find previous valid value
            prev_idx = findlast(isfinite, result[1:i-1])
            # find next valid value
            next_idx = findfirst(isfinite, result[i+1:end])
            if prev_idx === nothing && next_idx === nothing
                # all NaNs → replace with 0
                result[i] = 0.0
            elseif prev_idx === nothing
                # leading NaNs → use next valid value
                result[i] = result[next_idx + i]
            elseif next_idx === nothing
                # trailing NaNs → use previous valid value
                result[i] = result[prev_idx]
            else
                # interpolate as average of previous and next
                result[i] = (result[prev_idx] + result[next_idx + i]) / 2
            end
        end
        i += 1
    end
    return result
end

function interpolate_infs(v::Vector{Float64})
    n = length(v)
    result = copy(v)  # avoid modifying original
    i = 1
    while i <= n
        if isinf(result[i])
            # find previous valid value
            prev_idx = findlast(isfinite, result[1:i-1])
            # find next valid value
            next_idx = findfirst(isfinite, result[i+1:end])
            if prev_idx === nothing && next_idx === nothing
                # all NaNs → replace with 0
                result[i] = 0.0
            elseif prev_idx === nothing
                # leading NaNs → use next valid value
                result[i] = result[next_idx + i]
            elseif next_idx === nothing
                # trailing NaNs → use previous valid value
                result[i] = result[prev_idx]
            else
                # interpolate as average of previous and next
                result[i] = (result[prev_idx] + result[next_idx + i]) / 2
            end
        end
        i += 1
    end
    return result
end

for (key, household_data) in PV_households_data
    household_data["P/S"] = interpolate_nans(household_data["P/S"])
    household_data["Q/P"] = interpolate_nans(household_data["Q/P"])
    household_data["Q_pv/P_pv"] = interpolate_nans(household_data["Q_pv/P_pv"])
    household_data["P/S"] = interpolate_infs(household_data["P/S"])
    household_data["Q/P"] = interpolate_infs(household_data["Q/P"])
    household_data["Q_pv/P_pv"] = interpolate_infs(household_data["Q_pv/P_pv"])
end

list_PV = sort(collect(keys(PV_households_data)))

total_nans_PS = sum(sum(isnan, household_data["P/S"]) for (_, household_data) in PV_households_data)
total_nans_QP = sum(sum(isnan, household_data["Q/P"]) for (_, household_data) in PV_households_data)
total_nans_QP_pv = sum(sum(isnan, household_data["Q_pv/P_pv"]) for (_, household_data) in PV_households_data)
total_inf_PS = sum(sum(isinf, household_data["P/S"]) for (_, household_data) in PV_households_data)
total_inf_QP = sum(sum(isinf, household_data["Q/P"]) for (_, household_data) in PV_households_data)
total_inf_QP_pv = sum(sum(isinf, household_data["Q_pv/P_pv"]) for (_, household_data) in PV_households_data)

function extreme_voltage_index(PV_households_data, lower_percentile, higher_percentile) #have to finish still
    df_idx = _DF.DataFrame()
    for (key, household) in PV_households_data
        voltage = household["V$(household["phase"])"]
        high_idx = findall(voltage .> quantile(voltage, higher_percentile))
        low_idx = findall(voltage .< quantile(voltage, lower_percentile))
        df_idx[!, Symbol(key)] = [high_idx, low_idx]
    end
    return df_idx
end
extreme_v_idx = extreme_voltage_index(PV_households_data, 0.3, 0.7)

function net_export_index(PV_households_data)
    df_idx = _DF.DataFrame()
    for (key, household) in PV_households_data
        P_net = household["Ptot"]*1e4
        pv_idx = findall(P_net .<= quantile(P_net, 0.40))
        df_idx[!, Symbol(key)] = [pv_idx]
    end
    return df_idx
end
export_index = net_export_index(PV_households_data)

function no_pv_index(PV_households_data, threshold)
    df_idx = _DF.DataFrame()
    for (key, household) in PV_households_data
        P_net = household["Ptot"]*1e4
        pv_idx = findall(P_net .> quantile(P_net, threshold))
        df_idx[!, Symbol(key)] = [pv_idx]
    end
    return df_idx
end
no_pv_idx = no_pv_index(PV_households_data, 0.7)

#functions to show PV-data follows correct curve and is within limits
function visualize_wattvar_curve_2(PV_households_data, range, sunlight_timesteps, varP_curve, P_key, Q_key)
    x_curve = -first.(varP_curve)
    y_curve = last.(varP_curve)
    colors = palette(:tab10)
    i=0
    p = plot(
        x_curve,
        y_curve,
        xlabel = "Active Power",
        ylabel = "PV Reactive Power",
        title  = "PV Reactive Power vs Active Power",
        legend = false,
        grid   = true
    )
    idx = intersect(range, sunlight_timesteps)
    for (key, value) in PV_households_data
        if value["PV_setpoint"] == "WattVAr"
            i += 1
            S_rated = value["S_rated"][1]
            power_unit = 1e4
            phase = value["phase"]
            P_pv_data = value[P_key][idx] ./ S_rated .* power_unit
            Q_pv_data = value[Q_key][idx] ./ S_rated .* power_unit
            scatter!(p, P_pv_data, Q_pv_data, label="$key", color = colors[mod1(key, length(colors))], alpha = 0.3)
        end
    end
    display(p)
    println(i)
end
visualize_wattvar_curve_2(PV_households_data, 1:672, sunlight_timesteps, varP_curve, "P_pv", "Q_pv")

function visualize_voltvar_curve_2(PV_households_data, range, sunlight_timesteps, voltvar_curve, Q_key)
    #x_curve = first.(voltvar_curve)
    #y_curve = last.(voltvar_curve)
    p = plot(
        #x_curve,
        #y_curve,
        xlabel = "Voltage [pu]",
        ylabel = "PV Reactive Power [pu]",
        title  = "PV Reactive Power over Voltage",
        legend = true,
        grid   = true
    )
    #for i in voltvar_curve
    #    x_curve = first.(i)
    #    y_curve = last.(i)
    #    plot!(p, x_curve, y_curve)
    #end
    for (key, value) in PV_households_data
        if value["PV_setpoint"] == "VoltVAr"
            idx = intersect(range, sunlight_timesteps)
            power_unit = 1e4
            S_rated = value["S_rated"]
            phase = value["phase"]
            Q_pv_data1 = value[Q_key][idx] ./ S_rated .* power_unit #divide by S_rated to compare with voltvar curve
            #idx2 = findall(Q_pv_data1 .< quantile(Q_pv_data1, 0.2))
            voltage_data1 = value["V$(phase)_noiseless"][idx]
            voltage_data = voltage_data1
            Q_pv_data = Q_pv_data1
            scatter!(p, voltage_data, Q_pv_data, label="", alpha = 0.6)
        end
    end
    display(p)
end
visualize_voltvar_curve_2(PV_households_data, 1:2976, sunlight_timesteps, voltvar_curve, "Q_pv")

function visualize_PF_curve_2(PV_households_data, range, sunlight_timesteps, P_key, Q_key)
    p = plot(
        xlabel = "Voltage [pu]",
        ylabel = "PF [/]",
        title  = "PF vs Voltage",
        legend = false,
        grid   = true,
        ylim = (0.8, 1)
    )
    q = plot(
        xlabel = "Active Power",
        ylabel = "Reactive Power",
        title  = "Reactive Power vs Active Power",
        legend = false,
        grid   = true
    )
    #hline!(p, [PF_curve])
    #k = tan(acos(PF_curve))
    idx = intersect(range, sunlight_timesteps)
    for (key, value) in PV_households_data
        if value["PV_setpoint"] == "PF_fixed"
            phase = value["phase"]
            voltage_data = value["V$(phase)"][range]
            P_pv_data = value[P_key][range]*1e4
            Q_pv_data = value[Q_key][range]*1e4
            xmin = minimum(value[P_key][idx])
            xmax = maximum(value[P_key][idx])
            #x_curve = xmin:0.0000001:xmax
            #y_curve = -k .* x_curve
            #plot!(q, x_curve, y_curve, label="")
            PF = -P_pv_data ./ sqrt.(P_pv_data .^ 2 .+ Q_pv_data .^ 2)
            scatter!(p, voltage_data, PF, label="")
            scatter!(q, P_pv_data, Q_pv_data, label="")
        end
    end
    display(p)
    display(q)
end
visualize_PF_curve_2(PV_households_data, 1:2976, sunlight_timesteps, "P_pv", "Q_pv")

function visualize_voltwatt_curve_2(PV_households_data, range, sunlight_timesteps, P_key, Q_key)
    #x_curve = first.(VoltWatt_curve)
    #y_curve = -last.(VoltWatt_curve)
    p = plot(
        #x_curve,
        #y_curve,
        xlabel = "Voltage [pu]",
        ylabel = "PV Active Power [pu]",
        title  = "PV Active Power over Voltage",
        legend = true,
        grid   = true
    )
    q = plot(
        xlabel = "Voltage [pu]",
        ylabel = "PV Reactive Power [pu]",
        title  = "PV Reactive Power over Voltage",
        legend = false,
        grid   = true
    )
    for (key, value) in PV_households_data
        if value["PV_setpoint"] == "VoltWatt"
            idx = intersect(range, sunlight_timesteps)
            #idx = intersect(idx1, net_load_steps[!, Symbol(key)][1])
            power_unit = 1e4
            S_rated = value["S_rated"]
            phase = value["phase"]
            voltage_data1 = value["V$(phase)_noiseless"][idx]
            P_pv_data1 = value[P_key][idx] ./ S_rated .* power_unit
            Q_pv_data1 = value[Q_key][idx] ./ S_rated .* power_unit
            #idx2 = findall(P_pv_data1 .< quantile(P_pv_data1, 0.2))
            voltage_data = voltage_data1
            P_pv_data = P_pv_data1
            idx3 = findall(Q_pv_data1 .< quantile(Q_pv_data1, 0.2))
            Q_pv_data = Q_pv_data1[idx3]
            voltage_data2 = voltage_data1[idx3]
            scatter!(p, voltage_data, P_pv_data, label="", alpha = 0.3)
            scatter!(q, voltage_data2, Q_pv_data, label="", alpha = 0.3)
        end
    end
    display(p)
    display(q)
end
visualize_voltwatt_curve_2(PV_households_data, 1:2976, sunlight_timesteps, "P_pv", "Q_pv")

function test_under_rated_power(PV_households_data)
    for (key, value) in PV_households_data
        P_pv = value["P_pv"].*1e4
        Q_PV = value["Q_pv"].*1e4
        S_rated = value["S_rated"]
        S_calc = sqrt.(P_pv.^2 .+ Q_PV.^2)
        for i in 1:length(P_pv)
            if S_calc[i] > (S_rated + 0.01)
                println("Household $key exceeds rated power at time step $i with calculated S = $(S_calc[i]) and rated S = $S_rated")
            end
        end
    end
end
test_under_rated_power(PV_households_data)

function visualize_ppv_ptot(value, range, sunlight_timesteps)
    p = plot(xlabel = "time step", ylabel = "P_pv / P_tot", title = "P_pv and P_tot over time", label=true)
    idx = intersect(range, sunlight_timesteps)
    P_pv_data = value["P_pv"][idx]
    P_tot_data = value["Ptot"][idx]
    P_load = value["Ptot"][idx] - value["P_pv"][idx]
    plot!(p, idx, P_pv_data, label="P_pv")
    #plot!(p, idx, P_tot_data, label="P_tot")
    plot!(p, idx, P_load, label="P_load")
    display(p)
end
visualize_ppv_ptot(PV_households_data[231], 1:6800, sunlight_timesteps)

#functions to show net demand data in the same manner as PV-data
visualize_wattvar_curve_2(PV_households_data, 1:672, sunlight_timesteps, varP_curve, "Ptot", "Qtot")
visualize_voltvar_curve_2(PV_households_data, 1:672, sunlight_timesteps, voltvar_curve, "Qtot")
visualize_PF_curve_2(PV_households_data, 1:672, sunlight_timesteps, PF, "Ptot", "Qtot")
visualize_voltwatt_curve_2(PV_households_data, 1:672, sunlight_timesteps, VoltWatt_curve, "Ptot", "Qtot")

function visualization_PV_households!(PV_households_data, range)
    WattVAr_plots_PQ = plot(xlabel = "time step", ylabel = "Q/P", title = "WattVAr Control: Q/P over time", label=false)
    WattVAr_plots_QV = plot(xlabel = "time step", ylabel = "Q/V", title = "WattVAr Control: Q/V over time", label=false)
    WattVAr_plots_PS = plot(xlabel = "time step", ylabel = "P/S", title = "WattVAr Control: P/S over time", label=false)
    WattVAr_plots_PV = plot(xlabel = "time step", ylabel = "P/V", title = "WattVAr Control: P/V over time", label=false)
    VoltVAr_plots_PQ = plot(xlabel = "time step", ylabel = "Q/P", title = "VoltVAr Control: Q/P over time", label=false)
    VoltVAr_plots_QV = plot(xlabel = "time step", ylabel = "Q/V", title = "VoltVAr Control: Q/V over time", label=false)
    VoltVAr_plots_PS = plot(xlabel = "time step", ylabel = "P/S", title = "VoltVAr Control: P/S over time", label=false)
    VoltVAr_plots_PV = plot(xlabel = "time step", ylabel = "P/V", title = "VoltVAr Control: P/V over time", label=false)
    PF_plots_PQ = plot(xlabel = "time step", ylabel = "Q/P", title = "PF Control: Q/P over time", label=false)
    PF_plots_QV = plot(xlabel = "time step", ylabel = "Q/V", title = "PF Control: Q/V over time", label=false)
    PF_plots_PS = plot(xlabel = "time step", ylabel = "P/S", title = "PF Control: P/S over time", label=false)
    PF_plots_PV = plot(xlabel = "time step", ylabel = "P/V", title = "PF Control: P/V over time", label=false)
    VoltWatt_plots_PQ = plot(xlabel = "time step", ylabel = "Q/P", title = "VoltWatt Control: Q/P over time", label=false)
    VoltWatt_plots_QV = plot(xlabel = "time step", ylabel = "Q/V", title = "VoltWatt Control: Q/V over time", label=false)
    VoltWatt_plots_PS = plot(xlabel = "time step", ylabel = "P/S", title = "VoltWatt Control: P/S over time", label=false)
    VoltWatt_plots_PV = plot(xlabel = "time step", ylabel = "P/V", title = "VoltWatt Control: P/V over time", label=false)
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == "WattVAr"
            for i in range
                 if data["Q/P"][i] > 2000
                    println(key, i)
                end
            end
            plot!(WattVAr_plots_PQ, data["Q/P"][range], label=false)
            plot!(WattVAr_plots_QV, data["Q/V"][range], label=false)
            plot!(WattVAr_plots_PS, data["P/S"][range], label=false)
            plot!(WattVAr_plots_PV, data["P/V"][range], label=false)
        elseif data["PV_setpoint"] == "VoltVAr"
            plot!(VoltVAr_plots_PQ, data["Q/P"][range], label=false)
            plot!(VoltVAr_plots_QV, data["Q/V"][range], label=false)
            plot!(VoltVAr_plots_PS, data["P/S"][range], label=false)
            plot!(VoltVAr_plots_PV, data["P/V"][range], label=false)
        elseif data["PV_setpoint"] == "PF_fixed"
            plot!(PF_plots_PQ, data["Q/P"][range], label=false)
            plot!(PF_plots_QV, data["Q/V"][range], label=false)
            plot!(PF_plots_PS, data["P/S"][range], label=false)
            plot!(PF_plots_PV, data["P/V"][range], label=false)
        elseif data["PV_setpoint"] == "VoltWatt"
            plot!(VoltWatt_plots_PQ, data["Q/P"][range], label=false)
            plot!(VoltWatt_plots_QV, data["Q/V"][range], label=false)
            plot!(VoltWatt_plots_PS, data["P/S"][range], label=false)
            plot!(VoltWatt_plots_PV, data["P/V"][range], label=false)
        end
    end
    display(WattVAr_plots_PQ)
    display(WattVAr_plots_QV)
    display(WattVAr_plots_PS)
    display(WattVAr_plots_PV)
    display(VoltVAr_plots_PQ)
    display(VoltVAr_plots_QV)
    display(VoltVAr_plots_PS)
    display(VoltVAr_plots_PV)
    display(PF_plots_PQ)
    display(PF_plots_QV)
    display(PF_plots_PS)
    display(PF_plots_PV)
    display(VoltWatt_plots_PQ)
    display(VoltWatt_plots_QV)
    display(VoltWatt_plots_PS)
    display(VoltWatt_plots_PV)
end

visualization_PV_households!(PV_households_data, 1:672)

plot(PV_households_data[268]["Q/P"][1:672], xlabel = "time step", ylabel = "Q/P", title = "Q/P over time", label=false)
plot(PV_households_data[210]["Q_load"][1:192], xlabel = "time step", ylabel = "Q", title = "Q over time", label=false)
plot(PV_households_data[210]["P_load"][1:2976], xlabel = "time step", ylabel = "P", title = "P over time", label=false)
plot(PV_households_data[268]["Q_pv"][1:1344], xlabel = "time step", ylabel = "Q_pv", title = "Q_pv over time", label=false)
plot(PV_households_data[268]["P_pv"][1:1344], xlabel = "time step", ylabel = "P_pv", title = "P_pv over time", label=false)
plot(PV_households_data[268]["Q/V"][1:672], xlabel = "time step", ylabel = "Q/V", title = "Q/V over time", label=false)
plot(PV_households_data[268]["P/V"][1:672], xlabel = "time step", ylabel = "P/V", title = "P/V over time", label = false)
println(PV_households_data[268]["PV_setpoint"])
any(isnan, PV_households_data[268]["P_pv"])

function plot_Q_P_V_over_time(PV_households_data, household, timestamp_begin, timestamp_end)
    household_data = PV_households_data[household]
    setpoint = household_data["PV_setpoint"]
    power_unit = 1e4
    println("setpoint", setpoint)
    p = plot(xlabel = "time step", ylabel = "P, Q", title = "Power over time", label=false)
    q = plot(xlabel = "time step", ylabel = "Voltage", title = "Voltage over time", label=false)
    idx = timestamp_begin:timestamp_end
    P_data = household_data["Ptot"][idx].*power_unit
    Q_data = household_data["Qtot"][idx].*power_unit
    V_data = household_data["V$(household_data["phase"])"][idx]
    plot!(p, idx, P_data, label="P_tot")
    plot!(p, idx, Q_data, label="Q_tot")
    plot!(q, idx, V_data, label="V$(household_data["phase"])")
    display(p)
    display(q)
end
plot_Q_P_V_over_time(PV_households_data, 219, 500, 672)

function plot_QP_QV_household(signals, setpoint, range, sunlight_timesteps)
    QP_plot = plot(xlabel = "P", ylabel = "Q", title = "Q over P", label=false)
    QV_plot = plot(xlabel = "V", ylabel = "Q", title = "Q over V", label=false)
    PV_plot = plot(xlabel = "P", ylabel = "V", title = "V over P", label=false)
    idx = intersect(range, sunlight_timesteps)
    power_unit = 1e4
    for (key, signal) in signals
        S_rated = signal["S_rated"]
        if signal["PV_setpoint"] == setpoint
            data_P = signal["Ptot"][idx].*power_unit./S_rated
            data_Q = signal["Qtot"][idx].*power_unit./S_rated
            data_V = signal["V$(signal["phase"])"][idx]
            scatter!(QP_plot, data_P, data_Q, label=false)
            scatter!(QV_plot, data_V, data_Q, label=false)
            scatter!(PV_plot, data_P, data_V, label=false)
        end
    end
    display(QP_plot)
    display(QV_plot)
    display(PV_plot)
end

plot_QP_QV_household(PV_households_data, "PF_fixed", 1:1344, sunlight_timesteps) #PF_fixed, WattVAr, VoltVAr

function visualization_PS_PV_fixed_PF(PV_households_data, range, sunlight_timesteps)
    PS_plots = plot(xlabel = "time step", ylabel = "P/S", title = "P/S over time for fixed PF", label=false)
    i=0
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == "PF_fixed"
            println(key)
            i += 1
            data_1 = data["P/S"][range]
            data_to_plot = []
            for j in range
                if j in sunlight_timesteps
                    push!(data_to_plot, data_1[j])
                end
            end
            plot!(PS_plots, data_to_plot, label=false)
        end
    end
    display(PS_plots)
    println(i)
end

visualization_PS_PV_fixed_PF(PV_households_data, 1:672, sunlight_timesteps)

function visualization_delta_QV(PV_households_data, setpoint, range, export_index)
    V_nominal = 1.0
    p = plot(xlabel = "ΔV (V)", ylabel = "ΔQ (kVAr)", title = " $(setpoint)", label=false)
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == setpoint
            net_timestamps = export_index[!, Symbol(key)][1]
            idx = intersect(range, net_timestamps)
            phase = data["phase"]
            V = Float64.(data["V$(phase)"][idx])
            Q = Float64.(data["Qtot"][idx])*1e4
            ΔV = V .- V_nominal
            ΔQ = Q .- mean(Q)
            scatter!(p, ΔV, ΔQ, label=false)
        end
    end
    display(p)
end
visualization_delta_QV(PV_households_data, "PF_fixed", 1:2976, export_index)
visualization_delta_QV(PV_households_data, "VoltVAr", 1:2976, export_index)
#Computing correlation between P, Q, V, S for different setpoints
function correlation_analysis_PV_setpoints(PV_households_data, range, PV_setpoint, sunlight_timesteps)
    PF_PQ = Float64[]
    PF_QV = Float64[]
    PF_PS = Float64[]
    PF_PV = Float64[]
    plot1 = plot(xlabel = "house", ylabel = "correlation of $(PV_setpoint)", label=false)
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == PV_setpoint
            phase = data["phase"]
            idx = intersect(range, sunlight_timesteps)
            data_P = Float64.(data["Ptot"][idx])
            data_Q = Float64.(data["Qtot"][idx])
            data_PQ = data_Q./data_P
            data_V = Float64.(data["V$(phase)"][idx])
            #data_S = Float64.(data["S_tot"][idx])
            #data_PS = data_P./data_S
            #data_QV = data_Q./data_V
            push!(PF_PQ, cor(data_P, data_Q))
            push!(PF_QV, cor(data_Q, data_V))
            #push!(PF_PS, cor(data_P, data_S))
            push!(PF_PV, cor(data_P, data_V))
            #push!(PF_PQ, cor(data_PQ, data_QV))
            #push!(PF_QV, cor(data_PQ, data_PS))
            #push!(PF_PS, cor(data_QV, data_PS))
        end
    end
    plot!(plot1, 1:length(PF_PQ), PF_PQ, label="P/Q")
    plot!(plot1, 1:length(PF_QV), PF_QV, label="Q/V")
    #plot!(plot1, 1:length(PF_PS), PF_PS, label="P/S")
    plot!(plot1, 1:length(PF_PV), PF_PV, label="P/V")
    display(plot1)
end

correlation_analysis_PV_setpoints(PV_households_data, 1:2976, "PF_fixed", sunlight_timesteps)
correlation_analysis_PV_setpoints(PV_households_data, 1:2976, "WattVAr", sunlight_timesteps)
correlation_analysis_PV_setpoints(PV_households_data, 1:2976, "VoltVAr", sunlight_timesteps)
correlation_analysis_PV_setpoints(PV_households_data, 1:2976, "VoltWatt", sunlight_timesteps)

function correlation_analysis_PV_setpoints_negative_net(PV_households_data, range, PV_setpoint, net_timesteps)
    PF_PQ = Float64[]
    PF_QV = Float64[]
    PF_PS = Float64[]
    PF_PV = Float64[]
    plot1 = plot(xlabel = "house", ylabel = "correlation of $(PV_setpoint)", label=false)
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == PV_setpoint
            phase = data["phase"]
            net_timestamps = net_timesteps[!, Symbol(key)][1]
            idx = intersect(range, net_timestamps)
            data_P = Float64.(data["Ptot"][idx])
            data_Q = Float64.(data["Qtot"][idx])
            data_PQ = data_Q./data_P
            data_V = Float64.(data["V$(phase)"][idx])
            data_S = Float64.(data["S_tot"][idx])
            data_PS = data_P./data_S
            data_QV = data_Q./data_V
            push!(PF_PQ, cor(data_P, data_Q))
            push!(PF_QV, cor(data_Q, data_V))
            #push!(PF_PS, cor(data_P, data_S))
            push!(PF_PV, cor(data_P, data_V))
            #push!(PF_PQ, cor(data_PQ, data_QV))
            #push!(PF_QV, cor(data_PQ, data_PS))
            #push!(PF_PS, cor(data_QV, data_PS))
        end
    end
    plot!(plot1, 1:length(PF_PQ), PF_PQ, label="P/Q")
    plot!(plot1, 1:length(PF_QV), PF_QV, label="Q/V")
    plot!(plot1, 1:length(PF_PV), PF_PV, label="P/V")
    display(plot1)
end

correlation_analysis_PV_setpoints_negative_net(PV_households_data, 1:2976, "PF_fixed", export_index)
correlation_analysis_PV_setpoints_negative_net(PV_households_data, 1:2976, "WattVAr", export_index)
correlation_analysis_PV_setpoints_negative_net(PV_households_data, 1:2976, "VoltVAr", export_index)
correlation_analysis_PV_setpoints_negative_net(PV_households_data, 1:2976, "VoltWatt", export_index)

function PF_calculation(PV_households_data, range, export_index)
    results_df = _DF.DataFrame(Household = Int[], Setpoint = String[], PF_std = Float64[])
    for (key, data) in PV_households_data
        setpoint = data["PV_setpoint"]
        net_timestamps = export_index[!, Symbol(key)][1]
        idx = intersect(range, net_timestamps)
        data_P = Float64.(data["Ptot"][idx]*1e4)
        data_Q = Float64.(data["Qtot"][idx]*1e4)
        PF = abs.(data_P ./ sqrt.(data_P .^ 2 .+ data_Q .^ 2))
        pf_std = std(PF)
        push!(results_df, (key, setpoint, pf_std))
    end
    return results_df
end
PF_results = PF_calculation(PV_households_data, 1:2976, export_index)

function correlation_analysis_PV_setpoints_high_v(PV_households_data, range, PV_setpoint)
    corr_QV_low = Float64[]
    corr_QV_high = Float64[]
    corr_PV = Float64[]
    corr_PQ = Float64[]
    ratio_QV = Float64[]
    plot1 = plot(xlabel = "house", ylabel = "correlation of $(PV_setpoint)", label=false)
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == PV_setpoint
            phase = data["phase"]
            high_prod_index = findall(data["Ptot"] .<= quantile(data["Ptot"], 0.6))
            V_index_Q_high = findall(data["V$(phase)"] .>= quantile(data["V$(phase)"], 0.7))
            V_index_Q_low = findall(data["V$(phase)"] .< quantile(data["V$(phase)"], 0.3))
            V_index_P = findall(data["V$(phase)"] .>= quantile(data["V$(phase)"], 0.9))
            V_index_mid = findall((data["V$(phase)"] .>= quantile(data["V$(phase)"], 0.4)) .& (data["V$(phase)"] .<= quantile(data["V$(phase)"], 0.6)))
            data_P1 = data["Ptot"][intersect(intersect(range, V_index_P), high_prod_index)]
            idx_P = findall(data_P1 .<= quantile(data_P1, 0.1))
            data_P = data_P1[idx_P]
            data_V_P = data["V$(phase)"][intersect(intersect(range, V_index_P), high_prod_index)][idx_P]
            data_Q_low1 = Float64.(data["Qtot"][intersect(intersect(range, V_index_Q_low), high_prod_index)])
            data_Q_high1 = data["Qtot"][intersect(intersect(range, V_index_Q_high), high_prod_index)]
            idx_Q_high = findall(data_Q_high1 .<= quantile(data_Q_high1, 0.05))
            data_Q_high = data_Q_high1[idx_Q_high]
            data_V_high = data["V$(phase)"][intersect(intersect(range, V_index_Q_high), high_prod_index)][idx_Q_high]
            ratio = mean(data["Qtot"][intersect(range, V_index_Q_low)])/mean(data["Qtot"][intersect(range, V_index_mid)])
            if ratio > 4
                ratio = 1
            elseif ratio < -4
                ratio = -1
            end
            push!(ratio_QV, ratio)
            #push!(corr_PQ, cor(data_P, data_Q))
            if length(data_Q_low1) > 0
                idx_Q_low = findall(data_Q_low1 .<= quantile(data_Q_low1, 0.05))
                data_Q_low = data_Q_low1[idx_Q_low]
                data_V_low = data["V$(phase)"][intersect(intersect(range, V_index_Q_low), high_prod_index)][idx_Q_low]
                push!(corr_QV_low, cor(data_Q_low, data_V_low))
            else
                data_Q_low1 = data["Qtot"][intersect(intersect(range, V_index_Q_low), high_prod_index)]
                push!(corr_QV_low, 0.0)
            end
            push!(corr_QV_high, cor(data_Q_high, data_V_high))
            push!(corr_PV, cor(data_P, data_V_P))
        end
    end
    #plot!(plot1, 1:length(corr_PQ), corr_PQ, label="P/Q")
    plot!(plot1, 1:length(corr_QV_low), corr_QV_low, label="Q/V (Low Voltage)")
    plot!(plot1, 1:length(corr_QV_high), corr_QV_high, label="Q/V (High Voltage)")
    plot!(plot1, 1:length(corr_PV), corr_PV, label="P/V")
    plot!(plot1, 1:length(ratio_QV), ratio_QV, label="Ratio of Q at low V to mid V")
    display(plot1)
end

correlation_analysis_PV_setpoints_high_v(PV_households_data, 1:6000, "PF_fixed")
correlation_analysis_PV_setpoints_high_v(PV_households_data, 1:6000, "WattVAr")
correlation_analysis_PV_setpoints_high_v(PV_households_data, 1:6000, "VoltVAr")
correlation_analysis_PV_setpoints_high_v(PV_households_data, 1:6000, "VoltWatt")

function correlation_analysis_PV_setpoints_extreme_v(PV_households_data, range, PV_setpoint, net_timesteps, sunlight_hours)
    PF_PQ = Float64[]
    PF_QV = Float64[]
    house = Int[]
    PF_PV = Float64[]
    plot1 = plot(xlabel = "house", ylabel = "correlation of $(PV_setpoint)", label=false)
    for (key, data) in PV_households_data
        if data["PV_setpoint"] == PV_setpoint
            phase = data["phase"]
            net_timestamps = vcat(net_timesteps[!, Symbol(key)][1], net_timesteps[!, Symbol(key)][2])
            idx1 = intersect(range, net_timestamps)
            idx = intersect(idx1, sunlight_hours[!, Symbol(key)][1])
            data_P1 = Float64.(data["Ptot"][idx].*1e4)
            data_Q1 = Float64.(data["Qtot"][idx].*1e4)
            idx_P = findall(data_P1 .< quantile(data_P1, 0.2))
            idx_Q = findall(data_Q1 .< quantile(data_Q1, 0.2))
            data_P = data_P1[idx_P]
            data_Q = data_Q1[idx_Q]
            data_P_Q = data_P1[idx_Q]
            #data_PQ = data_Q./data_P
            data_V1 = Float64.(data["V$(phase)"][idx])
            data_V_P = data_V1[idx_P]
            data_V_Q = data_V1[idx_Q]
            #data_S = Float64.(data["S_tot"][idx])
            #data_PS = data_P./data_S
            #data_QV = data_Q./data_V
            push!(PF_PQ, cor(data_P_Q, data_Q))
            push!(PF_QV, cor(data_Q, data_V_Q))
            #push!(PF_PS, cor(data_P, data_S))
            push!(PF_PV, cor(data_P, data_V_P))
            push!(house, key)
            #push!(PF_PQ, cor(data_PQ, data_QV))
            #push!(PF_QV, cor(data_PQ, data_PS))
            #push!(PF_PS, cor(data_QV, data_PS))
        end
    end
    
    plot!(plot1, 1:length(PF_PQ), PF_PQ, label="P/Q")
    plot!(plot1, 1:length(PF_QV), PF_QV, label="Q/V")
    plot!(plot1, 1:length(PF_PV), PF_PV, label="P/V")
    display(plot1)
end

correlation_analysis_PV_setpoints_extreme_v(PV_households_data, 1:6000, "PF_fixed", extreme_v_idx, export_index)
correlation_analysis_PV_setpoints_extreme_v(PV_households_data, 1:6000, "WattVAr", extreme_v_idx, export_index)
correlation_analysis_PV_setpoints_extreme_v(PV_households_data, 1:6000, "VoltVAr", extreme_v_idx, export_index)
correlation_analysis_PV_setpoints_extreme_v(PV_households_data, 1:6000, "VoltWatt", extreme_v_idx, export_index)

#Computing FFT and Wavelet
function compute_fft(PV_household_data, PV_setpoint, vars, sunlight_timesteps; fs=1/900)
    idx = intersect(1:1344, sunlight_timesteps)
    a = plot(xlabel="Frequency (Hz)", ylabel="Amplitude (W)",title="FFT $(PV_setpoint)", legend=false)
    for (key, data) in PV_households_data
            if data["PV_setpoint"] == PV_setpoint #35=PF, 56=WattVAr, 60=VoltVAr
            signal = data[vars][idx]
            N = length(signal)
            signal_norm = (signal .- mean(signal)) ./ std(signal)
            fft_vals = fft(signal_norm)
            fft_vals = fft_vals[1:div(N,2)]
            freqs = (0:div(N,2)-1)*(fs/N)
            mag = abs.(fft_vals) * 2 / N
            plot!(a, freqs, mag, label="")
        end
    end
    display(a)
end

compute_fft(PV_households_data, "VoltVAr", "Q/V", sunlight_timesteps)

function compute_wavelet(signal)
    w = wavelet(WT.haar)
    levels = 4 
    coeffs = modwt(signal, w, levels)
    return coeffs
end

idx1 = idx[2:end]
coeffs = compute_wavelet(PV_households_data[219]["P/S"][idx1])
function plot_modwt(coeffs) 
    nlevels = size(coeffs, 2) 
    p = plot(layout = (nlevels, 1), size=(800, 600)) 
    for i in 1:nlevels 
        plot!(p[i], coeffs[:, i], label="Level $i") 
    end 
    display(p) 
end
plot_modwt(coeffs)

#Fitting of general models (to detect distinction between VV and VW)
function fit_models(signal, range, lower_timesteps, higher_timesteps, key)
    Ptot = signal["Ptot"]
    Qtot = signal["Qtot"]
    V = signal["V$(signal["phase"])"]

    Q1_lower = Qtot[intersect(range, lower_timesteps)]*1e4 #.-mean(Qtot[no_pv_idx[:, Symbol(key)][1]])*1e4
    V1_lower = V[intersect(range, lower_timesteps)]
    idx_Q_lower = findall(Q1_lower .<= quantile(Q1_lower, 0.05))
    Q2_lower = Q1_lower[idx_Q_lower]
    V2_lower = V1_lower[idx_Q_lower]
    P1_higher = Ptot[intersect(range, higher_timesteps)]*1e4
    Q1_higher = Qtot[intersect(range, higher_timesteps)]*1e4 #.-mean(Qtot[no_pv_idx[:, Symbol(key)][1]])*1e4
    V1_higher = V[intersect(range, higher_timesteps)]
    idx_Q_higher = findall(Q1_higher .<= quantile(Q1_higher, 0.05))
    idx_P_higher = findall(P1_higher .<= quantile(P1_higher, 0.05))
    P2_higher = P1_higher[idx_P_higher]
    Q2_higher = Q1_higher[idx_Q_higher]
    V2_higher = V1_higher[idx_Q_higher]
    V3_higher = V1_higher[idx_P_higher]

    n = length(Q2_lower) + length(Q2_higher)
    n_P = length(P2_higher)

    model1_lower = loess(V2_lower, Q2_lower, span=0.3)
    model1_higher = loess(V2_higher, Q2_higher, span=0.3)
    Qhat_VV_lower = predict(model1_lower, V2_lower)
    Qhat_VV_higher = predict(model1_higher, V2_higher)
    res_VV_lower = Q2_lower - Qhat_VV_lower
    res_VV_higher = Q2_higher - Qhat_VV_higher
    res_all_VV = vcat(res_VV_lower, res_VV_higher)
    k_VV = 0.3*n
    n = length(res_all_VV)
    sigma2_VV = sum(res_all_VV.^2) / n
    logL_VV = -(n/2) * (log(2*pi*sigma2_VV) + 1)
    #AIC_VV = -2 * logL_VV + 2 * k_VV

    Phat_VV_higher = fill(mean(P2_higher), length(P2_higher))
    res_VV_P_higher = P2_higher - Phat_VV_higher
    k_VV_P = 1
    sigma2_VV_P = sum(res_VV_P_higher.^2) / n_P
    logL_VV_P = -(n_P/2) * (log(2*pi*sigma2_VV_P) + 1)
    AIC_VV = -2 * (logL_VV + logL_VV_P) + 2 * (k_VV + k_VV_P)
    RMSE_VV = sqrt(mean(res_all_VV.^2))


    Qhat_VW_lower = fill(mean(Q2_lower), length(Q2_lower))
    Qhat_VW_higher = fill(mean(Q2_higher), length(Q2_higher))
    res_VW_lower = Q2_lower - Qhat_VW_lower
    res_VW_higher = Q2_higher - Qhat_VW_higher
    k_VW = 2
    res_all_VW = vcat(res_VW_lower, res_VW_higher)
    n = length(res_all_VW)
    k_VW = 2 
    sigma2_VW = sum(res_all_VW.^2) / n
    logL_VW = -(n/2) * (log(2*pi*sigma2_VW) + 1)
    #AIC_VW = -2 * logL_VW + 2 * k_VW

    model2_higher = loess(V3_higher, P2_higher, span=0.3)
    Phat_VW_higher = predict(model2_higher, V3_higher)
    res_VW_P_higher = P2_higher - Phat_VW_higher
    k_VW_P = 0.3*length(P2_higher)
    sigma2_VW_P = sum(res_VW_P_higher.^2) / n_P
    logL_VW_P = -(n_P/2) * (log(2*pi*sigma2_VW_P) + 1)
    AIC_VW = -2 * (logL_VW + logL_VW_P) + 2 * (k_VW_P + k_VW)
    RMSE_VW = sqrt(mean(res_all_VW.^2))

    return AIC_VV, AIC_VW
end

distinction_based_on_RMSE(PV_households_data, 1:2976)

function feature_extraction!(PV_households_data, range)
    corr_QV_low = Float64[]
    corr_QV_high = Float64[]
    corr_PV_high = Float64[]
    house = Int[]
    for (key, data) in PV_households_data
        push!(house, key)
        phase = data["phase"]
        V = data["V$(phase)"]
        V_high_P_index = findall(V .> quantile(V, 0.8))
        V_high_Q_index = findall(V .> quantile(V, 0.6))
        V_low_Q_index = findall(V .< quantile(V, 0.5))
        high_prod_index = findall(data["Ptot"] .<= quantile(data["Ptot"], 0.5)) 
        data_P1 = Float64.(data["Ptot"][intersect(intersect(range, V_high_P_index), high_prod_index)])
        idx_P = findall(data_P1 .<= quantile(data_P1, 0.1))
        data_P = data_P1[idx_P]
        data_high_Q1 = Float64.(data["Qtot"][intersect(intersect(range, V_high_Q_index), high_prod_index)])
        data_low_Q1 = Float64.(data["Qtot"][intersect(intersect(range, V_low_Q_index), high_prod_index)])
        if data_low_Q1 != []
            idx_Q_low = findall(data_low_Q1 .<= quantile(data_low_Q1, 0.4))
            data_Q_low = data_low_Q1[idx_Q_low]
            data_Q_V_low = V[intersect(intersect(range, V_low_Q_index), high_prod_index)][idx_Q_low]
            push!(corr_QV_low, cor(data_Q_low, data_Q_V_low))
        else
            push!(corr_QV_low, 0.0)
        end
        if data_high_Q1 != []
            idx_Q_high = findall(data_high_Q1 .>= quantile(data_high_Q1, 0.6))
            data_Q_high = data_high_Q1[idx_Q_high]
            data_Q_V_high = V[intersect(intersect(range, V_high_Q_index), high_prod_index)][idx_Q_high]
            push!(corr_QV_high, cor(data_Q_high, data_Q_V_high))
        else
            push!(corr_QV_high, 0.0)
        end
        data_P_V_high = V[intersect(intersect(range, V_high_P_index), high_prod_index)][idx_P]
        push!(corr_PV_high, cor(data_P, data_P_V_high))
    end
    corr_matrix = hcat(corr_QV_high, corr_QV_low, corr_PV_high)'
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

function clustering!(PV_households_data, range; Nr_clusters=2)
    feat_df = feature_extraction!(PV_households_data, range)
    X = Matrix(feat_df)
    result = kmeans_restart!(X, Nr_clusters, runs=50)
    clusters = result.assignments
    pv_labels = [PV_households_data[parse(Int,key)]["PV_setpoint"] for key in names(feat_df)]
    df = _DF.DataFrame(key=names(feat_df), cluster=clusters, PV_setpoint=pv_labels)
    counts = _DF.combine(_DF.groupby(df, [:cluster, :PV_setpoint]), _DF.nrow => :count)
    table = _DF.unstack(counts, :PV_setpoint, :count)

    setpoint_cols = [:VoltVAr, :VoltWatt]

    cluster_estimation = _DF.DataFrame(cluster = table.cluster, estimated_setpoint = [setpoint_cols[argmax([row[col] for col in setpoint_cols])] for row in eachrow(table)])
    building_assignment = _DF.DataFrame(key=names(feat_df), cluster=clusters, Uncertainty = result.costs)
    building_assignment = _DF.leftjoin(building_assignment,df[:, [:key, :PV_setpoint]],on = :key)
    building_assignment = _DF.leftjoin(building_assignment, cluster_estimation, on = :cluster)
    lowest_cost_keys_per_cluster = Vector{Vector{Any}}(undef, Nr_clusters)
    for c in 1:Nr_clusters
        cluster_rows = building_assignment[building_assignment.cluster .== c, :]
        sorted_rows = sort(cluster_rows, :Uncertainty)
        n_select = floor(Int, size(sorted_rows, 1) / 2)
        keys = sorted_rows.key[1:n_select]
        lowest_cost_keys_per_cluster[c] = keys
    end

    return table, result, building_assignment, lowest_cost_keys_per_cluster
end

X_buildings = Dict(k => v for (k, v) in PV_households_data if (v["PV_setpoint"] == "VoltVAr"|| v["PV_setpoint"] == "VoltWatt"))

table, result, building_assignment, lowest_cost_keys_per_cluster = clustering!(X_buildings, 1:2976; Nr_clusters=2)

building = 210
phase = PV_households_data[building]["phase"]
high_prod_index = findall(PV_households_data[building]["Ptot"] .<= quantile(PV_households_data[building]["Ptot"], 1))
low_voltage_index = findall(PV_households_data[building]["V$(phase)"] .< quantile(PV_households_data[building]["V$(phase)"], 0.5))
idx = intersect(intersect(1:2976, high_prod_index), low_voltage_index)
idx = intersect(1:2976, high_prod_index)
Q_index = findall(PV_households_data[building]["Qtot"][idx].*1e4 .<= quantile(PV_households_data[building]["Qtot"][idx].*1e4, 1))
idx = idx[Q_index]
scatter(PV_households_data[building]["V$(phase)"][idx], PV_households_data[building]["Qtot"][idx].*1e4, label=false, title="$(building)")


#Clustering directly on time series
Nr_clusters = 3
household_keys = collect(keys(PV_households_data))
idx = intersect(1:1344, sunlight_timesteps)
series = [household_data["Q/V"][idx] for (key, household_data) in PV_households_data]
series_normalized = [(s .- mean(s)) ./ std(s) for s in series]
X = hcat(series...)  
columns_to_cluster_on = _DF.DataFrame(X, Symbol.(household_keys))
result = kmeans(X, Nr_clusters)
clusters = result.assignments
pv_labels = [PV_households_data[key]["PV_setpoint"] for key in household_keys]
df = _DF.DataFrame(key=household_keys, cluster=clusters, PV_setpoint=pv_labels)
counts = _DF.combine(_DF.groupby(df, [:cluster, :PV_setpoint]), _DF.nrow => :count)
table = _DF.unstack(counts, :PV_setpoint, :count)

#Clustering with PCA
series = []
idx = intersect(1:1344, sunlight_timesteps)
for (_, data) in PV_households_data
    phase = data["phase"]
    P = data["P_pv"][idx]
    Q = data["Q_pv"][idx]
    V = data["V$(phase)"][idx]
    push!(series, vcat(P, Q, V)) 
end
X = hcat(series...)'
sigma = std(X, dims=1)
sigma[sigma .== 0] .= 1
X_norm = (X .- mean(X, dims=1)) ./ sigma
pca_model = fit(PCA, X_norm'; maxoutdim=10)
Z = transform(pca_model, X_norm')
Nr_clusters = 3
result = kmeans(Z, Nr_clusters)
clusters = result.assignments
pv_labels = [PV_households_data[key]["PV_setpoint"] for key in household_keys]
df = _DF.DataFrame(key=household_keys, cluster=clusters, PV_setpoint=pv_labels)
counts = _DF.combine(_DF.groupby(df, [:cluster, :PV_setpoint]), _DF.nrow => :count)
table = _DF.unstack(counts, :PV_setpoint, :count)

#Clustering on features (to detect distinction between PF and VV/VW)
table, result, lowest_cost_keys_per_cluster = clustering!(PV_households_data, 1:2976; Nr_clusters=2)
PF_cluster, corr_values = extract_PF_cluster(lowest_cost_keys_per_cluster, PV_households_data, 1:2976)
