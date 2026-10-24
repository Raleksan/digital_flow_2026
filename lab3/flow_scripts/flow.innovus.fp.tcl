#  ___       _ _
# |_ _|_ __ (_) |_
#  | || '_ \| | __|
#  | || | | | | |_
# |___|_| |_|_|\__|

source $::env(FLOW_DIR)/steps.innovus.tcl

# init_design works once per Innovus process, so each grade is a separate run:
#   FP_STAGE=4 make innovus.fp   -> data/<design>/floorplan/<design>_floorplan_4.fp
#   FP_STAGE=5 make innovus.fp   -> loads _4.fp, writes _floorplan_5.fp
set stage [expr {[info exists ::env(FP_STAGE)] ? $::env(FP_STAGE) : 4}]
user_init_design
if {$stage == 5} {
    read_floorplan $::env(ENV_DESIGN_DIR)/floorplan/$::env(ENV_DESIGN)_floorplan_4.fp
    source $::env(FLOW_DIR)/floorplan_5.tcl
} else {
    file mkdir $::env(ENV_DESIGN_DIR)/floorplan
    write_floorplan $::env(ENV_DESIGN_DIR)/floorplan/$::env(ENV_DESIGN)_import.fp   ;# deliverable: state right after import
    source $::env(FLOW_DIR)/floorplan_4.tcl
}
