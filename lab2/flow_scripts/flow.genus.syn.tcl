# ------------------------------------------------------------------------------
# Start
# ------------------------------------------------------------------------------

source $::env(FLOW_DIR)/steps.genus.tcl

# Build reports dirs
foreach s {syn_generic syn_map syn_opt} {
    file mkdir $::env(GENUS_REPORT_DIR)/$s $::env(GENUS_OUTPUT_DIR)/$s
}

# Host info for the log, then tool options (effort, HDL search path) before reading anything
step_genus_host_info
step_genus_global_options

# Read RTL from the file list (parse only, no design yet)
step_genus_read_hdl
# Read MMMC: .lib, corners, SDC; libraries must be known before elaborate
step_genus_read_mmmc
# Build the generic design for the top module; check for unresolved refs
step_genus_elaborate
# Bind the design to MMMC views and apply SDC; needs elaborated design
step_genus_init_design

# Synthesis: generic gates -> library cells -> timing/area optimization,
# each stage writes reports and a netlist into its own directory
step_genus_gen
step_genus_map
step_genus_opt

# Write the Conformal dofile comparing RTL with the final syn_opt netlist (does not run LEC)
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
