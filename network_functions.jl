function network_transformation!()
    eng = _PMD.parse_file("Master_oh.dss", data_model = _PMD.ENGINEERING, transformations=[_PMD.transform_loops!,_PMD.remove_all_bounds!])
    rm_transformer!(eng)
    reduce_enwl_lines_eng!(eng)
    eng["settings"]["sbase_default"] = 10000
    math = _PMD.transform_data_model(eng, kron_reduce=false, phase_project=false) #This is where the issue lies
    clean_4w_data!(math, eng=eng, merge_buses_diff_linecodes = false)
    add_linecode_math!(math, eng)
    return eng, math
end

function rm_transformer!(data_eng)
    if haskey(data_eng, "transformer")
        line1 = data_eng["line"]["line1"]
        trans = data_eng["transformer"]["tr1"]
        vprim_scale = trans["vm_nom"][2]/trans["vm_nom"][1]

        vsource = data_eng["voltage_source"]["source"]

        vsource["vm"] *= vprim_scale
        vsource["rs"] *= vprim_scale^2
        vsource["xs"] *= vprim_scale^2
        vsource["bus"] = "1"

        delete!(data_eng, "transformer")
        delete!(data_eng["bus"], "sourcebus")

        vbases_default = data_eng["settings"]["vbases_default"]
        vbases_default["1"] = vbases_default["sourcebus"]*vprim_scale
        delete!(vbases_default, "sourcebus")
    end
end

function reduce_enwl_lines_eng!(data_eng)
    rm_trailing_lines_eng!(data_eng)
    join_lines_eng!(data_eng)
end

function rm_trailing_lines_eng!(data_eng)

    buses_exclude = []
    for comp_type in ["load", "shunt", "generator", "voltage_source"]
        if haskey(data_eng, comp_type)
            buses_exclude = union(buses_exclude, [comp["bus"] for (_, comp) in data_eng[comp_type]])
        end
    end
    if haskey(data_eng, "transformer")
        buses_exclude = union(buses_exclude, hcat([tr["bus"] for (_, tr) in data_eng["transformer"]]...))
    end

    line_has_shunt = Dict()
    bus_lines = Dict(k=>[] for k in keys(data_eng["bus"]))
    for (id, line) in data_eng["line"]
        lc = data_eng["linecode"][line["linecode"]]
        line_has_shunt[id] = !all(iszero(lc[k]) for k in ["b_fr", "b_to", "g_fr", "g_to"])
        push!(bus_lines[line["f_bus"]], id)
        push!(bus_lines[line["t_bus"]], id)
    end

    eligible_buses = [bus_id for (bus_id, line_ids) in bus_lines if length(line_ids)==1 && !(bus_id in buses_exclude) && !line_has_shunt[line_ids[1]]]

    while !isempty(eligible_buses)
        for bus_id in eligible_buses
            # this trailing bus has one associated line
            line_id = bus_lines[bus_id][1]
            line = data_eng["line"][line_id]

            delete!(data_eng["line"], line_id)
            delete!(data_eng["bus"],  bus_id)

            other_end_bus = line["f_bus"]==bus_id ? line["t_bus"] : line["f_bus"]
            bus_lines[other_end_bus] = setdiff(bus_lines[other_end_bus], [line_id])
            delete!(bus_lines,  bus_id)
        end

        eligible_buses = [bus_id for (bus_id, line_ids) in bus_lines if length(line_ids)==1 && !(bus_id in buses_exclude) && !line_has_shunt[line_ids[1]]]
    end
end
function _line_reverse_eng!(line)
    prop_pairs = [("f_bus", "t_bus")]

    for (x,y) in prop_pairs
        tmp = line[x]
        line[x] = line[y]
        line[y] = tmp
    end
