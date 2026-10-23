#!/bin/sh
cd "$(dirname "$0")" || exit 1
exec ./tools/godot --path "$PWD" res://jrpg_style_preview.tscn -- --mute
