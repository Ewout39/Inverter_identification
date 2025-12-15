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

# loading in data
PR = 0.8
eff_panel = 0.2
panel_area = 1.7 #m2
nr_solar_hr_year = 2100
voltvar_curve = [(0.92, -0.44), (0.98, 0), (1, 0), (1.02, 0), (1.08, 0.44)] #need to make varying still
varP_curve = [(0, 0), (0.2, 0.0), (0.95,  0.3)] #need to make varying still
PF = 0.98 #need to make varying still
repititions = 2 #TODO change this back to 6
Nr_pv_buildings = 18

load_profiles = extract_loading_Slovak!() #data loaded in kW, kVAr from 2016
solar_irradiance = extract_solar_irradiance_Slovak!() #data loaded in kW/m2 from PVGIS.com
Nr_panels, solar_profile, S_inverter = create_solar_profiles!(solar_irradiance, PR, eff_panel, panel_area, load_profiles, nr_solar_hr_year)

#Network creation
eng, math = network_transformation!()
powerplot(math, width=1000, height = 1000, bus=(:size=>200))

#Result dictionary creation
Result_dict = initialize_empty_dict!()

#Power flow analysis
function optimal_power_flow_analysis!(math, load_profiles, solar_profile, S_rated, PF, varP_curve, repitition, Nr_pv_buildings)
    _PMD.add_start_vrvi!(math)
    for timestep in 1:100 #TODO change back to 35136
        insert_load_profiles!(math, load_profiles, timestep, solar_profile, PF, S_rated, varP_curve)
        res = _PMD.solve_mc_opf(math, _PMD.IVRENPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "max_iter" => 2000, "print_level" => 0))
        pf_solution_to_line_loading!(res, math)
        add_to_dict!(Result_dict, res, repitition, math)
        add_initial_values!(math, res)
    end
end

for current_repitition in 1:repititions
    PV_load, PV_setpoints = assignment_of_PV!(math, load_profiles, current_repitition, S_inverter, voltvar_curve, Nr_PV_buildings=Nr_pv_buildings)
    powerplot(math, width=1000, height = 1000, bus=(:size=>200))
    optimal_power_flow_analysis!(math, load_profiles, solar_profile, S_inverter, PF, varP_curve, current_repitition, Nr_pv_buildings)
end