end
function join_lines_eng!(data_eng)
    # a bus is eligible for reduction if it only appears in exactly two lines
    buses_all = collect(keys(data_eng["bus"]))
    buses_exclude = []

    # start by excluding all buses that appear in components other than lines
    for comp_type in ["load", "shunt", "generator", "voltage_source"]
        if haskey(data_eng, comp_type)
            buses_exclude = union(buses_exclude, [comp["bus"] for (_, comp) in data_eng[comp_type]])
        end
    end

    # per bus, list all inbound or outbound lines
    bus_lines = Dict(bus=>[] for bus in buses_all)
    for (id, line) in data_eng["line"]
        push!(bus_lines[line["f_bus"]], id)
        push!(bus_lines[line["t_bus"]], id)
    end

    # exclude all buses that do not have exactly two lines connected to it
    buses_exclude = union(buses_exclude, [bus for (bus, lines) in bus_lines if length(lines)!=2])

    # now loop over remaining buses
    candidates = setdiff(buses_all, buses_exclude)
    for bus in candidates
        line1_id, line2_id = bus_lines[bus]
        line1 = data_eng["line"][line1_id]
        line2 = data_eng["line"][line2_id]

        # reverse lines if needed to get the order
        # (x)--fr-line1-to--(bus)--to-line2-fr--(x)
        if line1["f_bus"]==bus
            _line_reverse_eng!(line1)
        end
        if line2["f_bus"]==bus
            _line_reverse_eng!(line2)
        end

        reducable = true
        reducable = reducable && line1["linecode"]==line2["linecode"]
        reducable = reducable && all(line1["t_connections"].==line2["t_connections"])
        if reducable

            line1["length"] += line2["length"]
            line1["t_bus"] = line2["f_bus"]
            line1["t_connections"] = line2["f_connections"]

            delete!(data_eng["line"], line2_id)
            delete!(data_eng["bus"], bus)
            for x in candidates
                if line2_id in bus_lines[x]
                    bus_lines[x] = [setdiff(bus_lines[x], [line2_id])..., line1_id]
                end
            end
        end
    end

    return data_eng
end

function add_length!(ntw::Dict, eng::Dict)
    for (_, br) in ntw["branch"]
        br["orig_length"] = eng["line"][br["name"]]["length"]
    end
    return ntw
end

function add_degree_to_bus!(data) # to see the number of connected ports
    for (b, bus) in data["bus"]
        bus["degree"] = 0
        for (br, branch) in data["branch"]
            if branch["t_bus"] == bus["index"] || branch["f_bus"] == bus["index"]
                bus["degree"] += 1
            end
        end
    end
end

function remove_all_superfluous_buses!(data::Dict)
    @assert !haskey(data, "nw") "Please use `remove_all_intermediate_buses_mn` for multinetwork data dicts like this one"
    load_buses = ["$(load["load_bus"])" for (_, load) in data["load"]]
    gen_buses = ["$(gen["gen_bus"])" for (_, gen) in data["gen"]]
    add_degree_to_bus!(data)
    for lb in load_buses @assert data["bus"][lb]["degree"] == 1 "Load $lb is on the main cable, add a small connection cable with the appropriate util function!" end #Need to change this to 3
    to_delete = [b for (b, bus) in data["bus"] if (b ∉ union!(gen_buses, load_buses) && bus["degree"] <= 2)]
    for db in to_delete
        data["bus"][db]["adjacent_buses"] = []
        data["bus"][db]["inout_branches"] = []
        for (br, branch) in data["branch"]
            if branch["f_bus"] == parse(Int, db) || branch["t_bus"] == parse(Int, db)
                push!(data["bus"][db]["inout_branches"], br)
                if branch["f_bus"] != parse(Int, db)
                    push!(data["bus"][db]["adjacent_buses"], "$(branch["f_bus"])")
                else
                    push!(data["bus"][db]["adjacent_buses"], "$(branch["t_bus"])")
                end
            end
        end
    end
    while !isempty(to_delete)
        for db in to_delete
            if any([b ∈ to_delete for b in data["bus"][db]["adjacent_buses"]])
                deletable_adj_bus = [b for b in data["bus"][db]["adjacent_buses"] if b ∈ to_delete][1]
                other_adj_bus = [b for b in data["bus"][db]["adjacent_buses"] if b != deletable_adj_bus][1]
                deletable_adj_bus_branches = data["bus"][deletable_adj_bus]["inout_branches"]
                delete_branch = first(intersect(Set(data["bus"][db]["inout_branches"]), Set(deletable_adj_bus_branches)))
                preserve_branch = [br for br in data["bus"][db]["inout_branches"] if br != delete_branch][1]
                
                Req = (data["branch"][preserve_branch]["br_r"] .+ data["branch"][delete_branch]["br_r"])
                Xeq = (data["branch"][preserve_branch]["br_x"] .+ data["branch"][delete_branch]["br_x"]) 
                data["branch"][preserve_branch]["br_r"] = Req
                data["branch"][preserve_branch]["br_x"] = Xeq
                
                data["branch"][preserve_branch]["f_bus"] = parse(Int64, other_adj_bus)
                data["branch"][preserve_branch]["t_bus"] = parse(Int64, deletable_adj_bus)
                data["bus"][deletable_adj_bus]["adjacent_buses"] = filter(x->x!=db, data["bus"][deletable_adj_bus]["adjacent_buses"])
                push!(data["bus"][deletable_adj_bus]["adjacent_buses"], other_adj_bus)
                data["bus"][deletable_adj_bus]["inout_branches"] = filter(x->x!=delete_branch, data["bus"][deletable_adj_bus]["inout_branches"])
                push!(data["bus"][deletable_adj_bus]["inout_branches"], preserve_branch)
                delete!(data["branch"], delete_branch)
            else
                delete_branch = data["bus"][db]["inout_branches"][1]
                preserve_branch = [br for br in data["bus"][db]["inout_branches"] if br != delete_branch][1]
                Req = (data["branch"][preserve_branch]["br_r"] .+ data["branch"][delete_branch]["br_r"])
                Xeq = (data["branch"][preserve_branch]["br_x"] .+ data["branch"][delete_branch]["br_x"]) 
                data["branch"][preserve_branch]["br_r"] = Req
                data["branch"][preserve_branch]["br_x"] = Xeq
                
                delete!(data["branch"], delete_branch)
                data["branch"][data["bus"][db]["inout_branches"][2]]["f_bus"] = parse(Int64, data["bus"][db]["adjacent_buses"][1])
                data["branch"][data["bus"][db]["inout_branches"][2]]["t_bus"] = parse(Int64, data["bus"][db]["adjacent_buses"][2])
            end
            delete!(data["bus"], db)
            to_delete = filter(x->x!=db, to_delete)
        end
    end
    # the lines below make sure that the orientation of the branch at the slack bus is from slack_bus to --> rest of feeder
    ref_bus = [bus["index"] for (_,bus) in data["bus"] if bus["bus_type"] == 3][1]
    ref_branch_fr = [b for (b, br) in data["branch"] if br["f_bus"] == ref_bus]
    if isempty(ref_branch_fr) 
        ref_branch_to = [b for (b, br) in data["branch"] if br["t_bus"] == ref_bus][1]
        f_bus = data["branch"][ref_branch_to]["f_bus"]
        data["branch"][ref_branch_to]["f_bus"] = ref_bus
        data["branch"][ref_branch_to]["t_bus"] = f_bus
    end
    return data
