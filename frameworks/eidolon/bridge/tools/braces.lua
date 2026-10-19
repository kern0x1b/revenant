-- braces.lua: the depth a Swift file ends at, counted from stdin with the braces lib/braces.lua reads as Swift.
--
--     xmake l braces.lua < file.swift
--
-- A brace in a string or a comment moves no depth; a block comment or a multi-line literal carries its state to the
-- next line. ours-check.lua has the controls for each of those.

local braces = import("lib.braces", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

function main(...)
    local depth, in_block, in_multiline, hashes = 0, false, false, 0
    while true do
        local line = io.read("l")
        if line == nil then
            break
        end
        local opened, closed
        opened, closed, in_block, in_multiline, hashes = braces.braces(line, in_block, in_multiline, hashes)
        depth = depth + opened - closed
    end
    print(depth)
end
