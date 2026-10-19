-- make-mutants.lua - writes the mutants the driver needs into the build directory, from the tree's own sources.
--
--    xmake l make-mutants.lua <build dir>
--
-- Kept as a script rather than as a copy in the run dir so the mutant is derived from the CURRENT port source every run, and a port
-- change that moves the anchor is a failed run rather than a stale mutant.
--
-- A MISSING ANCHOR IS A NON-ZERO EXIT AND NO MUTANT FILES. Every mutant this run wrote is taken back before the exit, so a failed run
-- leaves nothing for a later run to build. The Python file also defined clear_stale(), which nothing called; it is not ported, and the
-- sweep it describes is the one the README lists as owed.

local tsv = import("tsv", {rootdir = os.scriptdir()})

local written = {}

-- Writes a mutant AND REMEMBERS it, so a later failure can take back what this run put on disk.
local function wrote(build, name, text)
    local path = build .. "/" .. name
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
    written[#written + 1] = path
end

-- Takes back what this run wrote and exits with the message, as Python's sys.exit(message) did.
local function fail(message)
    for _, path in ipairs(written) do
        if os.isfile(path) then
            os.rm(path)
        end
    end
    io.stderr:write(message .. "\n")
    os.exit(1)
end

-- The text with the one place OLD stands replaced by NEW; the caller has counted that OLD stands once.
local function replace_once(text, old, new)
    local s, e = text:find(old, 1, true)
    return text:sub(1, s - 1) .. new .. text:sub(e + 1)
end

function main(...)
    local args = {...}
    if args[1] == nil then
        io.stderr:write("make-mutants.lua: pass the build directory\n")
        os.exit(1)
    end
    local build = args[1]
    if not os.isdir(build) then
        os.mkdir(build)
    end
    local src = os.scriptdir() .. "/../../../../packages/a/apple-backports/Security"

    local blocks = tsv.read_text(src .. "/SecProtocolOptionsBlocks13_0.m")
    local old = "    _challenge = block;\n    _challengeQueue = queue;\n}"
    local new = "    // MUTANT: the challenge block into the KEY UPDATE slot. This must NOT COMPILE.\n"
        .. "    _keyUpdate = block;\n    _keyUpdateQueue = queue;\n}"
    local count = tsv.count_of(blocks, old)
    if count ~= 1 then
        fail("make-mutants: FAILED - the blocks anchor matched " .. count .. " times, not once")
    end
    wrote(build, "mutant-blocks-challenge-into-keyupdate.m", replace_once(blocks, old, new))
    print("  mutant blocks-challenge-into-keyupdate.m: the challenge block into the key-update slot")

    -- Two more mutants, for the two cases whose crash was the whole point of F3. Without setvbuf their output was lost at the segfault
    -- and the comparator said the rows "did not measure" - naming a truncated buffer instead of the crash - so the case now dies WITH
    -- its last assertion printed.
    local data_src = tsv.read_text(src .. "/SecProtocolOptionsData13_0.m")
    local old_pair = "    if (!psk || !identity)\n        return;\n    // appended TOGETHER, so the two halves cannot fall out of step"
    local new_pair = "    // MUTANT: the pair is stored with only ONE half. A key without an identity names nothing, and the\n"
        .. "    // reader is handed a whole that is not whole.\n"
        .. "    if (!psk)\n        return;\n"
        .. "    if (!identity)\n        identity = psk;\n"
        .. "    // appended TOGETHER, so the two halves cannot fall out of step"
    count = tsv.count_of(data_src, old_pair)
    if count ~= 1 then
        fail("make-mutants: FAILED - the data anchor matched " .. count .. " times, not once")
    end
    wrote(build, "mutant-data-halfpair.m", replace_once(data_src, old_pair, new_pair))
    print("  mutant data-halfpair.m: the pair is stored with one half standing in for the other")

    -- ARC COPIES A BLOCK ON ASSIGNMENT TO A __strong IVAR, so changing the ASSIGNMENT removes nothing: the qualifier is what copies.
    -- The one edit that removes the copy is the STORAGE. The anchor below is the ivar declaration VERBATIM, indentation included.
    local held_src = tsv.read_text(src .. "/SecProtocolOptions13_0.m")
    local old_block = "    __strong sec_protocol_pre_shared_key_selection_t _pskSelection;"
    local new_block = "    __unsafe_unretained sec_protocol_pre_shared_key_selection_t _pskSelection;   // MUTANT: not strong,\n"
        .. "    // so assigning the block CANNOT copy it. A stack block is dead when the setter returns, and the\n"
        .. "    // block-survives-dead-frame row is what should catch this: either it crashes or it reads garbage."
    count = tsv.count_of(held_src, old_block)
    if count ~= 1 then
        fail("make-mutants: FAILED - the held anchor matched " .. count .. " times, not once")
    end
    wrote(build, "mutant-held-nocopy.m", replace_once(held_src, old_block, new_block))
    print("  mutant held-nocopy.m: the block is stored by pointer, so the stack frame it lived in is gone")

    -- THE IDENTITY CONTROL, and it is the only mutant that is NOT expected to change anything. It is a BYTE-IDENTICAL copy of a port
    -- source the case links, so the build succeeds, the comparison PASSES, and the driver must report it as UNNOTICED.
    local identity_src = tsv.read_text(src .. "/SecProtocolOptions13_0.m")
    wrote(build, "mutant-identity.m", identity_src)
    print("  mutant identity.m: a byte-identical copy of SecProtocolOptions13_0.m - nothing is changed")
    os.exit(0)
end
