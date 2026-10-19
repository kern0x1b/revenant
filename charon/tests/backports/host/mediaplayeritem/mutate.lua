-- mutate.lua: mutate one of the port's MPMediaItem files, and refuse to write a mutation that changed nothing.
--
-- The isPreorder mutant of the 10.3 group came out green once, and the reason was not the port: the substitution
-- did not match the file, so the "mutant" was the source and the contract passed on it. A mutation that does not
-- mutate is worse than no mutation, because it is counted as one. So this writes the mutant, compares it with the
-- source, and fails if they are the same, and prints the difference so what was mutated is on the record.
--
--   xmake l tests/backports/host/mediaplayeritem/mutate.lua <file> <from> <to> <scratch>
--
-- A mutation that changes the bytes is not yet a mutant. Removing an @synthesize changes the file and leaves ARC
-- synthesising the same property, and a check that correctly stays green is not a failure of the check. So the
-- gate above is a byte comparison of the file, and it is not enough on its own: a caller must also show that the
-- check's verdict moved. The verdict change is printed by hand, both with the mutation and without it:
--
--   xcrun clang -fobjc-arc -framework Foundation -I tests/backports/host/mediaplayeritem \
--       -I <the tree carrying the mutation> -o .agent-work/runs/mutate/mutant <the check>.m
--   .agent-work/runs/mutate/mutant | grep -E "RED|: OK"      # and the same against the source tree
--
-- The library's siblings are copied into the scratch directory beside the mutant, because the check includes
-- files of the library by name.

local LIBRARY = {"packages", "a", "apple-backports", "MediaPlayer"}
local GROUPS = {"MPMediaItem70.m", "MPMediaItem80.m", "MPMediaItem92.m", "MPMediaItem100.m", "MPMediaItem103.m"}

local function read(file)
    return io.readfile(file, {encoding = "binary"})
end

-- every occurrence of `needle` in `text`, as start and stop indices
local function occurrences(text, needle)
    local found = {}
    local at = 1
    while true do
        local first, last = text:find(needle, at, true)
        if first == nil then
            break
        end
        table.insert(found, {first, last})
        at = first + 1
    end
    return found
end

function main(...)
    local args = {...}
    if #args ~= 4 then
        raise("usage: xmake l tests/backports/host/mediaplayeritem/mutate.lua <file> <from> <to> <scratch>")
    end
    local name, before, after, scratch = args[1], args[2], args[3], args[4]
    local root = path.absolute(path.join(os.scriptdir(), "..", "..", "..", ".."))
    local library = path.join(root, table.unpack(LIBRARY))
    local source = path.join(library, name)
    local text = read(source)
    local found = occurrences(text, before)
    if #found == 0 then
        raise("FAIL: %s does not contain %q, so this is not a mutation of the port's code and the contract would have passed on the source", name, before)
    end
    if #found ~= 1 then
        raise("FAIL: %s contains %q %d times, so a mutation here would not say which getter changed", name, before, #found)
    end
    os.tryrm(scratch)
    os.mkdir(scratch)
    for _, group in ipairs(GROUPS) do
        os.cp(path.join(library, group), path.join(scratch, group))
    end
    local mutant = path.join(scratch, name)
    local first, last = found[1][1], found[1][2]
    io.writefile(mutant, text:sub(1, first - 1) .. after .. text:sub(last + 1), {encoding = "binary"})
    if read(mutant) == text then
        raise("FAIL: the mutant is byte for byte the source, so nothing was mutated")
    end
    print(string.format("mutated %s: %q -> %q", name, before, after))
    -- the difference, one line of context, as diff -u prints it; the labels are the ones the mutant report uses
    local diffout = path.join(scratch, name .. ".diff")
    os.execv("diff", {"-u", "-U1", "-L", "source/" .. name, "-L", "mutant/" .. name, source, mutant},
             {try = true, stdout = diffout})
    for line in io.lines(diffout) do
        print("  " .. line)
    end
    os.rm(diffout)
end
