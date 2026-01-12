function visualize_voltvar_curve(Result_dict, voltvar_curve, repititions)
    x_curve = first.(voltvar_curve)
    y_curve = last.(voltvar_curve)
    p = plot(
        x_curve,
        y_curve,
        xlabel = "Voltage",
        ylabel = "PV Reactive Power",
        title  = "PV Reactive Power over Voltage",
        legend = false,
        grid   = true
    )
    for repitition in 1:repititions
        for (key, value) in Result_dict["Repitition_$(repitition)"]["Loads"]
            if length(value["PV_setpoint"]) > 0
                if value["PV_setpoint"][1] == "VoltVAr"
                    println("load ", key)
                    power_unit = 1e4
                    S_rated = value["S_rated"][1]
                    phase = value["Phase"][1]
                    voltage_data = Result_dict["Repitition_$(repitition)"]["Busses"][string(value["bus_number"][1])]["V$(phase)"]
                    Q_pv_data = value["Q_pv$(phase)"] ./ S_rated .* power_unit
                    scatter!(p, voltage_data, Q_pv_data, label="", xlabel="Voltage [pu]", ylabel="PV Reactive Power [pu of S_rated]", title="PV Reactive Power over Voltage")
                end
            end
        end
    end
    display(p)
end

function visualize_voltvar_curve_single_load(Result_dict, voltvar_curve, repitition, load_id)
    x_curve = first.(voltvar_curve)
    y_curve = last.(voltvar_curve)
    p = plot(
        x_curve,
        y_curve,
        xlabel = "Voltage",
        ylabel = "PV Reactive Power",
        title  = "PV Reactive Power over Voltage for load $(load_id)",
        legend = false,
        grid   = true
    )
    value = Result_dict["Repitition_$(repitition)"]["Loads"][load_id]
    if value["PV_setpoint"][1] == "VoltVAr"
        power_unit = 1e4
        S_rated = value["S_rated"][1]
        phase = value["Phase"][1]
        voltage_data = Result_dict["Repitition_$(repitition)"]["Busses"][string(value["bus_number"][1])]["V$(phase)"]
        Q_pv_data = value["Q_pv$(phase)"] ./ S_rated .* power_unit
        scatter!(p, voltage_data, Q_pv_data, label="", xlabel="Voltage [pu]", ylabel="PV Reactive Power [pu of S_rated]", title="PV Reactive Power over Voltage for load $(load_id)")
    end
    display(p)
end

function visualize_wattvar_curve(Result_dict, varP_curve, repititions)
    x_curve = -first.(varP_curve)
    y_curve = last.(varP_curve)
    p = plot(
        x_curve,
        y_curve,
        xlabel = "Active Power",
        ylabel = "PV Reactive Power",
        title  = "PV Reactive Power vs Active Power",
        legend = false,
        grid   = true
    )
    for repitition in 1:repititions
        for (key, value) in Result_dict["Repitition_$(repitition)"]["Loads"]
            if length(value["PV_setpoint"]) > 0
                if value["PV_setpoint"][1] == "WattVAr"
                    S_rated = value["S_rated"][1]
                    power_unit = 1e4
                    phase = value["Phase"][1]
                    P_pv_data = value["P_pv$(phase)"] ./ S_rated .* power_unit
                    Q_pv_data = value["Q_pv$(phase)"] ./ S_rated .* power_unit
                    scatter!(p, P_pv_data, Q_pv_data, label="", xlabel="Active Power [pu of S_rated]", ylabel="PV Reactive Power [pu of S_rated]", title="PV Reactive Power vs Active Power")
                end
            end
        end
    end
    display(p)
end

function visualize_PF_curve(Result_dict, PF_curve, repititions)
    p = plot(
        xlabel = "Voltage",
        ylabel = "PF",
        title  = "PF vs Voltage",
        legend = false,
        grid   = true,
        ylims = (0.9, 1.0)
    )
    hline!([PF_curve])
    for repitition in 1:repititions
        for (key, value) in Result_dict["Repitition_$(repitition)"]["Loads"]
            if length(value["PV_setpoint"]) > 0
                if value["PV_setpoint"][1] == "PF_fixed"
                    ptot_key = only(filter(k -> startswith(k, "P_tot"), keys(value)))
                    phase = value["Phase"][1]
                    voltage_data = Result_dict["Repitition_$(repitition)"]["Busses"][string(value["bus_number"][1])]["V$(phase)"]
                    P_pv_data = value["P_pv$(phase)"]
                    Q_pv_data = value["Q_pv$(phase)"]
                    PF = -P_pv_data ./ sqrt.(P_pv_data .^ 2 .+ Q_pv_data .^ 2)
                    scatter!(p, voltage_data, PF, label="", xlabel="Voltage", ylabel="PF", title="PF vs Voltage")
                end
            end
        end
    end
    display(p)
