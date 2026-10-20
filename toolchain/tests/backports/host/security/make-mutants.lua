local tsv = import("tsv", {rootdir = os.scriptdir()})

local written = {}

local function wrote(build, name, text)
    local path = build .. "/" .. name
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
    written[#written + 1] = path
end

local function fail(message)
    for _, path in ipairs(written) do
        if os.isfile(path) then
            os.rm(path)
        end
    end
    io.stderr:write(message .. "\n")
    os.exit(1)
end

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
    local src = os.scriptdir() .. "/../../../../packages/frameworks/apple-backports/Security"

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

    local identity_src = tsv.read_text(src .. "/SecProtocolOptions13_0.m")
    wrote(build, "mutant-identity.m", identity_src)
    print("  mutant identity.m: a byte-identical copy of SecProtocolOptions13_0.m - nothing is changed")
    os.exit(0)
end
