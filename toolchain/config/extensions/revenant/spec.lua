local MANIFEST = "charon.toml"
local PATHS = {
    sources = ".", engine = "", build = "build", tasks = "tasks", package = "packaging", profiles = "",
    recipe = "", tests = "tests",
}
local PLATFORM_SAYS = {"os", "os-version", "arch", "sdk", "include-profiles", "system-name"}
local TARGET_KINDS = {"static-library", "device-library", "executable", "application"}
local BUILDING_VARIANT = "for-variant"
local GRAPH_PREFIXES = {pkg = true, include = true, lib = true, libdirs = true, bin = true}

local DIR = nil
local TOML = nil

function spec_bind(folder)
    DIR = folder
    TOML = nil
end

local function toml()
    if TOML == nil then
        assert(DIR ~= nil, "spec_bind(folder) names the folder holding toml.lua before a manifest is read")
        TOML = import("toml", {rootdir = DIR, anonymous = true})
    end
    return TOML
end

function spec_toml()
    return toml()
end

local function platforms_folder()
    return path.join(DIR, "platforms")
end

local function truthy(value)
    if value == nil or value == false or value == "" or value == 0 then
        return false
    end
    if type(value) == "table" then
        for _ in pairs(value) do
            return true
        end
        return false
    end
    return true
end

local function release(text)
    local parts = {}
    for part in tostring(text):gmatch("[^%.]+") do
        table.insert(parts, tonumber(part))
    end
    return parts
end