end

function visualization_bus_voltages(Result_dict, repitition, range)
    p1 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Phase 1",
        legend = false,
        grid   = true,
        ylim = (0.85, 1.15)
    )
    p2 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Phase 2",
        legend = false,
        grid   = true,
        ylim = (0.85, 1.15)
    )
    p3 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Phase 3",
        legend = false,
        grid   = true,
        ylim = (0.85, 1.15)
    )
    p4 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Neutral",
        legend = false,
        grid   = true,
        ylim = (0, 0.15)
    )
    for bus in keys(Result_dict["Repitition_$(repitition)"]["Busses"])
        color = :auto
        v1 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V1"][range]
        v2 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V2"][range]
        v3 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V3"][range]
        v4 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V4"][range]
        plot!(p1, v1, label="Bus=$(bus)", legend_background_color=RGBA(1,1,1,0.5), color=color)
        plot!(p2, v2, label="Bus=$(bus)", legend_background_color=RGBA(1,1,1,0.5), color=color)
        plot!(p3, v3, label="Bus=$(bus)", legend_background_color=RGBA(1,1,1,0.5), color=color)
        plot!(p4, v4, label="Bus=$(bus)", legend_background_color=RGBA(1,1,1,0.5), color=color)
    end
    display(p1)
    display(p2)
    display(p3)
    display(p4)
end

function visualization_bus_voltage_reactive_power_single_load(Result_dict, repitition, range, load_id)
    p1 = nothing
    p2 = nothing
    p3 = nothing
    p4 = nothing
    p1_sub = nothing
    p2_sub = nothing
    p3_sub = nothing
    p4_sub = nothing
    p1_sub_sub = nothing
    p2_sub_sub = nothing
    p3_sub_sub = nothing
    p4_sub_sub = nothing
    bus = string(Result_dict["Repitition_$(repitition)"]["Loads"][load_id]["bus_number"][1])
    power_unit = 1e4
    color = :auto
    phase = Result_dict["Repitition_$(repitition)"]["Loads"][load_id]["Phase"][1]
    S_rated = Result_dict["Repitition_$(repitition)"]["Loads"][load_id]["S_rated"][1]
    Q_series = Result_dict["Repitition_$(repitition)"]["Loads"][load_id]["Q_pv$(phase)"][range].*power_unit./S_rated
    P_series = Result_dict["Repitition_$(repitition)"]["Loads"][load_id]["P_pv$(phase)"][range].*power_unit
    v1 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V1"][range]
    v2 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V2"][range]
    v3 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V3"][range]
    v4 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V4"][range]
    p1 = plot( Q_series, label="Bus=$(bus)", xlabel="Time", ylabel="Reactive power", title="Phase 1", legend_background_color=RGBA(1,1,1,0.5), color=color)
    p2 = plot( Q_series, label="Bus=$(bus)", xlabel="Time", ylabel="Reactive power", title="Phase 2", legend_background_color=RGBA(1,1,1,0.5), color=color)
    p3 = plot( Q_series, label="Bus=$(bus)", xlabel="Time", ylabel="Reactive power", title="Phase 3", legend_background_color=RGBA(1,1,1,0.5), color=color)
    p4 = plot( Q_series, label="Bus=$(bus)", xlabel="Time", ylabel="Reactive power", title="Neutral", legend_background_color=RGBA(1,1,1,0.5), color=color)
    p1_sub = plot( v1, label="Bus=$(bus)", xlabel="Time", ylabel="Voltage", ylim=(0.8, 1.1), legend_background_color=RGBA(1,1,1,0.5), color=color)
    p2_sub = plot( v2, label="Bus=$(bus)", xlabel="Time", ylabel="Voltage", ylim=(0.95, 1.02), legend_background_color=RGBA(1,1,1,0.5), color=color)
    p3_sub = plot( v3, label="Bus=$(bus)", xlabel="Time", ylabel="Voltage", ylim=(0.8, 1.1), legend_background_color=RGBA(1,1,1,0.5), color=color)
    p4_sub = plot( v4, label="Bus=$(bus)", xlabel="Time", ylabel="Voltage", ylim=(0, 0.15), legend_background_color=RGBA(1,1,1,0.5), color=color)
    p1_sub_sub = plot( P_series, label="Bus=$(bus)", xlabel="Time", ylabel="Active Power", legend_background_color=RGBA(1,1,1,0.5), color=color)
    p2_sub_sub = plot( P_series, label="Bus=$(bus)", xlabel="Time", ylabel="Active Power", legend_background_color=RGBA(1,1,1,0.5), color=color)
    p3_sub_sub = plot( P_series, label="Bus=$(bus)", xlabel="Time", ylabel="Active Power", legend_background_color=RGBA(1,1,1,0.5), color=color)
    p4_sub_sub = plot( P_series, label="Bus=$(bus)", xlabel="Time", ylabel="Active Power", legend_background_color=RGBA(1,1,1,0.5), color=color)
    combined_p1 = plot(p1, p1_sub, layout=@layout([a{0.5h}; b{0.5h}]), size=(800, 600))
    combined_p2 = plot(p2, p2_sub, layout=@layout([a{0.5h}; b{0.5h}]), size=(800, 600))
    combined_p3 = plot(p3, p3_sub, layout=@layout([a{0.5h}; b{0.5h}]), size=(800, 600))
    combined_p4 = plot(p4, p4_sub, layout=@layout([a{0.5h}; b{0.5h}]), size=(800, 600))
    combined_p1_full = plot(combined_p1, p1_sub_sub, layout=@layout([a{0.66h}; b{0.34h}]), size=(800, 800))
    combined_p2_full = plot(combined_p2, p2_sub_sub, layout=@layout([a{0.66h}; b{0.34h}]), size=(800, 800))
    combined_p3_full = plot(combined_p3, p3_sub_sub, layout=@layout([a{0.66h}; b{0.34h}]), size=(800, 800))
    combined_p4_full = plot(combined_p4, p4_sub_sub, layout=@layout([a{0.66h}; b{0.34h}]), size=(800, 800))
    display(combined_p1_full)
    display(combined_p2_full)
    display(combined_p3_full)
    display(combined_p4_full)
