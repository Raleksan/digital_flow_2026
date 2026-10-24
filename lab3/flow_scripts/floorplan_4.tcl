# Grade 4 floorplan, run after user_init_design

set margin  20
set die_min 200

# ring inner edge: 4+4+2+4 = 14 from die
set ring_w   4
set ring_s   2
set ring_off 4
set frame   14

# 1. Floorplan 50%, 1:1
create_floorplan -site CoreSite -core_density_size 1.0 0.5 $margin $margin $margin $margin

# die >= 200x200
lassign [lindex [get_db current_design .bbox] 0] x0 y0 x1 y1
set w [expr {$x1 - $x0}]
set h [expr {$y1 - $y0}]
if {$w < $die_min || $h < $die_min} {
    create_floorplan -site CoreSite \
        -die_size [expr {max($w, $die_min)}] [expr {max($h, $die_min)}] \
        $margin $margin $margin $margin
}
lassign [lindex [get_db current_design .bbox] 0] x0 y0 x1 y1

# 2. Pins: inputs left, outputs right
set ins  [get_db [get_db ports -if {.direction==in}] .name]
set outs [get_db [get_db ports -if {.direction==out}] .name]
edit_pin -pin $ins  -side Left  -layer Metal4 -spread_type center -spacing 1 -unit micron -fix_overlap 1
edit_pin -pin $outs -side Right -layer Metal4 -spread_type side -fix_overlap 1

# 3. Ring, first net is outer: VSS outside
connect_global_net VDD -type pg_pin -pin_base_name VDD -inst_base_name *
connect_global_net VSS -type pg_pin -pin_base_name VSS -inst_base_name *
add_rings -nets {VSS VDD} -type core_rings -follow io \
    -layer {top TopMetal1 bottom TopMetal1 left TopMetal2 right TopMetal2} \
    -width $ring_w -spacing $ring_s -offset $ring_off

# 4. Follow pins
route_special -connect core_pin -nets {VDD VSS} -core_pin_target first_after_row_end \
    -allow_jogging 1 -allow_layer_change 1 \
    -layer_change_range {Metal1 TopMetal2} -crossover_via_layer_range {Metal1 TopMetal2}

# 5. Hard blockage frame 14 um
# frame is outside core (margin 20 > 14), without -no_cut_by_core it is dropped
# default snap "inst" moves the frame past the die edge
set_db floorplan_snap_place_blockage_grid manufacturing
create_place_blockage -no_cut_by_core -type hard -name perim_L \
    -area [list $x0 $y0 [expr {$x0+$frame}] $y1]
create_place_blockage -no_cut_by_core -type hard -name perim_R \
    -area [list [expr {$x1-$frame}] $y0 $x1 $y1]
create_place_blockage -no_cut_by_core -type hard -name perim_B \
    -area [list [expr {$x0+$frame}] $y0 [expr {$x1-$frame}] [expr {$y0+$frame}]]
create_place_blockage -no_cut_by_core -type hard -name perim_T \
    -area [list [expr {$x0+$frame}] [expr {$y1-$frame}] [expr {$x1-$frame}] $y1]

# 6. Check, save
check_floorplan
check_connectivity -nets {VDD VSS} -type special
file mkdir $::env(ENV_DESIGN_DIR)/floorplan
write_floorplan $::env(ENV_DESIGN_DIR)/floorplan/$::env(ENV_DESIGN)_floorplan_4.fp
