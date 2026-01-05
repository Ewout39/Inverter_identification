function extract_loading_Slovak!()
    loaded_data = Dict{Int, Any}()
    column_names_P = ["PLoad_$(i)" for i in 1:330]
    column_names_Q = ["QLoad_$(i)" for i in 1:330]
    column_names = vcat(column_names_P, column_names_Q)
    load_data = _DF.DataFrame((column_name => [0.0 for _ in 1:35136] for column_name in column_names)...)
    k = 1
    i = 1
    while i <= 330
        data = nothing
        #filepath = "c:\\Users\\ewout\\OneDrive - KU Leuven\\2e_master\\thesis\\datasets\\1000_houses_dataset\\Code_data\\powerdf_clean_test\\$(k).csv"
        filepath = "c:\\Users\\u0181580\\OneDrive - KU Leuven\\2e_master\\thesis\\datasets\\1000_houses_dataset\\Code_data\\powerdf_clean_test\\$(k).csv"
        try
            data = CSV.read(filepath, _DF.DataFrame, delim=',')
        catch e
            #@warn "File not found: $filepath"
            #filepath = "c:\\Users\\ewout\\OneDrive - KU Leuven\\2e_master\\thesis\\datasets\\1000_houses_dataset\\Code_data\\powerdf_clean_train\\$(k-581).csv"
            filepath = "C:\\Users\\u0181580\\OneDrive - KU Leuven\\2e_master\\thesis\\datasets\\1000_houses_dataset\\Code_data\\powerdf_clean_train\\$(k-581).csv"
            data = CSV.read(filepath, _DF.DataFrame, delim=',')
        end
        if data[1, :PV] == 0 && sum(data[!, :P])*0.25 >= 2000
            loaded_data[i] = data
            if sum(data[!, :P])*0.25 >= 7500
                random_adjustment = rand(-500:500)
                scale_factor= (7500 + random_adjustment) / sum(data[!, :P])
            else
                scale_factor= 1.0
            end
            for j in 6:35141
                load_data[j-5, "PLoad_$(i)"] = loaded_data[i][j, :P].*scale_factor
                load_data[j-5, "QLoad_$(i)"] = loaded_data[i][j, :Q].*scale_factor
            end
            i += 1
        end
        k += 1
    end
    return load_data #kW and kVAr
end

function extract_solar_irradiance_Slovak!()
    solar_irradiance_1h = _DF.DataFrame("Irradiance_kW_m2" => [0.0 for _ in 1:8784])
    solar_irradiance = _DF.DataFrame("Irradiance_kW_m2" => [0.0 for _ in 1:35136])
    #filepath = "C:\\Users\\ewout\\OneDrive - KU Leuven\\PHD\\Julia\\Inverter_setpoint\\Irradiance_profile.csv"
    filepath = "Irradiance_profile.csv"
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

function create_solar_profiles!(solar_irradiance, eff_system, load_profiles, panel_peak_power, panel_size)
    Nr_panels = []
    S_inverter = []
    column_names = ["Psolar_$(i)" for i in 1:330]
    solar_profile = _DF.DataFrame((column_name => [0.0 for _ in 1:35136] for column_name in column_names)...)
    for i in 1:330
        load_profile = load_profiles[!, "PLoad_$(i)"]
        yearly_consumption = sum(load_profile)*0.25 #kWh
        daily_consumption = yearly_consumption/365 #kWh/day
        peak_sun_hours = sum(solar_irradiance)*0.25/365 #h/day
        system_size = daily_consumption / (peak_sun_hours)*1.25 #kW
        nr_panels = ceil(system_size / panel_peak_power) #number of panels needed
        for j in 1:35136
                solar_profile[j, "Psolar_$(i)"] = nr_panels * panel_size * solar_irradiance[j] * eff_system #Irradiance in KW per m2
        end
        S_inv = 0.85 * nr_panels * panel_peak_power #kW
        push!(Nr_panels, nr_panels)
        push!(S_inverter, S_inv)
    end
    return Nr_panels, solar_profile, S_inverter
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
                    "Phase" => Int[],
                    "key_PV" => Int[],
                    "PV_setpoint" => String[],
                    "bus_number" => Int[]
                )
            end
            push!(load_dict["P$(values["connections"][1])"], values["pd"][1])
            push!(load_dict["Q$(values["connections"][1])"], values["qd"][1])
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
                    "Phase" => Int[],
                    "key_PV" => Int[],
                    "PV_setpoint" => String[],
                    "bus_number" => Int[]
                )
            end
            push!(load_dict["P_pv_original$(values["connections"][1])"], values["pd_start"][1])
            push!(load_dict["P_pv$(values["connections"][1])"], values["pd"][1])
            push!(load_dict["Q_pv$(values["connections"][1])"], values["qd"][1])
            push!(load_dict["PV_setpoint"], values["PV_setpoint"])
            push!(load_dict["bus_number"], values["load_bus"])
            push!(load_dict["key_PV"], load_idx)
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



