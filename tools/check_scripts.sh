#!/bin/sh
# Parses every GDScript file and prints errors (run from the project root).
for f in $(find src tests -name '*.gd'); do
  out=$(timeout 60 godot --headless --check-only --script "res://$f" 2>&1 | grep -E 'SCRIPT ERROR|Parse Error' | grep -v -e 'depended scripts' -e 'Identifier not found: Game')
  [ -n "$out" ] && echo "== $f" && echo "$out"
done
echo check done
