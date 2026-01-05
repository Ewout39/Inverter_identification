function visualize_volvar_curve(Result_dict, voltvar_curve, repititions)
    x_curve = first.(voltvar_curve)
    y_curve = last.(voltvar_curve)
    p = plot(
        x_curve,
        y_curve,
        xlabel = "Voltage",
        ylabel = "PV Reactive Power",
        title  = "PV Reactive Power vs Voltage",
        legend = false,
        grid   = true
    )
    for repitition in 1:repititions
        for (key, value) in Result_dict["Repitition_$(repitition)"]["Loads"]
            if length(value["PV_setpoint"]) > 0
                if value["PV_setpoint"][1] == "VoltVAr"
                    phase = value["Phase"][1]
                    voltage_data = Result_dict["Repitition_$(repitition)"]["Busses"][string(value["bus_number"][1])]["V$(phase)"]
                    Q_pv_data = value["Q_pv$(phase)"]
                    scatter!(p, voltage_data, Q_pv_data, label="", xlabel="Voltage", ylabel="PV Reactive Power", title="PV Reactive Power vs Voltage")
                end
            end
        end
    end
    display(p)
end

function visualize_wattvar_curve(Result_dict, varP_curve, repititions)
    x_curve = first.(varP_curve)
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
                    phase = value["Phase"][1]
                    P_pv_data = value["P_pv$(phase)"]
                    Q_pv_data = value["Q_pv$(phase)"]
                    scatter!(p, P_pv_data, Q_pv_data, label="", xlabel="Active Power", ylabel="PV Reactive Power", title="PV Reactive Power vs Active Power")
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
        ylims = (0.0, 1.0)
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
        ylim = (0.95, 1.05)
    )
    p2 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Phase 2",
        legend = false,
        grid   = true,
        ylim = (0.95, 1.05)
    )
    p3 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Phase 3",
        legend = false,
        grid   = true,
        ylim = (0.95, 1.05)
    )
    p4 = plot(
        xlabel = "Time",
        ylabel = "Voltage",
        title  = "Voltage over time on Neutral",
        legend = false,
        grid   = true,
        ylim = (0, 0.10)
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

function visualize_PV_active_power(Result_dict, repitition, solar_profile, math, range)
    p = plot(
        xlabel = "Time Step",
        ylabel = "PV Active Power (kW)",
        title  = "PV Active Power over Time",
        legend = true,
        grid   = true
    )

    for (key, value) in Result_dict["Repitition_$(repitition)"]["Loads"]
        if length(value["PV_setpoint"]) > 0
            key_PV = value["key_PV"][1]
            p_id = math["load"]["$(key_PV)"]["parquet_id"]
            P_solar = solar_profile[range, "Psolar_"*p_id]
            ptot_key = only(filter(k -> startswith(k, "P_tot"), keys(value)))
            phase = parse(Int, ptot_key[end])
            P_pv_data = value["P_pv$(phase)"]
            P_diff = P_solar .- P_pv_data
            if maximum(abs.(P_diff)) > 1e-3
                plot!(p, 1:length(P_pv_data), P_diff, label="bus:$(key_PV)", color=:blue, xlabel="Time Step", ylabel="PV Active Power (kW)", title="PV Active Power over Time")
            end
        end
    end
    display(p)
end