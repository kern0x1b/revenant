local root = path.directory(path.directory(path.absolute(os.scriptdir())))
local modules = path.join(root, "modules")

import("core.base.json")
import("byteorder", {rootdir = modules})
import("workspace", {rootdir = modules})

local LLVM = "llvm 23.1.3"

local function version_key(text)
    local key = {}
    for part in text:gmatch("[^%.]+") do
        table.insert(key, tonumber(part))
    end
    return key
end

local function version_less(a, b)
    local x, y = version_key(a), version_key(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or -1, y[i] or -1
        if p ~= q then
            return p < q
        end
    end
    return false
end

local function sources(out)
    local registry = path.join(root, "..", "packages", "frameworks", "apple-backports", "registry")
    local libraries = {}
    for line in io.lines(path.join(modules, "apple", "backports.lua")) do
        local name, folder = line:match('name = "([A-Za-z]+Backports)", folder = "([A-Za-z]+)"')
        if name then
            table.insert(libraries, {name = name, folder = folder})
        end
    end
    local plan = {}
    for _, lib in ipairs(libraries) do
        local folder = lib.folder
        local files = {}
        local d = path.join(registry, folder)
        if os.isdir(d) then
            files = os.files(path.join(d, "*.json"))
            byteorder.sort(files)
        end
        local single = path.join(registry, folder .. ".json")
        if os.isfile(single) then
            table.insert(files, single)
        end
        local bands, floors = {}, {}
        for _, f in ipairs(files) do
            local held = json.decode(io.readfile(f))
            for _, e in ipairs(held.entries or held) do
                if e.kind == "protocol" and e.status == "implemented" then
                    local intro = e.introduced
                    if intro == nil or intro == "" then
                        intro = "0"
                    end
                    if e.api == nil then
                        raise("%s: a protocol row has no api", f)
                    end
                    bands[intro] = bands[intro] or {}
                    table.insert(bands[intro], e.api)
                    local m = e.minimum
                    if m ~= nil and m ~= "" and (floors[intro] == nil or version_less(floors[intro], m)) then
                        floors[intro] = m
                    end
                end
            end
        end
        local intros = {}
        for intro in pairs(bands) do
            table.insert(intros, intro)
        end
        table.sort(intros, version_less)
        for _, intro in ipairs(intros) do
            local names = bands[intro]
            byteorder.sort(names)
            local base = lib.name .. "Protocols" .. intro
            local body = {
                string.format("// %s.m - written by modules/apple/backports.lua, not by hand.", base),
                string.format('#import "Revenant%sProtocols.h"', folder), "",
                string.format("static void revenant_%s_protocols(void) __attribute__((used));", lib.name),
                string.format("static void revenant_%s_protocols(void)", lib.name), "{"
            }
            for _, n in ipairs(names) do
                table.insert(body, string.format("    (void)@protocol(%s);", n))
            end
            table.insert(body, "}")
            table.insert(body, "")
            local target = path.join(out, "src", base .. ".m")
            io.writefile(target, table.concat(body, "\n"))
            table.insert(plan, {file = target, base = base, folder = folder, minimum = floors[intro] or "6.0"})
        end
    end
    return plan
end

local function header(out, folder)
    local dir = path.join(out, "hdr", folder)
    if os.isfile(path.join(dir, "Revenant" .. folder .. "Protocols.h")) then
        return
    end
    os.mkdir(dir)
    local err = path.join(out, "hdr", folder .. ".err")
    local status = os.execv(os.programfile(), {"l", path.join(root, "tools", "gen.lua"), "protocolheaders", "--tree", root,
                                               "--framework", folder, "--out", dir},
                            {stdout = os.nuldev(), stderr = err, try = true})
    if status ~= 0 then
        local last = ""
        for line in io.readfile(err):gmatch("[^\n]+") do
            last = line
        end
        print("protocol-sources: tools/gen could not write the header of %s: %s", folder, last)
    end
end

local function compile(clang, sdk, out, entry)
    local target = "armv7-apple-ios" .. entry.minimum
    local diag = path.join(out, "obj", entry.base .. ".diag")
    local status = os.execv(clang, {"-target", target, "-isysroot", sdk, "-fobjc-arc", "-Os", "-g0", "-Wall",
                                    "-Wno-unguarded-availability-new", "-Wno-unguarded-availability",
                                    "-I" .. path.join(out, "hdr", entry.folder),
                                    "-I" .. path.join(root, "..", "packages", "frameworks", "apple-backports", entry.folder),
                                    "-c", entry.file, "-o", path.join(out, "obj", entry.base .. ".o")},
                            {stderr = diag, try = true})
    if status == 0 then
        return true
    end
    local first = ""
    for line in io.readfile(diag):gmatch("[^\n]+") do
        if line:find("error:", 1, true) and first == "" then
            first = line
        end
    end
    print("FAIL %s.m (%s, %s): %s", entry.base, target, entry.folder, first)
    return false
end

local function libraries_of(plan)
    local seen, count = {}, 0
    for _, entry in ipairs(plan) do
        if not seen[entry.folder] then
            seen[entry.folder] = true
            count = count + 1
        end
    end
    return count
end

function main(sdk, out)
    assert(sdk and out, "usage: xmake l toolchain/tests/addon/protocol-sources.lua <sdk> <out>")
    local clang = path.join(workspace.package_of(LLVM, true), "bin", "clang")
    assert(os.isexec(clang), "protocol-sources: %s has no clang at %s", LLVM, clang)
    os.tryrm(out)
    os.mkdir(path.join(out, "src"))
    os.mkdir(path.join(out, "obj"))
    local plan = sources(out)
    print(string.format("%d protocol sources over %d libraries", #plan, libraries_of(plan)))
    local examined, fail = 0, 0
    for _, entry in ipairs(plan) do
        header(out, entry.folder)
        examined = examined + 1
        if not compile(clang, sdk, out, entry) then
            fail = fail + 1
        end
    end
    if examined == 0 then
        print("protocol-sources: FAIL - 0 protocol sources examined, so nothing was compiled; the registry is")
        print("  " .. path.join(root, "..", "packages", "frameworks", "apple-backports", "registry") .. " and the libraries are read from")
        print("  " .. path.join(modules, "apple", "backports.lua"))
        os.exit(2)
    end
    local libraries = libraries_of(plan)
    print(string.format("examined: %d protocol sources over %d %s, each at the triple of its rows' minimum", examined, libraries,
                        libraries == 1 and "library" or "libraries"))
    if fail == 0 then
        print(string.format("protocol-sources: OK - %d of %d protocol sources compile for armv7 against %s", examined, examined, sdk))
        return
    end
    print(string.format("protocol-sources: FAIL - %d of %d protocol sources do not compile", fail, examined))
    os.exit(fail)
end
