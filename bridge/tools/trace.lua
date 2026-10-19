-- trace.lua: for a fully qualified name, which file, line and enclosing type declares it.
--
--     xmake l trace.lua NAMES-FILE [--out table.tsv]      (names are `Image.ResizingMode.stretch`)
--     xmake l trace.lua --check                           (the controls below, each with its owner written by hand)
--
-- The row list a gap tool prints is a bare member name, and a bare name is not a place: `stretch` is
-- `Image.ResizingMode.stretch` and is declared as `case tile` / `case stretch` **inside** `Image` in SwiftUICore, with
-- no prefix on the line at all. So the name is looked up whole, the enclosing type is composed from the nesting - every
-- struct, enum and class pushes, every `extension X` sets the base to `X` - and the file, the line and that enclosing
-- type come out.

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})
local owners = import("lib.owners", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local MODULES = {
    Swift = true, SwiftUI = true, SwiftUICore = true, Foundation = true, CoreGraphics = true, UIKit = true,
    Combine = true, Observation = true, CoreTransferable = true, DeveloperToolsSupport = true,
}

-- the interfaces searched, in the order the names are looked up in, each with the label it is printed under
local function interfaces()
    local env = os.getenv("APPLE_26_SDK")
    local sdk = (env and env ~= "") and env or path.join(os.getenv("HOME"), "Git", "projects", "ios", "charon",
        ".agent-work", "sdk-26.2", "iPhoneOS26.2.sdk")
    local root = path.join(os.scriptdir(), "..", "..")
    local out = {}
    local groups = {
        {path.join(sdk, "System", "Library", "Frameworks", "*", "Modules", "*.swiftmodule", "arm64e-apple-ios.swiftinterface"), "26.2 arm64e"},
        {path.join(sdk, "System", "Library", "Frameworks", "*", "Modules", "*.swiftmodule", "arm64-apple-ios.swiftinterface"), "26.2 arm64"},
        {path.join(sdk, "usr", "lib", "swift", "*.swiftmodule", "arm64e-apple-ios.swiftinterface"), "26.2 arm64e stdlib"},
        {path.join(root, "bridge", "fw", "SwiftUI.framework", "Modules", "SwiftUI.swiftmodule", "*.swiftinterface"), "16.4"},
    }
    for _, group in ipairs(groups) do
        local found = os.files(group[1])
        table.sort(found)
        for _, file in ipairs(found) do
            out[#out + 1] = {file, group[2]}
        end
    end
    return out
end

-- the module prefix, if the interface wrote one, dropped: the name a caller writes has no module
local function qualified(name)
    local last = nil
    for _, at in ipairs(text.positions(name, ".")) do
        last = at
    end
    if not last then
        return name
    end
    local head, tail = string.sub(name, 1, last - 1), string.sub(name, last + 1)
    local first, _, rest = text.partition(head, ".")
    if MODULES[first] then
        if string.find(head, ".", 1, true) then
            return rest
        end
        return tail
    end
    return name
end

-- re.search(r'\b(?:static\s+|case\s+)?(?:let|var|func|case)\s+([\w_]+)', s): the name of the leftmost match, or nil
local MEMBER_KEYWORDS = {"let", "var", "func", "case"}

local function member_name(s)
    for at = 1, #s do
        if text.boundary(s, at) then
            -- the optional prefix is tried first, then the keyword straight at `at`
            local starts = {}
            for _, prefix in ipairs({"static", "case"}) do
                if text.startswith(s, prefix, at) then
                    local _, space = string.find(s, "^%s+", at + #prefix)
                    if space then
                        starts[#starts + 1] = space + 1
                    end
                end
            end
            starts[#starts + 1] = at
            for _, q in ipairs(starts) do
                for _, keyword in ipairs(MEMBER_KEYWORDS) do
                    if text.startswith(s, keyword, q) then
                        local _, space = string.find(s, "^%s+", q + #keyword)
                        local name = space and string.match(s, "^[%w_]+", space + 1)
                        if name then
                            return name
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function last_component(name)
    local parts = text.split(name, ".")
    return parts[#parts]
end

local function ends_with(s, suffix)
    return suffix == "" or string.sub(s, -#suffix) == suffix
end

-- the file, line and enclosing type that declare a fully qualified name. The line is examined before the stack is
-- popped, which the walk in lib/owners.lua already does: `case stretch` stands inside `extension SwiftUICore.Image`
-- and inside `ResizingMode`, and the owner is `Image.ResizingMode`.
local function find(name, file, label)
    local want = qualified(name)
    local member = last_component(want)
    local enclosing = ""
    local dot = nil
    for _, at in ipairs(text.positions(want, ".")) do
        dot = at
    end
    if dot then
        enclosing = string.sub(want, 1, dot - 1)
    end
    local hits = {}
    for _, row in ipairs(owners.walk(text.split(io.readfile(file), "\n"))) do
        local s = text.strip(row.line)
        if s ~= "" and not text.startswith(s, "//") and row.owner ~= nil then
            if member_name(s) == member and (enclosing == "" or ends_with(row.owner, enclosing)) then
                hits[#hits + 1] = {owner = row.owner, number = row.number, label = label}
            end
        end
    end
    return hits
end

-- the enclosing type is part of the check: a line number on its own proves nothing, and three of the five were
-- "found" under a type that has nothing to do with them
local CONTROLS = {
    {"Image.ResizingMode.stretch", "Image.ResizingMode"},
    {"Image.Orientation.up", "Image.Orientation"},
    {"Image.TemplateRenderingMode.original", "Image.TemplateRenderingMode"},
    {"Image.Interpolation.high", "Image.Interpolation"},
    {"View.symbolRenderingMode", "View"},
}

-- Python's repr of a list of strings, which the failure line prints
local function list_repr(list)
    local quoted = {}
    for i, item in ipairs(list) do
        quoted[i] = "'" .. item .. "'"
    end
    return "[" .. text.join(", ", quoted) .. "]"
end

local function check(ifaces)
    local failures = 0
    for _, control in ipairs(CONTROLS) do
        local name, wanted = control[1], control[2]
        local hits, owner_list = {}, {}
        for _, iface in ipairs(ifaces) do
            for _, hit in ipairs(find(name, iface[1], iface[2])) do
                hits[#hits + 1] = hit
                owner_list[#owner_list + 1] = hit.owner
            end
        end
        local found = false
        for _, owner in ipairs(owner_list) do
            if owner == wanted then
                found = true
            end
        end
        if found then
            for _, hit in ipairs(hits) do
                local mark = hit.owner == wanted and "ok  " or "    "
                print(string.format("%s %s  %s %d  in %s", mark, name, hit.label, hit.number, hit.owner))
            end
            if #owner_list > 1 then
                print(string.format("     (%d declarations of that name; the control wants %s)", #owner_list, wanted))
            end
        else
            local shown = #owner_list > 0 and list_repr(owner_list) or "nothing"
            print(string.format("FAIL %s  no declaration in %s; found in %s", name, wanted, shown))
            failures = failures + 1
        end
    end
    io.stderr:write(string.format("# %d of %d controls passed\n", #CONTROLS - failures, #CONTROLS))
    return failures
end

function main(...)
    local args = {...}
    if args[1] == nil then
        io.stderr:write("usage: trace.lua NAMES-FILE [--out table.tsv] | trace.lua --check\n")
        os.exit(2)
    end
    local ifaces = interfaces()
    if args[1] == "--check" then
        if check(ifaces) > 0 then
            os.exit(1)
        end
        return
    end
    local rows = {}
    for _, line in ipairs(text.split(io.readfile(args[1]), "\n")) do
        -- as the Python read it: the stripped line, skipped when it is blank or a comment in the raw line's first column
        local name = text.strip(line)
        if name ~= "" and not text.startswith(line, "#") then
            local row = nil
            for _, iface in ipairs(ifaces) do
                local hits = find(name, iface[1], iface[2])
                if #hits > 0 then
                    local hit = hits[1]
                    row = {name, hit.owner, hit.label, tostring(hit.number), ""}
                    break
                end
            end
            rows[#rows + 1] = row or {name, "(not found)", "", "", ""}
        end
    end
    if args[2] == "--out" then
        local out = {"name\textended-type\tinterface\tline\tavailability"}
        for _, row in ipairs(rows) do
            out[#out + 1] = text.join("\t", row)
        end
        io.writefile(args[3], table.concat(out, "\n") .. "\n")
    else
        for _, row in ipairs(rows) do
            print(text.join("\t", row))
        end
    end
end
