#  ___       _ _
# |_ _|_ __ (_) |_
#  | || '_ \| | __|
#  | || | | | | |_
# |___|_| |_|_|\__|

source $::env(FLOW_DIR)/steps.innovus.tcl

# result dirs (run dir = run/innovus_impl)
file mkdir ./db ./reports ./out ./reports/init ./reports/final

# design setup
user_init_design
global_net
user_read_floorplan

# pre-run design check
check_timing -verbose > ./reports/init/check_timing.rpt
report_clocks -description > ./reports/init/report_clocks.rpt
puts "Setup views: [get_db [get_db analysis_views -if {.is_setup}] .name]"
puts "Hold views:  [get_db [get_db analysis_views -if {.is_hold}] .name]"

# check setup and hold time
user_preplace

# place std cells with opt, report setup hold time
user_place

# run CTS with opt
user_clock_tree_synthesis

# route
user_route

# check rc and sta
user_extract_rc
user_sta

# phy checks
report_timing -late  -path_type full_clock -max_paths 1 > ./reports/final/timing_late.rpt
report_timing -early -path_type full_clock -max_paths 1 > ./reports/final/timing_early.rpt
check_place
check_connectivity -type all -out_file ./reports/final/connectivity.rpt
check_drc -check_only all -out_file ./reports/final/drc.rpt

# write outputs
user_write_lef Metal5
user_write_gds
user_write_lib typ typ
user_write_spef
user_write_netlist
user_write_sdf typ
user_write_def

write_db ./db/DB.$::env(ENV_DESIGN).final.enc

gui_show
gui_fit
