"""Check of lab 2, task 2: bilinear interpolation over sg13g2_inv_1 tables.

Run: python3 chk.py  (prints the results; asserts fail if they drift from the solution)
"""
from bisect import bisect_right

# sg13g2_inv_1, TIMING_DELAY_7x7ds1: rows = input transition (ns), columns = load (pF)
TR_INDEX = [0.0186, 0.0966, 0.174, 0.3294, 0.6408, 1.263, 2.5074]
C_INDEX = [0.001, 0.0234, 0.039, 0.0648, 0.108, 0.18, 0.3]

CELL_RISE = [
    [0.0205719, 0.0848296, 0.128092, 0.199447, 0.318838, 0.518101, 0.849448],
    [0.0398926, 0.127013, 0.171607, 0.2431, 0.362415, 0.561583, 0.893251],
    [0.0498247, 0.160896, 0.211178, 0.285806, 0.405313, 0.604319, 0.936677],
    [0.0622623, 0.212967, 0.275659, 0.362491, 0.490653, 0.691096, 1.02222],
    [0.0762995, 0.28615, 0.372319, 0.484795, 0.638694, 0.859707, 1.19943],
    [0.0913686, 0.380329, 0.503954, 0.661879, 0.866157, 1.14164, 1.52702],
    [0.103918, 0.495311, 0.667757, 0.894301, 1.18717, 1.55836, 2.05515],
]
RISE_TRANSITION = [
    [0.0125999, 0.100999, 0.163518, 0.267086, 0.440603, 0.729804, 1.21163],
    [0.0291065, 0.109929, 0.167666, 0.268012, 0.440723, 0.729805, 1.21164],
    [0.0406096, 0.128774, 0.18287, 0.276752, 0.443069, 0.729806, 1.21229],
    [0.0598324, 0.166797, 0.221317, 0.309827, 0.464342, 0.73765, 1.2123],
    [0.0883365, 0.235312, 0.297668, 0.389487, 0.536865, 0.79102, 1.23916],
    [0.135534, 0.342698, 0.42918, 0.53731, 0.69564, 0.942633, 1.35981],
    [0.216534, 0.499855, 0.624864, 0.783205, 0.978157, 1.25617, 1.67218],
]
CELL_FALL = [
    [0.019836, 0.0720874, 0.106541, 0.163463, 0.25875, 0.417531, 0.682264],
    [0.0395964, 0.11771, 0.155353, 0.213374, 0.308748, 0.467671, 0.732361],
    [0.0509111, 0.152159, 0.196359, 0.259989, 0.358062, 0.517105, 0.78147],
    [0.0647576, 0.203158, 0.260317, 0.337775, 0.44837, 0.614163, 0.879592],
    [0.0833724, 0.277519, 0.35476, 0.457313, 0.594908, 0.787599, 1.07128],
    [0.108019, 0.379345, 0.491028, 0.631289, 0.817653, 1.06345, 1.40298],
    [0.139839, 0.510478, 0.671114, 0.876549, 1.13745, 1.47517, 1.91999],
]
FALL_TRANSITION = [
    [0.0103362, 0.0751289, 0.121741, 0.198942, 0.328212, 0.54365, 0.902721],
    [0.0251781, 0.0888987, 0.130576, 0.202929, 0.32909, 0.543878, 0.902722],
    [0.0360123, 0.108594, 0.1498, 0.217604, 0.337463, 0.545867, 0.902781],
    [0.0531764, 0.145768, 0.189865, 0.257812, 0.369995, 0.565105, 0.908969],
    [0.0802861, 0.207273, 0.260262, 0.334456, 0.450561, 0.636779, 0.956355],
    [0.125613, 0.309892, 0.376686, 0.47094, 0.599912, 0.799092, 1.11043],
    [0.203753, 0.464283, 0.568951, 0.692645, 0.85734, 1.08762, 1.43131],
]

C_IN = 0.0028869  # pin A capacitance, pF
TR_X = 0.08       # rising input at X, ns
C_Y, C_Z = 0.03, 0.05


def lookup(table, tr, c):
    """Bilinear interpolation as in the README: first along load, then along transition."""
    i = bisect_right(TR_INDEX, tr) - 1
    j = bisect_right(C_INDEX, c) - 1
    assert 0 <= i < len(TR_INDEX) - 1 and 0 <= j < len(C_INDEX) - 1, "outside table: extrapolation"
    a = (tr - TR_INDEX[i]) / (TR_INDEX[i + 1] - TR_INDEX[i])
    b = (c - C_INDEX[j]) / (C_INDEX[j + 1] - C_INDEX[j])
    f1 = table[i][j] + b * (table[i][j + 1] - table[i][j])
    f2 = table[i + 1][j] + b * (table[i + 1][j + 1] - table[i + 1][j])
    return f1 + a * (f2 - f1)


def solve(c_inv1):
    """INV1 output falls (cell_fall), INV2/INV3 outputs rise (cell_rise)."""
    d1, t1 = lookup(CELL_FALL, TR_X, c_inv1), lookup(FALL_TRANSITION, TR_X, c_inv1)
    d2, t2 = lookup(CELL_RISE, t1, C_Y), lookup(RISE_TRANSITION, t1, C_Y)
    d3, t3 = lookup(CELL_RISE, t1, C_Z), lookup(RISE_TRANSITION, t1, C_Z)
    return {"INV1": (TR_X, c_inv1, d1, t1), "INV2": (t1, C_Y, d2, t2), "INV3": (t1, C_Z, d3, t3)}


def report(title, cells):
    print(f"\n{title}")
    print(f"{'cell':<6}{'tr_in, ns':>11}{'load, pF':>12}{'delay, ns':>12}{'tr_out, ns':>12}")
    for name, (tr, c, d, t) in cells.items():
        print(f"{name:<6}{tr:>11.6f}{c:>12.7f}{d:>12.6f}{t:>12.6f}")
    xy = cells["INV1"][2] + cells["INV2"][2]
    xz = cells["INV1"][2] + cells["INV3"][2]
    print(f"X->Y = {xy:.6f} ns   X->Z = {xz:.6f} ns   (X->Z slower by {(xz - xy) * 1e3:.2f} ps)")
    return xy, xz


branch = solve(2 * C_IN)
single = solve(C_IN)
xy, xz = report("With branch (INV1 drives INV2 + INV3)", branch)
xy0, _ = report("Without INV3 (for comparison)", single)
