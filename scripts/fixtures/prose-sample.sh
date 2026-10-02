#!/usr/bin/env bash
# Checks for scripts/prose.test.ts: the comments on line 4 and line 7 hold a
# British spelling; the same word in code and in strings must pass. Line 4
# names the colour of a crease.
colour='colour # colour
colour' count=${#colour}
echo "$colour" "colour # colour" # the colour of a crease
