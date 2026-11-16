"""Write scripts/levels/mosswater/mosswater_layout.json from mw_layout.py, so the Godot side
(look-dev now, the playable level in phase B) places everything from the same numbers as the
terrain, the painted ground and the plan.

    python tools/levels/mosswater/export_layout.py <out.json>
"""
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import mw_layout as L  # noqa: E402


def main(out):
    axis_s = [round(v, 6) for v in L.st_xz(1.0, 0.0)]
    axis_t = [round(v, 6) for v in L.st_xz(0.0, 1.0)]
    ponds = {}
    for name, p in L.PONDS.items():
        cx, cz = L.st_xz(*p["c"])
        ponds[name] = {"name": p["name"], "center": [round(cx, 3), p["water"], round(cz, 3)], "radius_s": p["r"][0],
                       "radius_t": p["r"][1], "water_y": p["water"], "depth": L.POND_DEPTH}
    data = {
        "generator": "tools/levels/mosswater/export_layout.py",
        "source": "tools/levels/mosswater/mw_layout.py",
        "units": "Godot metres; X east, Y up, Z south; yaw in degrees about Y, models face -Z",
        "slope_axes": {"s_up_slope": [axis_s[0], 0.0, axis_s[1]], "t_across": [axis_t[0], 0.0, axis_t[1]]},
        "tiers": {"t0": L.T0_NEAR, "t1": L.T1, "t2": L.T2},
        "markers": {k: list(v) for k, v in L.build_markers().items()},
        "ponds": ponds,
        "island": {"center": list(L.ground(*L.ISLAND["c"])), "radius": L.ISLAND["r"]},
        "spring": {"center": list(L.at(L.SPRING["c"][0], L.SPRING["c"][1], L.SPRING["water"])), "radius": L.SPRING["r"]},
        "curse_zones": L.curse_zones(),
        "lanterns": L.lanterns(),
        "fights": L.fights(),
        "stair_shelves": L.stair_shelves(),
        "gully": L.gully_pieces(),
        "trees": L.trees(),
        "props": L.props(),
        "paths": {k: [[round(x, 2), round(z, 2)] for x, z in v] for k, v in L.path_points().items()},
        "people": L.PEOPLE,
        "verse_stones": L.VERSE_STONES,
    }
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print("LAYOUT %s markers=%d trees=%d props=%d lanterns=%d" % (Path(out).name, len(data["markers"]), len(data["trees"]), len(data["props"]), len(data["lanterns"])))


if __name__ == "__main__":
    main(sys.argv[1])
