local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/carry_audit.lua REFERENCE [--tree DIR] [PATH ...]
  lists the sources whose port markers thinned out against REFERENCE, another WebKit tree carrying the
  port - the webkit package before the series was moved to a newer base, or a checkout of the old fork.
  The tree audited is the installed webkit package's unless --tree names one. A file with fewer markers
  than the reference is an upstream refactor or a carry the move dropped, and is worth reading before a
  release.]]

local markers = {"WEBKIT_IOS6", "USE(JSVALUE64)", "JSVALUE32_64", "CPU(ARM_THUMB2)", "payloadGPR", "tagGPR"}
local suffixes = {".cpp", ".h", ".mm", ".m", ".asm"}
local defaults = {"Source/WebCore", "Source/WebKitLegacy", "Source/JavaScriptCore", "Source/WTF"}

local function count(file)
    local found = 0
    for line in io.readfile(file, {encoding = "binary"}):gmatch("[^\n]*") do
        for _, marker in ipairs(markers) do
            if line:find(marker, 1, true) then
                found = found + 1
                break
            end
        end
    end
    return found
end

local function source(file)
    for _, suffix in ipairs(suffixes) do
        if file:endswith(suffix) then
            return true
        end
    end
    return false
end

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local given, rest = tree.arguments({...}, {tree = "value", help = "switch"})
    if given.help or #rest == 0 then
        print(USAGE)
        return
    end
    local reference = path.absolute(table.remove(rest, 1))
    if not os.isdir(reference) then
        raise("%s is not a folder holding a WebKit tree", reference)
    end
    local here = tree.engine_source(given.tree)
    local gaps = 0
    for _, area in ipairs(#rest > 0 and rest or defaults) do
        for _, file in ipairs(os.files(path.join(reference, area, "**"))) do
            if source(file) then
                local relative = path.relative(file, reference)
                local local_file = path.join(here, relative)
                local there = count(file)
                if there > 0 and os.isfile(local_file) then
                    local found = count(local_file)
                    if found < there then
                        print(string.format("%-4s %s (the reference has %d, here %d)", "-" .. (there - found), relative, there, found))
                        gaps = gaps + 1
                    end
                end
            end
        end
    end
    print(string.format("%d files carry fewer markers than the reference", gaps))
end
