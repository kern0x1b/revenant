local MODULES = path.join(os.scriptdir(), "..", "..", "modules")
local byteorder = import("byteorder", {rootdir = MODULES, anonymous = true})
local workspace = import("workspace", {rootdir = MODULES, anonymous = true})
local sw = import("surface_walk", {rootdir = os.scriptdir(), anonymous = true})

local USAGE = "usage: xmake l tools/corpus/surface-diff.lua [--sdk SDK] [--target TARGET] [--registry REGISTRY] [--above ABOVE] [--up-to UP_TO] [--release RELEASE] [--list] [--rows ROWS] frameworks [frameworks ...]"

local function parse_options(arguments)
    local valued = {sdk = true, target = true, registry = true, above = true, ["up-to"] = true, release = true, rows = true}
    local options = {above = "6.0", frameworks = {}}
    local index = 1
    while index <= #arguments do
        local argument = arguments[index]
        local name, value = argument:match("^%-%-([%w-]+)=(.*)$")
        if name == nil then
            name = argument:match("^%-%-([%w-]+)$")
        end
        if name and valued[name] then
            if value == nil then
                index = index + 1
                value = arguments[index]
                if value == nil then
                    raise("%s: argument --%s: expected one argument", USAGE, name)
                end
            end
            options[name] = value
        elseif name == "list" and value == nil then
            options.list = true
        elseif argument:sub(1, 1) == "-" and #argument > 1 then
            raise("%s: unrecognized arguments: %s", USAGE, argument)
        else
            table.insert(options.frameworks, argument)
        end
        index = index + 1
    end
    if #options.frameworks == 0 then
        raise("%s: the following arguments are required: frameworks", USAGE)
    end
    return options
end

local function is_macos_sdk(sdk)
    return path.filename(sdk):find("MacOSX", 1, true) ~= nil
end

local function owner_of(api)
    return api:match("^[-+]%[([%w_]+) ") or api:match("^([^.]*)")
end

local function sum(counter)
    local total = 0
    for _, count in pairs(counter) do
        total = total + count
    end
    return total
end

local function bump(counter, key)
    counter[key] = (counter[key] or 0) + 1
end

local function past_up_to(version, up_to)
    if up_to == nil then
        return false
    end
    local head = {version[1], version[2]}
    local padded = {}
    for _, part in ipairs(up_to) do
        table.insert(padded, part)
    end
    while #padded < 2 do
        table.insert(padded, 0)
    end
    return sw.compare(head, padded) > 0 and sw.compare(version, up_to) > 0
end

local function surface_diff(options)
    local sdk = options.sdk or sw.newest_macos_sdk()
    local target = options.target or (is_macos_sdk(sdk) and "arm64-apple-ios26.0-macabi" or "arm64-apple-ios" .. sw.sdk_version(sdk))
    local registry_root = options.registry or path.join(workspace.root(), "packages", "a", "apple-backports", "registry")
    local above = sw.parse_version(options.above)
    local up_to = options["up-to"] and sw.parse_version(options["up-to"]) or nil
    print("SDK %s, target %s, API that arrived after iOS %s%s", path.filename(sdk), target, options.above,
          up_to and " up to " .. options["up-to"] or "")
    local inventory = options.release and sw.release(options.release) or nil
    local written = options.rows and io.open(options.rows, "w") or nil
    for _, framework in ipairs(options.frameworks) do
        local surface = sw.declared_surface(sdk, framework, target)
        local rows = surface.rows
        local apis = table.copy(surface.order)
        byteorder.sort(apis)
        if written then
            for _, api in ipairs(apis) do
                local version = rows[api].version
                local shown = (version and not sw.same(version, sw.unavailable_version())) and sw.show_version(version) or ""
                written:write(string.format("%s\t%s\t%s\t%s\n", framework, rows[api].kind, api, shown))
            end
        end
        local registry = sw.registry_names(registry_root, framework)
        local totals, gaps, carried = {}, {}, {}
        local listed, unversioned = {}, {}
        for _, api in ipairs(apis) do
            local kind, version = rows[api].kind, rows[api].version
            if version == nil then
                if inventory and (kind == "method" or kind == "property") and not sw.covered(api, kind, nil, registry)
                        and not inventory:knows_selector(api, kind) then
                    local owner = owner_of(api)
                    if inventory.classes[owner] == nil and not inventory:protocols()[owner] then
                        table.insert(unversioned, {api = api, kind = kind})
                    end
                end
            elseif not (sw.compare(version, above) <= 0 or sw.same(version, sw.unavailable_version()) or past_up_to(version, up_to)) then
                local release = tostring(version[1])
                bump(totals, release)
                local decided = sw.covered(api, kind, version, registry)
                if not decided and inventory and inventory:has(api, kind) then
                    bump(carried, release)
                elseif not decided then
                    bump(gaps, release)
                    table.insert(listed, {version = version, api = api, kind = kind})
                end
            end
        end
        print("\n%s: %d declared after iOS %s, %d not decided%s", framework, sum(totals), options.above, sum(gaps),
              inventory and string.format(", %d of the rest carried by iOS %s itself", sum(carried), options.release) or "")
        local releases = table.keys(totals)
        table.sort(releases, function (a, b) return tonumber(a) < tonumber(b) end)
        for _, release in ipairs(releases) do
            print("  iOS %-3s declared %5d   decided %5d%s   gap %5d", release, totals[release],
                  totals[release] - (gaps[release] or 0) - (carried[release] or 0),
                  inventory and string.format("   carried by the release %5d", carried[release] or 0) or "", gaps[release] or 0)
        end
        if inventory then
            print("  no recorded availability: %d members of a class or protocol iOS %s does not have, that no class of it answers and the registry does not decide",
                  #unversioned, options.release)
        end
        if options.list then
            table.sort(listed, function (a, b)
                local order = sw.compare(a.version, b.version)
                if order ~= 0 then
                    return order < 0
                end
                if a.api ~= b.api then
                    return byteorder.less(a.api, b.api)
                end
                return byteorder.less(a.kind, b.kind)
            end)
            for _, row in ipairs(listed) do
                print("    %-6s %-9s %s", sw.show_version(row.version), row.kind, row.api)
            end
            for _, row in ipairs(unversioned) do
                print("    %-6s %-9s %s", "?", row.kind, row.api)
            end
        end
    end
    if written then
        written:close()
    end
end

function main(...)
    local options = parse_options({...})
    local failure = nil
    try {
        function ()
            surface_diff(options)
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    sw.cleanup()
    if failure then
        io.stderr:write(failure .. "\n")
        os.exit(1)
    end
end
