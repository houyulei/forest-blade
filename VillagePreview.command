#!/bin/sh
cd "$(dirname "$0")" || exit 1
exec ./tools/godot --path "$PWD" "$@"
