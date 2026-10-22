import("core.base.json")

local SDK_VERSION = "26.2"
local SDK_VARIABLE = "REVENANT_GEN_SDK"
local CORPUS_VARIABLE = "REVENANT_CORPUS_ROOT"
local TASK_VARIABLE = "REVENANT_TASK"
local HOME_VARIABLE = "REVENANT_HOME"

local resolved = {}

function root()
    return path.directory(path.directory(path.normalize(path.absolute(os.scriptdir()))))
end

function home()
    local named = os.getenv(HOME_VARIABLE)
    if named and named ~= "" then
        return named
    end
    local value = os.getenv("HOME")
    if not value or value == "" then
        raise("workspace: HOME is not set, so there is no $HOME/.revenant to keep revenant's data in")
    end
    return path.join(value, ".revenant")
end

function task()
    local named = os.getenv(TASK_VARIABLE)
    if named and named ~= "" then
        return named
    end
    local folder = root()
    while true do
        if os.exists(path.join(folder, ".git")) then
            return path.filename(folder)
        end
        local parent = path.directory(folder)
        if not parent or parent == folder then
            return path.filename(root())
        end
        folder = parent
    end
end

function cache()
    return path.join(home(), "cache")
end

local function ensure(folder)
    if os.isdir(folder) then
        return
    end
    ensure(path.directory(folder))
    try { function () os.mkdir(folder) end }
    if not os.isdir(folder) then
        raise("workspace: cannot create %s", folder)
    end
end

function run(...)
    local folder = path.join(cache(), task(), ...)
    ensure(folder)
    return folder
end

function fresh(name)
    local parent = run()
    for _ = 1, 100 do
        local folder = path.join(parent, string.format("%s.%06x", name, math.random(0, 0xffffff)))
        if not os.exists(folder) then
            os.mkdir(folder)
            return folder
        end
    end
    raise("workspace: no free folder %s.* under %s after 100 tries", name, parent)
end

function corpus(...)
    local folder = os.getenv(CORPUS_VARIABLE) or path.join(home(), "corpus")
    if not os.isdir(folder) then
        raise("workspace: no corpus at %s; set %s to it", folder, CORPUS_VARIABLE)
    end
    local parts = {...}
    local wanted = path.join(folder, table.unpack(parts))
    if #parts > 0 and not os.exists(wanted) then
        raise("workspace: the corpus at %s has no %s", folder, path.relative(wanted, folder))
    end
    return wanted
end

local function sdk_in(installdir, version)
    return import("apple.sdk", {rootdir = os.scriptdir()}).folder(installdir, version)
end

function package_of(requirement, install)
    local scratch = fresh("package-resolve")
    local lines = {string.format("add_repositories(%q)", "revenant " .. root()), string.format("add_requires(%q)", requirement)}
    if install then
        table.insert(lines, string.format("add_addons(%q, {sourcedir = %q})", "revenant", path.join(root(), "toolchain")))
    end
    io.writefile(path.join(scratch, "xmake.lua"), table.concat(lines, "\n") .. "\n")
    local failure
    local result = try {
        function ()
            if install then
                os.execv(os.programfile(), {"require", "-y"}, {curdir = scratch})
            end
            local output = os.iorunv(os.programfile(), {"require", "--info", "--format=json"}, {curdir = scratch})
            local start = output:sub(1, 2) == "[\n" and 1 or output:find("\n[\n", 1, true)
            local entries = start and json.decode(output:sub(start)) or {}
            for _, entry in ipairs(entries) do
                if entry.require == requirement and entry.installdir then
                    return entry.installdir
                end
            end
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    os.tryrm(scratch)
    if failure then
        raise("workspace: xmake could not resolve revenant's %s package: %s", requirement, failure)
    end
    if not result then
        raise("workspace: xmake named no install folder for revenant's %s package", requirement)
    end
    return result
end

function sdk_package(version)
    local key = "package " .. version
    if resolved[key] then
        return resolved[key]
    end
    local installdir = package_of("iphoneos-sdk " .. version, true)
    local folder = sdk_in(installdir, version)
    if not os.isfile(path.join(folder, "SDKSettings.json")) then
        raise("workspace: the iphoneos-sdk install is incomplete even after xmake installed it: %s has no SDKSettings.json", folder)
    end
    resolved[key] = folder
    return folder
end

function sdk()
    local named = os.getenv(SDK_VARIABLE)
    if named and named ~= "" then
        if not os.isfile(path.join(named, "SDKSettings.json")) then
            raise("workspace: %s is %s, which holds no SDKSettings.json, so it is not an iPhoneOS SDK", SDK_VARIABLE, named)
        end
        return path.absolute(named)
    end
    return sdk_package(SDK_VERSION)
end

function main(command, ...)
    local arguments = {...}
    if command == "sdk" then
        print(sdk())
    elseif command == "sdk-package" and arguments[1] then
        print(sdk_package(arguments[1]))
    elseif command == "corpus" then
        print(corpus(table.unpack(arguments)))
    elseif command == "task" then
        print(task())
    elseif command == "run" then
        print(run(table.unpack(arguments)))
    elseif command == "fresh" and arguments[1] then
        print(fresh(arguments[1]))
    else
        raise("usage: ./xmakew l toolchain/modules/workspace.lua sdk | sdk-package <version> | corpus [path ...] | task | run [path ...] | fresh <name>")
    end
end