end

function find_voltage_source_branch_bus(math)
    for (b, branch) in math["branch"]
        if branch["source_id"] == "voltage_source.source"
            return b, branch["f_bus"], branch["t_bus"]
        end
    end
    return error()
end

function clean_4w_data!(ntw::Dict; eng::Dict=Dict{String, Any}(), merge_buses_diff_linecodes::Bool = false)
    if merge_buses_diff_linecodes 
        remove_all_superfluous_buses!(ntw) 
        add_length!(ntw, eng)
        #TODO add function to add length even when we remove all superfluous buses
    end
    #### below removes virtual voltage source (but the transformer I removed in the eng model, thus beforehand)
    vsource_branch, vsource_bus, new_slackbus = find_voltage_source_branch_bus(ntw) 
    ntw["gen"]["1"]["gen_bus"] = new_slackbus
    ntw["bus"]["$new_slackbus"] = deepcopy(ntw["bus"]["$vsource_bus"])
    ntw["bus"]["$new_slackbus"]["bus_i"] = new_slackbus
    ntw["bus"]["$new_slackbus"]["index"] = new_slackbus
    delete!(ntw["branch"], vsource_branch)
    delete!(ntw["bus"], "$vsource_bus")
    return ntw
end

function add_linecode_math!(math::Dict, eng::Dict)
    for (id, branch) in math["branch"]
        name = branch["name"]  # This usually matches the line ID in eng["line"]
        if haskey(eng["line"], name) && haskey(eng["line"][name], "linecode")
            branch["linecode"] = eng["line"][name]["linecode"]
        end
    end
end