end

function Compare_bus_voltages(Result_dict, Result_dict1, repitition, range)
    p1 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Phase 1",
        legend = false,
        grid   = true,
        ylim = (0, 0.01)
    )
    p2 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Phase 2",
        legend = false,
        grid   = true,
        ylim = (0, 0.01)
    )
    p3 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Phase 3",
        legend = false,
        grid   = true,
        ylim = (0, 0.01)
    )
    p4 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Neutral",
        legend = false,
        grid   = true,
        ylim = (0, 0.01)
    )
    for bus in keys(Result_dict["Repitition_$(repitition)"]["Busses"])
        color = :auto
        v1 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V1"][range]
        v2 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V2"][range]
        v3 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V3"][range]
        v4 = Result_dict["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V4"][range]
        v1_1 = Result_dict1["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V1"][range]
        v2_1 = Result_dict1["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V2"][range]
        v3_1 = Result_dict1["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V3"][range]
        v4_1 = Result_dict1["Repitition_$(repitition)"]["Busses"]["$(bus)"]["V4"][range]
        v1_diff = abs.(v1 .- v1_1)
        v2_diff = abs.(v2 .- v2_1)
        v3_diff = abs.(v3 .- v3_1)
        v4_diff = abs.(v4 .- v4_1)
        plot!(p1, v1_diff, label="Bus=$(bus)", legend_background_color=RGBA(1,1,1,0.5), color=color)
        plot!(p2, v2_diff, label="Bus=$(bus)", legend_background_color=RGBA(1,1,1,0.5), color=color)
        plot!(p3, v3_diff, label="Bus=$(bus)", legend_background_color=RGBA(1,1,1,0.5), color=color)
        plot!(p4, v4_diff, label="Bus=$(bus)", legend_background_color=RGBA(1,1,1,0.5), color=color)
    end
    display(p1)
    display(p2)
    display(p3)
    display(p4)
end

function visualize_PV_active_power(Result_dict, repitition)
    p = plot(
        xlabel = "Time Step",
        ylabel = "PV Active Power (kW)",
        title  = "PV Active Power difference over Time",
        legend = true,
        grid   = true,
        ylims  = (-0.01, 0.01)
    )

    for (key, value) in Result_dict["Repitition_$(repitition)"]["Loads"]
        if length(value["PV_setpoint"]) > 0
            ptot_key = only(filter(k -> startswith(k, "P_tot"), keys(value)))
            phase = parse(Int, ptot_key[end])
            power_unit = 1e4
            key_PV = value["key_PV"][1]
            P_solar = value["P_pv_original$(phase)"]* power_unit
            P_pv_data = value["P_pv$(phase)"]* power_unit
            P_diff = P_solar .- P_pv_data
            if maximum(abs.(P_diff)) > 1e-3
                plot!(p, 1:length(P_pv_data), P_diff, label="bus:$(key_PV)", color=:blue, xlabel="Time Step", ylabel="PV Active Power (kW)", title="PV Active Power difference over Time")
            end
        end
    end
    display(p)
end