local function release_before(a, b)
    local left, right = release(a), release(b)
    for index = 1, math.max(#left, #right) do
        local x, y = left[index] or 0, right[index] or 0
        if x ~= y then
            return x < y
        end
    end
    return false
end

local function sorted_names(map)
    local names = {}
    for key in pairs(map or {}) do
        table.insert(names, tostring(key))
    end
    table.sort(names)
    return names
end

local function joined(names, fallback)
    if #names == 0 then
        return fallback
    end
    return table.concat(names, ", ")
end

local function manifest_of(root)
    return path.join(root, MANIFEST)
end

function spec_placeholders(text)
    local found = {}
    for index = 1, #text do
        local name = spec_match_at(text, index)
        if name then
            table.insert(found, name)
        end
    end
    return found
end

function spec_match_at(text, index)
    if text:sub(index, index) ~= "{" then
        return nil
    end
    local at = index + 1
    if not text:sub(at, at):match("^[a-z]$") then
        return nil
    end
    at = at + 1
    while text:sub(at, at):match("^[a-z0-9_%.%-]$") do
        at = at + 1
    end
    if text:sub(at, at) == ":" then
        at = at + 1
        while not text:sub(at, at):match("^[{}]$") and at <= #text do
            at = at + 1
        end
    end
    if text:sub(at, at) ~= "}" then
        return nil
    end
    return text:sub(index + 1, at - 1)
end

local function is_graph_name(name)
    return GRAPH_PREFIXES[name:match("^([^:]*)")] ~= nil
end

function spec_substitute(text, known, keep_graph_names)
    if keep_graph_names == nil then
        keep_graph_names = true
    end
    local out = {}
    local index = 1
    while index <= #text do
        local name = spec_match_at(text, index)
        if name == nil then
            table.insert(out, text:sub(index, index))
            index = index + 1
        else
            local whole = "{" .. name .. "}"
            if known[name] ~= nil then
                table.insert(out, tostring(known[name]))
            elseif keep_graph_names and is_graph_name(name) then
                table.insert(out, whole)
            else
                raise("{%s} in '%s' resolves to nothing; every name must have a value", name, text)
            end
            index = index + #whole
        end
    end
    return table.concat(out)
end

function spec_with_implicit_variants(content)
    local pipelines = content.pipeline
    if content.variants == nil and toml().is_table(pipelines) and truthy(pipelines) then
        local variants = {}
        local names = toml().keys(pipelines)
        for _, name in ipairs(names) do
            variants[name] = {}
        end
        return toml().merge(content, {variants = toml().map_from(names, variants)})
    end
    return content
end

local function declaration(root, content, platforms)
    return {root = root, content = content, platforms = platforms}
end

function spec_load(root)
    local file = manifest_of(root)
    if not os.isfile(file) then
        return nil
    end
    local text = io.readfile(file)
    local content = nil
    try { function ()
        content = toml().parse(text, file)
    end, catch { function (broken)
        raise("%s is not readable: %s", file, tostring(broken))
    end } }
    return declaration(root, spec_with_implicit_variants(content), platforms_folder())
end

function decl_section(declared, name, default)
    local value = declared.content[name]
    if value ~= nil then
        return value
    end
    if default == nil then
        return {}
    end
    return default
end

function decl_get(declared, section, key, default)
    local value = decl_section(declared, section)[key]
    if value == nil then
        return default
    end
    return value
end

function decl_require(declared, section, key)
    local value = decl_get(declared, section, key)
    if value == nil or value == "" then
        raise("%s declares no %s.%s", manifest_of(declared.root), section, key)
    end
    return value
end

function decl_path(declared, name)
    if PATHS[name] == nil then
        raise("%s is not a path Charon knows; known: %s", name, joined(sorted_names(PATHS), ""))
    end
    local declaredPath = decl_get(declared, "paths", name, PATHS[name])
    if not truthy(declaredPath) then
        return nil
    end
    return path.join(declared.root, declaredPath)
end

function decl_using(declared, name)
    local declaredPath = decl_get(declared, "use", name, "")
    if not truthy(declaredPath) then
        return nil
    end
    return path.join(declared.root, declaredPath)
end

function decl_variants(declared)
    return decl_section(declared, "variants")
end

function decl_variant(declared, name)
    local variants = decl_variants(declared)
    if variants[name] == nil then
        raise("%s declares no variant %s (%s)", manifest_of(declared.root), name,
              joined(sorted_names(variants), "none declared"))
    end
    return variants[name]
end

local function is_named(entry, name)
    return entry.name == name
end

function decl_for_variant(declared, name)
    local variant = decl_variant(declared, name)
    local content = toml().copy(declared.content)
    if truthy(variant.target) then
        content.target = toml().merge(content.target or {}, variant.target)
    end
    if truthy(variant.platform) then
        content.platform = toml().merge(content.platform or {}, variant.platform)
    end
    if truthy(variant.conf) then
        content.conf = toml().merge(content.conf or {}, variant.conf)
    end
    if truthy(variant.package) then
        content.package = toml().copy(variant.package)
    end
    local overrides = variant.targets or {}
    for _, target_name in ipairs(toml().keys(overrides)) do
        local matched = false
        for _, kind in ipairs(TARGET_KINDS) do
            local listed = content[kind]
            local entries = listed or {}
            if toml().is_table(listed) and truthy(listed) then
                entries = {listed}
            end
            for _, entry in ipairs(entries) do
                if is_named(entry, target_name) then
                    for _, key in ipairs(toml().keys(overrides[target_name])) do
                        entry[key] = toml().copy(overrides[target_name][key])
                    end
                    matched = true
                end
            end
        end
        if not matched then
            raise("%s variant %s overrides a target %s that nothing declares", manifest_of(declared.root), name,
                  target_name)
        end
    end
    content[BUILDING_VARIANT] = name
    return declaration(declared.root, content, declared.platforms)
end

local function list_of(value)
    if value == nil then
        return {}
    end
    return toml().copy(value)
end

local function concat_lists(first, second)
    local out = list_of(first)
    for _, item in ipairs(list_of(second)) do
        table.insert(out, item)
    end
    return out
end

local function platform_file(declared, name)
    local candidates = {path.join(declared.root, "platforms", name .. ".toml"),
                        path.join(declared.platforms, name .. ".toml")}
    for _, candidate in ipairs(candidates) do
        if os.isfile(candidate) then
            return candidate
        end
    end
    local known = {}
    for _, folder in ipairs({path.join(declared.root, "platforms"), declared.platforms}) do
        if os.isdir(folder) then
            for _, file in ipairs(os.files(path.join(folder, "*.toml"))) do
                known[path.basename(file):gsub("%.toml$", "")] = true
            end
        end
    end
    raise("%s uses the platform %s, which neither the port nor Charon defines (%s)", manifest_of(declared.root),
          name, joined(sorted_names(known), "none"))
end

function decl_platform(declared)
    local chosen = decl_section(declared, "platform")
    if not truthy(chosen) then
        return nil
    end
    local name = chosen.use
    if not truthy(name) then
        raise("%s has a [platform] that names none with use", manifest_of(declared.root))
    end
    local found = platform_file(declared, name)
    local facts = toml().parse(io.readfile(found), found)

    local repeated = {}
    for _, key in ipairs(PLATFORM_SAYS) do
        if decl_section(declared, "target")[key] ~= nil then
            table.insert(repeated, key)
        end
    end
    if #repeated > 0 then
        raise("%s names %s under [target] and uses the %s platform, which says it; [platform] is the one place for "
              .. "what the port builds for", manifest_of(declared.root), table.concat(repeated, ", "), name)
    end

    local architectures = facts.architectures or {}
    local arch = chosen.arch
    if arch == nil or architectures[arch] == nil then
        raise("%s builds for %s on %s, which builds for %s", manifest_of(declared.root), tostring(arch), name,
              joined(sorted_names(architectures), "nothing"))
    end
    local version = chosen["os-version"]
    if not truthy(version) then
        raise("%s names no os-version under [platform]; it is the oldest release the port runs on",
              manifest_of(declared.root))
    end

    local bounds = toml().merge(facts["os-version"] or {}, architectures[arch]["os-version"] or {})
    if bounds.min ~= nil and release_before(version, bounds.min) then
        raise("%s targets %s %s on %s, and %s starts at %s", manifest_of(declared.root), facts.os, version, arch,
              name, bounds.min)
    end
    if bounds.max ~= nil and release_before(bounds.max, version) then
        raise("%s targets %s %s on %s, and %s ends at %s", manifest_of(declared.root), facts.os, version, arch,
              name, bounds.max)
    end

    local distribution = chosen.distribution
    local distributions = facts.distributions or {}
    if distribution ~= nil and distributions[distribution] == nil then
        raise("%s distributes as %s, which %s does not know (%s)", manifest_of(declared.root), distribution, name,
              joined(sorted_names(distributions), "none"))
    end
    local unknown = {}
    for key in pairs(chosen) do
        if key ~= "use" and key ~= "arch" and key ~= "os-version" and key ~= "distribution" then
            table.insert(unknown, tostring(key))
        end
    end
    if #unknown > 0 then
        table.sort(unknown)
        raise("%s says %s under [platform], which Charon does not read", manifest_of(declared.root),
              table.concat(unknown, ", "))
    end

    local template = facts["cross-toolchain"]
    local arch_facts = architectures[arch]
    return {
        name = name,
        ["python-requires"] = list_of(facts["python-requires"]),
        requires = list_of(facts.requires),
        extends = list_of(facts.extends),
        ["cross-toolchain"] = template and path.join(path.directory(found), template) or nil,
        ["build-only"] = list_of(facts["build-only"]),
        frameworks = toml().copy(facts.frameworks or {}),
        os = facts.os,
        sdk = facts.sdk,
        arch = arch,
        ["os-version"] = tostring(version),
        distribution = distribution,
        distributed = toml().copy(distributions[distribution] or {}),
        ["deployment-environment"] = facts["deployment-environment"],
        compiler = toml().copy(facts.compiler or {}),
        conf = toml().copy(facts.conf or {}),
        ["port-tool-requires"] = list_of(facts["port-tool-requires"]),
        ["tool-requires"] = concat_lists(facts["tool-requires"], arch_facts["tool-requires"]),
    }
end

function decl_targets(declared, kind)
    local listed = declared.content[kind]
    if not truthy(listed) then
        listed = {}
    elseif toml().is_table(listed) then
        listed = {listed}
    end
    for _, target in ipairs(listed) do
        if target.name == nil then
            raise("a %s in %s has no name", kind, manifest_of(declared.root))
        end
    end
    return listed
end

function decl_target(declared, kind, name)
    for _, target in ipairs(decl_targets(declared, kind)) do
        if target.name == name then
            return target
        end
    end
    raise("%s declares no %s called %s", manifest_of(declared.root), kind, name)
end

function decl_generates(target)
    return not truthy(target.cmake)
end

function decl_conf_required(declared)
    return decl_section(declared, "conf")
end

function decl_tiers(declared)
    local tests = decl_section(declared, "tests")
    local chosen = {}
    for _, key in ipairs(toml().keys(tests)) do
        if toml().is_table(tests[key]) then
            table.insert(chosen, key)
        end
    end
    return toml().map_from(chosen, tests)
end

function decl_tier(declared, name)
    local tiers = decl_tiers(declared)
    if tiers[name] == nil then
        raise("%s declares no test tier %s (%s)", manifest_of(declared.root), name,
              joined(toml().keys(tiers), "none declared"))
    end
    return tiers[name]
end

function decl_transport_binder(declared)
    return decl_get(declared, "tests", "transport")
end

function decl_tasks(declared)
    return decl_section(declared, "tasks")
end

function decl_task(declared, name)
    local tasks = decl_tasks(declared)
    if tasks[name] == nil then
        raise("%s declares no task %s (%s)", manifest_of(declared.root), name,
              joined(toml().keys(tasks), "none declared"))
    end
    return tasks[name]
end

function decl_pipeline(declared, variant)
    local steps = decl_get(declared, "pipeline", variant)
    if not truthy(steps) then
        raise("%s declares no pipeline for the %s variant", manifest_of(declared.root), variant)
    end
    return steps
end
