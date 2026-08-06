import PowerModelsDistribution as _PMD
using JuMP
import DataFrames as _DF
using CSV
using PowerPlots
using Random
import Distributions as _DST
using Statistics
using Ipopt
using Interpolations
using Plots
using Revise
using FFTW
using DSP
using Wavelets
using Loess
using Clustering #expects columns = observations, rows=features
using Distances
using MultivariateStats
using StatsPlots
using StatsBase
using MyVVPackage
include("load_data.jl")
include("network_functions.jl")
include("visualization.jl")

# loading in data 
const DATA_DIR = joinpath(dirname(@__DIR__), "inverter_identification", "Fluvius data")
#Yearly consumption Fluvius visualization function
yearly_consumption_noPV, yearly_consumption_EV_noPV, yearly_consumption_WP_noPV, yearly_consumption_WP_EV_noPV = Yearly_consumption_profiles!()

#Loading in the load profiles
country = "Belgium"
Weibull = false
load_profiles, building_list, PF_list = load_data!(country, weibull=Weibull)
scenario = Medium_v #"Medium_v", #"High_v", "Low_v",

#Quick test to see if all PV buildings are filtered out of Slovakian dataset
function plot_load_profiles(load_profiles, begin_i, end_i)
    x = plot()
    for i in begin_i:end_i
        P_load = load_profiles[14593:15960, "PLoad_$(i)"]
        plot!(x, P_load, label="$(i)")
    end
    display(x)
end
plot_load_profiles(load_profiles, 191, 191)

#Quick test to see if the power factors are correctly distributed
histogram(PF_list, bins=30, normalize=:pdf, xlabel="PF", ylabel="Probability Density", title="Distribution of PF")

panel_peak_power = 0.4 #kW
voltvar_curve = [[(0.88, -0.42), (0.9, -0.42), (0.98, 0), (1.0, 0), (1.02, 0.12), (1.1, 0.12)], #Distribution Grid Optimal Power Flow with Volt-VAr and Volt-Watt Settings of Smart Inverters
                [(0.88, -0.4), (0.92, -0.4), (0.98, 0), (1.02, 0), (1.08, 0.4), (1.1, 0.4)], #Improving Distribution System State Estimation by Including Volt-Var Control Information
                [(0.88, -0.44), (0.92, -0.44), (0.98, 0), (1.02, 0), (1.08, 0.44), (1.1, 0.44)], #Droop-control-aided state estimation and false data detection in active distribution systems
                [(0.88, -0.1), (0.94, -0.42), (0.97, 0), (1.03, 0), (1.08, 0.3), (1.1, 0.3)]] #Self-created

                
varP_curve = [[(0, 0), (0.2, 0.0), (0.95,  0.21875)], [(0, 0), (0.35, 0.0), (0.95,  0.0855)], [(0, 0), (0.1, 0.0), (0.95,  0.213)]] #Self-created
VoltWatt_curve = [[(0.88, 0.99), (1.0, 0.99), (1.07, 0.0), (1.1, 0.0)], #Distribution Grid Optimal Power Flow with Volt-VAr and Volt-Watt Settings of Smart Inverters
                [(0.88, 0.99), (1.02, 0.99), (1.08, 0.0), (1.1, 0.0)], #Self-created
                [(0.88, 0.99), (1.04, 0.99), (1.09, 0.0), (1.1, 0.0)], #Self-created
                [(0.88, 0.99), (1.01, 0.99), (1.07, 0.0), (1.1, 0.0)], #self-created
                [(0.88, 0.99), (1.00, 0.99), (1.05, 0.0), (1.1, 0.0)]] #Self-created

PF = [0.96, 0.97, 0.98, 0.99]
repititions = 6
Nr_pv_buildings = 20
Z_value = 1.8

solar_irradiance = extract_solar_irradiance!(country) #data loaded in kW/m2 from PVGIS.com (originally per hour/ interpolated to 15min)
Nr_panels, solar_profile, daily_consumption, S_inverter = create_solar_profiles!(solar_irradiance, load_profiles, panel_peak_power) #Solar_profile in kW
daily_con = _DF.DataFrame(cons=daily_consumption)
S_inv = _DF.DataFrame(S_inv = S_inverter)

#Result dictionary creation
Result_dict = initialize_empty_dict!()
Result_dict1 = initialize_empty_dict!()

