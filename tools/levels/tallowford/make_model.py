"""Builds one Tallowford model; see tf_models.py.

    blender --background --factory-startup --python tools/levels/tallowford/make_model.py -- <name> <out.glb> <paintmap.json>
"""
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tf_models  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
tf_models.build(args[0], args[1], args[2])
