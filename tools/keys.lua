import("core.project.config")
import("private.action.require.impl.package")

local prebuilt = import("@addon.revenant.prebuilt", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local HOST = {"llvm", "swift", "swift-bootstrap", "apple-compat", "iphoneos-sdk", "ld64"}
local GUEST_NAMES = {"libcxx", "swift-runtime"}
local GUEST = {libcxx = true, ["swift-runtime"] = true}
local GUEST_CONFIGS = {["swift-runtime"] = {library_evolution = true}}
local GUEST_LABEL = "iphoneos-arm64"

local function guest_text(root)
    return table.concat({
        'set_project("guest")',
        string.format('add_repositories("revenant %s")', root),
        string.format('add_addons("revenant", {sourcedir = "%s"})', path.join(root, "toolchain")),
        'set_config("apple_minimum", "7.0")',
        'set_config("apple_compat_only", true)',
        'includes("@addon/revenant/apple-ios")',
        ""}, "\n")
end

local function print_keys(names, guest)
    local requires, extra = {}, {}
    for _, name in ipairs(names) do
        requires[#requires + 1] = "revenant@" .. name
        local setting = {system = false}
        if guest and GUEST_CONFIGS[name] then
            setting.configs = GUEST_CONFIGS[name]
        end
        extra["revenant@" .. name] = setting
    end
    local instances = package.load_packages(requires, {requires_extra = extra})
    for _, name in ipairs(names) do
        local found = false
        for _, instance in ipairs(instances) do
            if instance:name() == name and instance:is_toplevel() then
                print("%s %s %s%s", name, instance:version_str() or "latest", prebuilt.key(instance), guest and " " .. GUEST_LABEL or "")
                found = true
                break
            end
        end
        if not found then
            raise("keys: the project requires no package %s", name)
        end
    end
end

local function print_guest_keys(names)
    local root = os.projectdir()
    local project = workspace.run("keys-guest")
    io.writefile(path.join(project, "xmake.lua"), guest_text(root))
    local envs = {REVENANT_PREBUILT = os.getenv("REVENANT_PREBUILT") or "kern0x1b/revenant", REVENANT_PREBUILT_ONLY = "llvm,swift,ld64"}
    os.vrunv(os.programfile(), {"f", "-P", project, "-p", "iphoneos", "-a", "arm64", "-y", "-c"}, {curdir = project, envs = envs})
    local output = os.iorunv(os.programfile(), table.join({"l", "-P", project, path.absolute(path.join(os.scriptdir(), "keys.lua")), "--in-guest"}, names), {curdir = project, envs = envs})
    io.write(output)
end

function main(...)
    local arguments = {...}
    config.load()
    if arguments[1] == "--in-guest" then
        print_keys(table.slice(arguments, 2), true)
        return
    end
    local forced = arguments[1] == "guest"
    if forced then
        table.remove(arguments, 1)
    end
    local names = #arguments > 0 and arguments or (forced and GUEST_NAMES or table.join(HOST, GUEST_NAMES))
    local here, away = {}, {}
    for _, name in ipairs(names) do
        if GUEST[name] and (forced or config.get("plat") ~= "iphoneos") then
            away[#away + 1] = name
        else
            here[#here + 1] = name
        end
    end
    if #here > 0 then
        print_keys(here, false)
    end
    if #away > 0 then
        print_guest_keys(away)
    end
end