#Power flow analysis
Summer = 14593:23424 
Summer_week = 14793:15064 #For debugging
range_period = Summer
dirpath = create_directory!()
function optimal_power_flow_analysis!(math, load_profiles, solar_profile, S_rated, PF, varP_curve, repitition, PV_load, scenario)
    _PMD.add_start_vrvi!(math)
    for timestep in range_period 
        insert_load_profiles!(math, load_profiles, timestep, solar_profile, PF, S_rated, varP_curve, repitition, scenario)
        global res = MyVVPackage.solve_mc_opf(math, MyVVPackage.IVRENPowerModelVoltVar, optimizer_with_attributes(Ipopt.Optimizer, "max_iter" => 2000, "print_level" => 0), build_mc_opf = MyVVPackage.build_mc_opf)
        pf_solution_to_line_loading!(res, math)
        add_to_dict!(Result_dict, res, repitition, math, PV_load)
        add_initial_values!(math, res)
    end
end

for current_repitition in 1:repititions 
    global eng, math = network_transformation!()
    for (key, branch) in math["branch"]
        br_r = branch["br_r"]
        br_x = branch["br_x"]
        math["branch"][key]["br_r"] = br_r .*Z_value
        math["branch"][key]["br_x"] = br_x .*Z_value
    end
    add_on = 0
    if country == "Slovakia"
        add_on = 0
    elseif country == "Belgium" && Weibull == false
        add_on = 5
    elseif country == "Belgium" && Weibull == true
        add_on = 10
    end
    println("Starting repitition ", current_repitition)
    PV_load, PV_setpoints = assignment_of_PV!(math, load_profiles, current_repitition, S_inverter, voltvar_curve, VoltWatt_curve, Nr_PV_buildings=Nr_pv_buildings, PF, add_on, varP_curve)
    optimal_power_flow_analysis!(math, load_profiles, solar_profile, S_inverter, PF, varP_curve, current_repitition, PV_load, scenario)
    println("Finished repitition ", current_repitition)
end

store_data_results!(Result_dict)

#visualization
repitition = 6
visualize_voltvar_curve(Result_dict, voltvar_curve, repititions)
visualize_voltvar_curve_single_load(Result_dict, voltvar_curve, repitition, "50")
visualize_wattvar_curve(Result_dict, varP_curve, repititions)
visualize_PF_curve(Result_dict, PF, repititions)
visualize_voltwatt_curve(Result_dict, VoltWatt_curve, repititions)
visualization_all_bus_voltages(Result_dict, repitition)
range1 = 1:672
visualization_bus_voltages(Result_dict, repitition, range1)
visualization_bus_voltage_reactive_power_single_load(Result_dict, repitition, range1, "43")
Compare_bus_voltages(Result_dict, Result_dict1, repitition, range1)
visualize_PV_active_power(Result_dict, repitition)




function test_under_rated_power(Result_dict1, repitition)
    for (key, value) in Result_dict1["Repitition_$(repitition)"]["Loads"]
        if length(value["PV_setpoint"]) > 0
            phase = value["Phase"][1]
            P_pv = value["P_pv$(phase)"] .* 1e4
            Q_PV = value["Q_pv$(phase)"] .* 1e4
            Pd_start = value["P_pv_original$(phase)"] .* 1e4
            S_rated = value["S_rated"][1]
            S_calc = sqrt.(P_pv.^2 .+ Q_PV.^2)
            bus_number = value["bus_number"][1]
            voltage = Result_dict1["Repitition_$(repitition)"]["Busses"]["$(bus_number)"]["V$(phase)"]
            #S_calc = P_pv
            for i in 1:length(P_pv)
                if S_calc[i] > S_rated
                    println(key, value["PV_setpoint"][1])
                    println(voltage[i])
                    println(Pd_start[i])
                    println(P_pv[i], Q_PV[i])
                    println("Household $key exceeds rated power at time step $i with calculated S = $(S_calc[i]) and rated S = $S_rated")
                end
            end
        end
    end
end
test_under_rated_power(Result_dict, repitition)

load_dict = Result_dict1["Repitition_$(repitition)"]["Loads"]["50"]
S_rated = load_dict["S_rated"][1]
phase = load_dict["Phase"][1]
P_pv = load_dict["P_pv$(phase)"] .* 1e4
for i in 1:length(P_pv)
    if abs(P_pv[i]/S_rated) > 1
        println(i)
    end
end
