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
