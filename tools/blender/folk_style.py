"""Shared style data for the paper folk (tools/blender/make_folk.py and
tools/textures/painted/paint_folk.py): body sizes, builds, palettes and the defaults a cast spec
falls back on. Plain Python, no Blender, so the painter can import it too.

A cast spec is a JSON file:

    {
      "models": "assets/levels/tallowford/folk",        glb files (and their import registry)
      "textures": "assets/levels/tallowford/folk",      painted atlases, <name>.png and <name>_faded.png
      "scenes": "scenes/levels/tallowford/folk",        wrapper scenes, <name>.tscn
      "people": {
        "old_wick": {"size": "elder", "build": "slim", "garment": "robe", "hat": "none",
                     "prop": "lantern", "palette": "ochre", "colours": {"trim": "#7a2f22"}, "seed": 4}
      }
    }

Every key of a person is optional; see PERSON_DEFAULTS.
"""
import json

SIZES = {
    # height, leg, head, shoulder half-width, hip half-width, arm length, torso depth, stoop (deg)
    "adult": dict(height=1.66, leg=0.80, head=0.25, shoulder=0.205, hip=0.15, arm=0.64, depth=0.11, stoop=0.0),
    "elder": dict(height=1.54, leg=0.72, head=0.245, shoulder=0.195, hip=0.155, arm=0.6, depth=0.115, stoop=-16.0),
    "child": dict(height=1.06, leg=0.44, head=0.25, shoulder=0.135, hip=0.11, arm=0.4, depth=0.085, stoop=0.0),
}
BUILDS = {"slim": 0.85, "average": 1.0, "stout": 1.25}
GARMENTS = ("robe", "tunic", "apron")
HATS = ("none", "paper_boat", "wide_brim", "scarf", "cap")
PROPS = ("none", "lantern", "pole", "bucket", "basket", "scroll")

# Muted, dyed-cloth palettes; skin is warm paper, hair is ink. Every colour can be overridden.
PALETTES = {
    "indigo": {"garment": "4a5d7a", "trim": "d9cfb4", "legs": "3b4152", "hat": "ece3cd", "prop": "6b5442"},
    "madder": {"garment": "a8483a", "trim": "e2c27a", "legs": "4a3b34", "hat": "d8c39a", "prop": "5a4a3c"},
    "ochre": {"garment": "b88d45", "trim": "5d4a36", "legs": "4f4337", "hat": "c9b48a", "prop": "5a4a3c"},
    "moss": {"garment": "6f7d4f", "trim": "c7b78f", "legs": "3f4434", "hat": "a99a6c", "prop": "6b5442"},
    "ash": {"garment": "77736b", "trim": "b9b2a2", "legs": "3c3a36", "hat": "8f897d", "prop": "4d4640"},
    "persimmon": {"garment": "d0703a", "trim": "f0e2c0", "legs": "4c4038", "hat": "ece3cd", "prop": "6b5442"},
}
COMMON = {"skin": "efe4cc", "hair": "2a2626", "shoe": "3a332d", "lamp": "f2c46b"}

PERSON_DEFAULTS = {
    "size": "adult", "build": "average", "garment": "tunic", "hat": "none", "prop": "none",
    "palette": "indigo", "colours": {}, "seed": 1, "texture_size": 512,
}


def person(spec, name):
    """The full description of one person: defaults, size and build numbers, and colours."""
    p = dict(PERSON_DEFAULTS)
    p.update(spec["people"][name])
    p["name"] = name
    for key, allowed in (("size", SIZES), ("build", BUILDS), ("garment", GARMENTS), ("hat", HATS),
                         ("prop", PROPS), ("palette", PALETTES)):
        if p[key] not in allowed:
            raise ValueError("%s: %s must be one of %s, not %r" % (name, key, ", ".join(allowed), p[key]))
    p["dims"] = dict(SIZES[p["size"]])
    p["width"] = BUILDS[p["build"]]
    colours = dict(COMMON)
    colours.update(PALETTES[p["palette"]])
    colours.update({k: v.lstrip("#") for k, v in p["colours"].items()})
    p["colours"] = colours
    p["material"] = "M_folk_%s" % name
    return p


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def paths(spec, name):
    """Output paths of one person, repository-relative."""
    return {
        "glb": "%s/%s.glb" % (spec["models"], name),
        "texture": "%s/%s.png" % (spec["textures"], name),
        "faded": "%s/%s_faded.png" % (spec["textures"], name),
        "scene": "%s/%s.tscn" % (spec["scenes"], name),
        "paintmap": ".userdata/paintmaps/folk_%s.json" % name,
    }


ANIMATIONS = ("idle", "talk", "walk", "faded")
LOOPING = ("idle", "talk", "walk", "faded")


def scene_name(name):
    return "".join(part.capitalize() for part in name.split("_"))


if __name__ == "__main__":
    import sys
    spec = load(sys.argv[1])
    for n in spec["people"]:
        person(spec, n)
    print(" ".join(spec["people"]))
