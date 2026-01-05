import PowerModelsDistribution as _PMD
using JuMP
import DataFrames as _DF
using CSV
using PowerPlots
using Random
using Statistics
using Ipopt
using Interpolations
using Plots
using Revise
using MyVVPackage
include("network_functions.jl")
include("load_data.jl")
include("visualization.jl")

# loading in data
eff_system = 0.18
panel_peak_power = 0.4 #kW
panel_area = 2.0 #m2
voltvar_curve = [(0.6, -0.44), (0.92, -0.44), (0.98, 0), (1.02, 0), (1.08, 0.44), (1.4, 0.44)] #TODO need to make varying still
varP_curve = [(0, 0), (0.2, 0.0), (0.95,  0.3)] #TODO need to make varying still
PF = 0.98 #TODO need to make varying still
repititions = 2 #TODO change this back to 6
Nr_pv_buildings = 18

load_profiles = extract_loading_Slovak!() #data loaded in kW, kVAr from 2016
solar_irradiance = extract_solar_irradiance_Slovak!() #data loaded in kW/m2 from PVGIS.com
Nr_panels, solar_profile, S_inverter = create_solar_profiles!(solar_irradiance, eff_system, load_profiles, panel_peak_power, panel_area) 

#Result dictionary creation
Result_dict = initialize_empty_dict!()
Result_dict1 = initialize_empty_dict!()

#Power flow analysis
range = 1:100
function optimal_power_flow_analysis!(math, load_profiles, solar_profile, S_rated, PF, varP_curve, repitition, PV_load)
    _PMD.add_start_vrvi!(math)
    for timestep in range #TODO change back to 35136 (or from April till september)
        insert_load_profiles!(math, load_profiles, timestep, solar_profile, PF, S_rated, varP_curve)
        global res = MyVVPackage.solve_mc_opf(math, MyVVPackage.IVRENPowerModelVoltVar, optimizer_with_attributes(Ipopt.Optimizer, "max_iter" => 2000, "print_level" => 0), build_mc_opf = MyVVPackage.build_mc_opf)
        pf_solution_to_line_loading!(res, math)
        add_to_dict!(Result_dict, res, repitition, math, PV_load)
        add_initial_values!(math, res)
    end
end

function optimal_power_flow_analysis1!(math, load_profiles, solar_profile, S_rated, PF, varP_curve, repitition, PV_load)
    _PMD.add_start_vrvi!(math)
    for timestep in range #TODO change back to 35136 (or from April till september)
        insert_load_profiles!(math, load_profiles, timestep, solar_profile, PF, S_rated, varP_curve)
        res = _PMD.solve_mc_opf(math, _PMD.IVRENPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "max_iter" => 2000, "print_level" => 0))
        pf_solution_to_line_loading!(res, math)
        add_to_dict!(Result_dict1, res, repitition, math, PV_load)
        add_initial_values!(math, res)
    end
end

for current_repitition in 1:repititions
    eng, math = network_transformation!()
    println("Starting repitition ", current_repitition)
    PV_load, PV_setpoints = assignment_of_PV!(math, load_profiles, current_repitition, S_inverter, voltvar_curve, Nr_PV_buildings=Nr_pv_buildings)
    optimal_power_flow_analysis!(math, load_profiles, solar_profile, S_inverter, PF, varP_curve, current_repitition, PV_load)
    println("Finished repitition ", current_repitition)
end

for current_repitition in 1:repititions
    eng, math = network_transformation!()
    println("Starting repitition ", current_repitition)
    PV_load, PV_setpoints = assignment_of_PV!(math, load_profiles, current_repitition, S_inverter, voltvar_curve, Nr_PV_buildings=Nr_pv_buildings)
    assign_load_to_parquet_id!(math, load_profiles, current_repitition)
    optimal_power_flow_analysis1!(math, load_profiles, solar_profile, S_inverter, PF, varP_curve, current_repitition, PV_load)
    println("Finished repitition ", current_repitition)
end


#visualization
visualize_volvar_curve(Result_dict, voltvar_curve, repititions)
visualize_wattvar_curve(Result_dict, varP_curve, repititions)
visualize_PF_curve(Result_dict, PF, repititions)
repitition = 1
visualization_bus_voltages(Result_dict, repitition, range)
Compare_bus_voltages(Result_dict, Result_dict1, repitition, range)
visualize_PV_active_power(Result_dict, repitition, solar_profile, math, range)