function assignment_of_PV!(math::Dict, load_profiles::_DF.DataFrame, repitition::Int, S_inverters::Vector{Any}, voltvar_curve::Vector{Tuple{Real, Real}}; Nr_PV_buildings::Int=18)
    rng = Random.seed!(repitition)                 
    numbers = randperm(rng, 55)[1:55]
    PV_load = []
    phase_1 = 0
    phase_2 = 0
    phase_3 = 0
    nr_PVs = 1
    load_key = 55
    setpoints_list = ["PF_fixed", "VoltWatt"] #TODO add "VoltVAr"
    for n in numbers
        if math["load"]["$(n)"]["connections"][1] == 1 && ((phase_1 - 4 <  phase_2 && phase_1 - 4 < phase_3) || phase_1 < 5)
            phase_1 += 1
            load_key += 1
            copy_load(math, n, load_key)
            push!(PV_load, "$(n)")
            nr_PVs += 1
        elseif math["load"]["$(n)"]["connections"][1] == 2 && (phase_2 - 4 < phase_1 && phase_2 - 4 < phase_3 || phase_2 < 5)
            phase_2 += 1
            load_key += 1
            copy_load(math, n, load_key)
            push!(PV_load, "$(n)")
            nr_PVs += 1
        elseif math["load"]["$(n)"]["connections"][1] == 3 && (phase_3 - 4 < phase_1 && phase_3 - 4 < phase_2 || phase_3 < 5)
            phase_3 += 1
            load_key += 1
            copy_load(math, n, load_key)
            push!(PV_load, "$(n)")
            nr_PVs += 1
        end
        if nr_PVs > Nr_PV_buildings
            break
        end
    end
    assign_load_to_parquet_id!(math, load_profiles, repitition)
    PV_setpoints = assign_PV_setpoints!(math, PV_load, setpoints_list, repitition, voltvar_curve, S_inverters)
    return PV_load, PV_setpoints
end

function assign_PV_setpoints!(math::Dict, PV_load::Vector{Any}, setpoints_list::Vector{String}, repitition::Int, voltvar_curve::Vector{Tuple{Real, Real}}, S_inverters::Vector{Any})
    rng = Random.seed!(repitition) 
    setpoints_intermediate_list = [rand(rng, setpoints_list) for _ in 1:10*length(PV_load)]
    PV_setpoints = []
    PF_fixed_count = 0
    VoltWatt_count = 0
    VoltVAr_count = 0
    nr_PVs = 1
    i = 1
    for (_, load) in math["load"] #TODO add VoltVAr + add starting values for pd and qd
        PV_setpoint = setpoints_intermediate_list[i]
        if PV_setpoint == "PF_fixed" && load["index"] > 55 && ((PF_fixed_count - 4 <  VoltWatt_count) || PF_fixed_count < 5) #TODO add VoltVAr_count
            PF_fixed_count += 1
            load["PV_setpoint"] = "PF_fixed"
            push!(PV_setpoints, (load["index"], "PF_fixed"))
            load["pd_start"] = load["pd"][1]
            load["qd_start"] = load["qd"][1]     
            nr_PVs += 1
        elseif PV_setpoint == "VoltWatt" && load["index"] > 55 && ((VoltWatt_count - 4 <  PF_fixed_count) || VoltWatt_count < 5) #TODO add VoltVAr_count
            VoltWatt_count += 1
            load["PV_setpoint"] = "VoltWatt"
            push!(PV_setpoints, (load["index"], "VoltWatt"))
            load["pd_start"] = load["pd"][1]
            load["qd_start"] = load["qd"][1]
            nr_PVs += 1
        elseif PV_setpoint == "VoltVAr" && load["index"] > 55 && ((VoltVAr_count - 4 <  PF_fixed_count && VoltVAr_count - 4 <  VoltWatt_count) || VoltVAr_count < 5)
            p_id = load["parquet_id"]
            VoltVAr_count += 1
            load["PV_setpoint"] = "VoltVAr"
            push!(PV_setpoints, (load["index"], "VoltVAr"))
            load["pd_start"] = load["pd"][1]
            load["qd_start"] = load["qd"][1]
            load["VV_breakpoints"] = [i[1] for i in voltvar_curve]
            load["VV_Q_values"] = [i[2] for i in voltvar_curve]
            load["S_rating"] = S_inverters[parse(Int, p_id)]
            nr_PVs += 1
        else
            load["PV_setpoint"] = "None"
        end
        if nr_PVs > length(PV_load)
            println(PF_fixed_count, " ", VoltWatt_count)
            return PV_setpoints
        end
    i += 1
    end
end

function copy_load(math::Dict, original_load_number::Int, new_load_number::Int)  #TODO may need to put dispatchable on 1, for varying loads
    math["load"]["$(new_load_number)"] = deepcopy(math["load"]["$(original_load_number)"])
    math["load"]["$(new_load_number)"]["source_id"] = "load.load$(new_load_number)"
    math["load"]["$(new_load_number)"]["name"] = "load$(new_load_number)"
    math["load"]["$(new_load_number)"]["index"] = new_load_number
    math["load"]["$(new_load_number)"]["non_PV_load_number"] = original_load_number
end

