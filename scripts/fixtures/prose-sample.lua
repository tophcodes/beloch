-- Checks for scripts/prose.test.ts: the comments on line 3 and line 4 hold a
-- British spelling; the same word in code and in strings must pass. Line 3
-- names the colour of a crease.
local colour = "colour" --[[ the colour of a crease ]]
local long = [[
colour -- colour
]]
return { colour = colour, long = long }
