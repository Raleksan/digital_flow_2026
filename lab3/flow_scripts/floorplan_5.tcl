# Grade 5 floorplan, run after loading blockB_floorplan_4.fp

set A_cells 11207.511   ;# lab 2 report_area
set margin  12
set die_min 200
set gap     2           ;# VDD ring to rows

# manufacturing grid 0.005
proc snap {v} {
    expr {round($v / 0.005) * 0.005}
}

# 1. Die from calculation: 50%, >= 200
set core [expr {sqrt($A_cells / 0.5)}]
set W    [expr {max($core + 2*$margin, $die_min)}]
puts "calc: core = [format %.2f $core], die = [format %.2f $W]"

# remove grade 4 blockages and power
delete_obj [get_db place_blockages]
delete_routes -net {VDD VSS} -type special
create_floorplan -site CoreSite -die_size $W $W $margin $margin $margin $margin

# real size after snapping
lassign [lindex [get_db current_design .bbox] 0] x0 y0 x1 y1
set W [expr {$x1 - $x0}]
set H [expr {$y1 - $y0}]
set L [expr {min($W, $H)}]

# 2. Ring from real die
set ring_w   [snap [expr {min(0.02*$L, 20)}]]
set ring_s   [snap [expr {min(0.01*$L, 20)}]]
set ring_off [snap [expr {min(0.02*$L, 20)}]]
set t [expr {$ring_off + 2*$ring_w + $ring_s + $gap}]
puts "ring: w = $ring_w, s = $ring_s, o = $ring_off, cut t = $t"

# 3. Pins on Metal3, sorted so bit 0 is at the bottom
set data [lsort -dictionary [get_db [get_db ports data_in*] .name]]
set ctrl {rst_n clear valid_in}
set outs [lsort -dictionary [get_db [get_db ports -if {.direction==out}] .name]]

edit_pin -pin clk   -side Top    -layer Metal3 -spread_type center -fix_overlap 1
edit_pin -pin $ctrl -side Bottom -layer Metal3 -spread_type center -spacing 2 -unit micron -fix_overlap 1

# -spread_type range ignores -start/-end, so start + pitch (track 0.42), die 199.92:
#   data 32 pins, 35..65%, pitch 1.68 -> 73.92..126.00
#   outs 112 pins, 10..90%, pitch 1.26 -> 30.24..170.10
edit_pin -pin $data -side Left -layer Metal3 -spread_type start -spacing 1.68 -unit micron \
    -start [list $x0 73.92] -spread_direction clockwise -fix_overlap 1
edit_pin -pin $outs -side Right -layer Metal3 -spread_type start -spacing 1.26 -unit micron \
    -start [list $x1 30.24] -spread_direction counterclockwise -fix_overlap 1
check_pin_assignment

# 4. Ring (VSS outside) and center pair
connect_global_net VDD -type pg_pin -pin_base_name VDD -inst_base_name *
connect_global_net VSS -type pg_pin -pin_base_name VSS -inst_base_name *
add_rings -nets {VSS VDD} -type core_rings -follow io \
    -layer {top TopMetal1 bottom TopMetal1 left TopMetal2 right TopMetal2} \
    -width $ring_w -spacing $ring_s -offset $ring_off

# VDD left, VSS right, centered
add_stripes -nets {VDD VSS} -layer TopMetal2 -direction vertical \
    -width $ring_w -spacing $ring_s -number_of_sets 1 \
    -start_from left -start [expr {$x0 + $W/2.0 - $ring_w - $ring_s/2.0}]

# 5. Cut rows by t, before route_special: core edge is under the VDD ring
split_row -area [list $x0 $y0 [expr {$x0+$t}] $y1]
split_row -area [list [expr {$x1-$t}] $y0 $x1 $y1]
split_row -area [list [expr {$x0+$t}] $y0 [expr {$x1-$t}] [expr {$y0+$t}]]
split_row -area [list [expr {$x0+$t}] [expr {$y1-$t}] [expr {$x1-$t}] $y1]

# follow pins
route_special -connect core_pin -nets {VDD VSS} -core_pin_target first_after_row_end \
    -allow_jogging 1 -allow_layer_change 1 \
    -layer_change_range {Metal1 TopMetal2} -crossover_via_layer_range {Metal1 TopMetal2}

# 6. A-B hard placement, C-D routing Metal3
set AB [list [snap [expr {$x0 + 0.20*$W}]] [snap [expr {$y0 + 0.57*$H}]] \
             [snap [expr {$x0 + 0.36*$W}]] [snap [expr {$y0 + 0.74*$H}]]]
set CD [list [snap [expr {$x0 + 0.65*$W}]] [snap [expr {$y0 + 0.27*$H}]] \
             [snap [expr {$x0 + 0.81*$W}]] [snap [expr {$y0 + 0.44*$H}]]]
# default snap "inst" grows A-B to rows
set_db floorplan_snap_place_blockage_grid manufacturing
create_place_blockage -type hard -name blk_AB -area $AB
create_route_blockage -name blk_CD -layers Metal3 -rects [list $CD]
puts "A-B: $AB, C-D: $CD"

# 7. Areas for the report
set a_cells 0
foreach a [get_db insts .area] {
    set a_cells [expr {$a_cells + $a}]
}
lassign [lindex [get_db current_design .core_bbox] 0] cx0 cy0 cx1 cy1
set a_core [expr {($cx1 - $cx0) * ($cy1 - $cy0)}]
set a_rows 0
foreach r [get_db rows .rect] {
    lassign [concat {*}$r] rx0 ry0 rx1 ry1
    set a_rows [expr {$a_rows + ($rx1 - $rx0) * ($ry1 - $ry0)}]
}
lassign $AB ax0 ay0 ax1 ay1
set a_ab [expr {($ax1 - $ax0) * ($ay1 - $ay0)}]
puts [format "A_cells = %.1f, A_core = %.1f, U_core = %.1f%%" $a_cells $a_core [expr {100*$a_cells/$a_core}]]
puts [format "A_rows = %.1f, U_rows = %.1f%%, A_AB = %.1f" $a_rows [expr {100*$a_cells/$a_rows}] $a_ab]

# 8. Check, save
check_floorplan
check_connectivity -nets {VDD VSS} -type special
check_drc
file mkdir $::env(ENV_DESIGN_DIR)/floorplan
write_floorplan $::env(ENV_DESIGN_DIR)/floorplan/$::env(ENV_DESIGN)_floorplan_5.fp