function assign_load_to_parquet_id!(data::Dict, df::_DF.DataFrame, repitition::Int)
    parquet_ids = names(df)[1+55*(repitition-1):55*repitition] #goes up to 330
    count = 1
    sorted_keys = sort(collect(keys(data["load"])), by=x->parse(Int,x))
    for key in sorted_keys
        load = data["load"]["$key"]
        if parse(Int, key) <= 55
            if split(parquet_ids[count], "_")[1] == "PLoad"
                load["parquet_id"] = split(parquet_ids[count], "_")[end]
            end
        else
            load["parquet_id"] = data["load"]["$(load["non_PV_load_number"])"]["parquet_id"]
        end
        count+=1
    end
    return data
end


function insert_load_profiles!(data::Dict, df::_DF.DataFrame, timestep::Int, solar_profile::_DF.DataFrame, PF::Float64, S_inverters::Vector{Any}, varP_curve::Vector{Tuple{Real, Real}})
    power_unit = data["settings"]["sbase"]
    @assert power_unit == 1e4 "The profiles are in kW, but the power_unit seems different. Please fix."
    for (key, load) in data["load"]
        p_id = load["parquet_id"]
        if parse(Int, key) > 55
            S_rated = S_inverters[parse(Int, p_id)]
            P_solar = solar_profile[timestep, "Psolar_"*p_id]
            if load["PV_setpoint"] == "PF_fixed"
                Q_solar = P_solar * tan(acos(PF))
            elseif load["PV_setpoint"] == "VoltWatt"
                if P_solar/S_rated <= varP_curve[2][1]
                    Q_solar = 0.0
                elseif P_solar/S_rated >= varP_curve[2][1] && P_solar/S_rated <= varP_curve[3][1]
                    Q_solar = S_rated * (varP_curve[2][2] + (varP_curve[3][2] - varP_curve[2][2])/(varP_curve[3][1]-varP_curve[2][1]) * (P_solar/S_rated - varP_curve[2][1]))
                else
                    P_solar = varP_curve[3][1]*S_rated
                    Q_solar = S_rated * varP_curve[3][2]
                end
            end
            load["pd"][1] = -P_solar/power_unit
            load["qd"][1] = Q_solar/power_unit
        else
            load["pd"][1] = df[timestep, "PLoad_"*p_id]/power_unit
            load["qd"][1] = df[timestep, "QLoad_"*p_id]/power_unit
        end
    end
end

function add_initial_values!(math::Dict, result::Dict)
    for (key, bus) in math["bus"]
        vr = result["solution"]["bus"]["$key"]["vr"]
        vi = result["solution"]["bus"]["$key"]["vi"]
        bus["vr_start"] = vr
        bus["vi_start"] = vi
    end
    for (key, load) in math["load"]
        pd = result["solution"]["load"]["$key"]["pd"]
        qd = result["solution"]["load"]["$key"]["qd"]
        load["pd_start"] = pd
        load["qd_start"] = qd
    end
end    

function pf_solution_to_line_loading!(sol::Dict, math::Dict)
    for (i, line) in sol["solution"]["branch"]
        bus = math["branch"]["$(i)"]["f_bus"]
        um = sqrt.(sol["solution"]["bus"]["$(bus)"]["vr"][1:4].^2 .+ sol["solution"]["bus"]["$(bus)"]["vi"][1:4].^2)
        ua = atan.(sol["solution"]["bus"]["$(bus)"]["vi"][1:4] ./ sol["solution"]["bus"]["$(bus)"]["vr"][1:4])
        uf = um .* exp.(1im .* ua)
        if haskey(line, "cr") && haskey(line, "ci")
            i_f = line["cr"][1:4] .+ 1im .* line["ci"][1:4]
            sf = uf.*conj(i_f)
            pf = real.(sf)
            qf = imag.(sf)
        else
            pf = line["pf"][1:4]
            qf = line["qf"][1:4] 
        end
        line_loading = sqrt.(pf.^2 .+ qf.^2).*math["settings"]["sbase"]./(abs.(uf).*math["settings"]["vbases_default"]["103"])
        if math["branch"][i]["linecode"] == "pluto" || math["branch"][i]["linecode"] == "hydrogen"
            ampacity = 600  #437, but actually should be 600 Amps 600 ~= 437/0.75
        elseif math["branch"][i]["linecode"] == "ABC2x16"
            ampacity = 78.0
        elseif math["branch"][i]["linecode"] == "TW2X16"
            ampacity = 437.0
        else
            warning("Linecode $(math["branch"][i]["linecode"]) not recognized, assuming ampacity of 437 A") 
            ampacity = 437.0
        end
        sol["solution"]["branch"][i]["line_loading"] = line_loading./ampacity
    end
end
