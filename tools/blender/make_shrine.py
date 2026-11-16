"""Builds the shrine prop; see props.py.

    blender --background --factory-startup --python tools/blender/make_shrine.py -- <out.glb> <paintmap.json>
"""
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402

props.build("shrine")
