# ------------------------------------------------------------------------------
# Start
# ------------------------------------------------------------------------------

source $::env(FLOW_DIR)/steps.genus.tcl

# Build reports dirs
foreach s {syn_generic syn_map syn_opt} {
    file mkdir $::env(GENUS_REPORT_DIR)/$s $::env(GENUS_OUTPUT_DIR)/$s
}

step_genus_host_info
step_genus_global_options
step_genus_read_hdl
step_genus_read_mmmc
step_genus_elaborate
step_genus_init_design
step_genus_gen
step_genus_map
step_genus_opt

step_genus_lec $::env(GENUS_OUTPUT_DIR)/syn_opt/$::env(ENV_DESIGN).v



# ------------------------------------------------------------------------------
# Finish
# ------------------------------------------------------------------------------
puts "============================"
puts "Synthesis Finished"
puts "============================"

# suspend
# gui_show
quit
