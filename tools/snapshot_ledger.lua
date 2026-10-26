local root = path.absolute(path.directory(os.scriptdir()))

local PROBE = path.join(root, "emulator", "src", "kernel", "snapshot_census.cpp")
local DESCRIBED = {
    path.join(root, "emulator", "src", "foundation", "virtual_clock.cpp"),
    path.join(root, "emulator", "src", "network", "wifi_state.cpp"),
}
local LEDGER = path.join(root, "emulator", "src", "kernel", "include", "kernel", "snapshot_ledger.hpp")
local BOOTED = path.join(root, "emulator", "src", "kernel", "test", "kernel_snapshot_booted_members.hpp")

local USAGE = [[usage: ./xmakew l tools/snapshot_ledger.lua [check]

Reads the kernel snapshot ledger in kernel_snapshot_probe_test.cpp, the names the probe
emits and the booted-state list, then prints how the ledger covers them. With check, the
exit status is 1 when a name populated at boot is still open, or a probe name is in no
list.]]

local function names_in(text)
    local found = {}
    for name in text:gmatch('"([%a][%w_]*%.[%w_]+)"') do
        found[#found + 1] = name
    end
    return found
end

local function coverage_names(text, coverage)
    local found = {}
    for name, kind in text:gmatch('{"([^"]+)", Coverage::(%a+)}') do
        if kind == coverage then
            found[#found + 1] = name
        end
    end
    return found
end

local function array_names(text, identifier)
    local start = text:find("constexpr std::array<std::string_view, %d+> " .. identifier .. " {")
    if not start then
        start = text:find("inline constexpr std::array<std::string_view, %d+> " .. identifier .. " {")
    end
    if not start then
        raise("no array named " .. identifier)
    end
    local body = text:sub(text:find("{", start, true) + 1, text:find("};", start, true) - 1)
    return names_in(body)
end

local function set_of(list)
    local set = {}
    for _, name in ipairs(list) do
        set[name] = true
    end
    return set
end

local function sorted_keys(set)
    local keys = {}
    for name in pairs(set) do
        keys[#keys + 1] = name
    end
    table.sort(keys)
    return keys
end

function main(...)
    local arguments = {...}
    local strict = false
    for _, argument in ipairs(arguments) do
        if argument == "check" then
            strict = true
        elseif argument == "help" or argument == "--help" then
            print(USAGE)
            return
        else
            raise("unknown argument " .. argument .. "\n" .. USAGE)
        end
    end

    local ledger = io.readfile(LEDGER)
    local saved = coverage_names(ledger, "saved")
    local open = coverage_names(ledger, "open")
    local wired = coverage_names(ledger, "wired")
    local refused = coverage_names(ledger, "refused")
    local sources = io.readfile(PROBE)
    for _, file in ipairs(DESCRIBED) do
        sources = sources .. io.readfile(file)
    end
    local probe = set_of(names_in(sources))
    local booted = array_names(io.readfile(BOOTED), "booted_populated_members")

    local accounted = {}
    for _, list in ipairs({saved, open, wired, refused}) do
        for _, name in ipairs(list) do
            accounted[name] = true
        end
    end

    local open_set = set_of(open)
    local open_booted = {}
    for _, name in ipairs(booted) do
        if open_set[name] then
            open_booted[#open_booted + 1] = name
        end
    end
    table.sort(open_booted)

    local unaccounted_probe = {}
    for _, name in ipairs(sorted_keys(probe)) do
        if not accounted[name] then
            unaccounted_probe[#unaccounted_probe + 1] = name
        end
    end

    local stale = {}
    local probed = set_of(sorted_keys(probe))
    for _, list in ipairs({saved, open, wired, refused}) do
        for _, name in ipairs(list) do
            if not probed[name] then
                stale[#stale + 1] = name
            end
        end
    end

    print(string.format("ledger: %d saved, %d open, %d wired, %d refused",
        #saved, #open, #wired, #refused))
    print(string.format("probe names: %d, booted populated names: %d", #sorted_keys(probe), #booted))
    print(string.format("open and populated at boot: %d", #open_booted))
    for _, name in ipairs(open_booted) do
        print("  open " .. name)
    end
    print(string.format("probe names in no ledger list: %d", #unaccounted_probe))
    for _, name in ipairs(unaccounted_probe) do
        print("  unaccounted " .. name)
    end
    print(string.format("ledger names the probe never emits: %d", #stale))
    for _, name in ipairs(stale) do
        print("  stale " .. name)
    end

    if strict and (#open_booted > 0 or #unaccounted_probe > 0) then
        raise("%d populated names are open and %d probe names are unaccounted",
            #open_booted, #unaccounted_probe)
    end
end
