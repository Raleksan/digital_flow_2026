# ################
# WORST
# ################
set lib_list_worst {}

lappend lib_list_worst " $::env(PDK_DIR)/IHP_Open_PDK/sg13g2_stdcell/lib/sg13g2_stdcell_slow_1p08V_125C.lib"

create_rc_corner -name worst -temperature {125} -pre_route_res {1} -pre_route_cap {1} -pre_route_clock_res {0} -pre_route_clock_cap {0} -post_route_res {1} -post_route_cap {1} -post_route_cross_cap {1} -post_route_clock_res {0} -post_route_clock_cap {0}
create_library_set -name worst -timing $lib_list_worst
create_opcond -name worst -process {1} -voltage {1.08} -temperature {125}
create_timing_condition -name worst -opcond {worst} -library_sets {worst}
create_delay_corner -name worst -timing_condition {worst} -rc_corner {worst}

# ################
# TYP
# ################
set lib_list_typ {}

lappend lib_list_typ  " $::env(PDK_DIR)/IHP_Open_PDK/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"

create_rc_corner -name typ -temperature {25} -pre_route_res {1} -pre_route_cap {1} -pre_route_clock_res {0} -pre_route_clock_cap {0} -post_route_res {1} -post_route_cap {1} -post_route_cross_cap {1} -post_route_clock_res {0} -post_route_clock_cap {0}
create_library_set -name typ -timing $lib_list_typ
create_opcond -name typ -process {1} -voltage {1.20} -temperature {25}
create_timing_condition -name typ -opcond {typ} -library_sets {typ}
create_delay_corner -name typ -timing_condition {typ} -rc_corner {typ}

# ################
# BEST
# ################
set lib_list_best {}

lappend lib_list_best  " $::env(PDK_DIR)/IHP_Open_PDK/sg13g2_stdcell/lib/sg13g2_stdcell_fast_1p65V_40C.lib"

create_rc_corner -name best -temperature {40} -pre_route_res {1} -pre_route_cap {1} -pre_route_clock_res {0} -pre_route_clock_cap {0} -post_route_res {1} -post_route_cap {1} -post_route_cross_cap {1} -post_route_clock_res {0} -post_route_clock_cap {0}
create_library_set -name best -timing $lib_list_best
create_opcond -name best -process {1} -voltage {1.65} -temperature {40}
create_timing_condition -name best -opcond {best} -library_sets {best}
create_delay_corner -name best -timing_condition {best} -rc_corner {best}

# ################
# FINAL 
# ################

create_constraint_mode -name func -sdc_files "$::env(ENV_DESIGN_DIR)/$::env(ENV_DESIGN).sdc"
create_analysis_view -name view_worst -constraint_mode {func} -delay_corner {worst}
create_analysis_view -name view_best -constraint_mode {func} -delay_corner {best}
set_analysis_view -setup {view_worst} -hold {view_best}