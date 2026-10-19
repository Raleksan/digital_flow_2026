# ------------------------------------------------------------------------------
# Start
# ------------------------------------------------------------------------------

source $::env(FLOW_DIR)/steps.genus.tcl

# Step 1.
step_genus_host_info
# Step 2.
step_genus_global_options
# Step 3.
step_genus_read_hdl
# Step 4.
step_genus_read_mmmc
# Step 5.
step_genus_elaborate
# Step 6.
step_genus_init_design
# Step 7.
step_genus_gen
# Step 8.
step_genus_map
# Step 9.
step_genus_opt
# Step 10.
step_genus_user_out
# Step 11.
step_genus_user_reports
# Step 12.
step_genus_lec

# ------------------------------------------------------------------------------
# Finish
# ------------------------------------------------------------------------------
puts "============================"
puts "Synthesis Finished"
puts "============================"

gui_show
# quit
