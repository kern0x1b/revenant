import("core.base.json")

local SDK_VERSION = "26.2"
local SDK_VARIABLE = "CHARON_GEN_SDK"
local CORPUS_VARIABLE = "CHARON_CORPUS_ROOT"
local TASK_VARIABLE = "HADES_TASK"

local resolved = {}

function root()
    return path.directory(path.absolute(os.scriptdir()))
end

local function home()
    local value = os.getenv("HOME")
    if not value or value == "" then
        raise("workspace: HOME is not set, so there is no $HOME/.cache/hades to put run output in")
    end
    return value
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
            return path.filename(path.directory(root()))
        end
        folder = parent
    end
end

function cache()
    return path.join(home(), ".cache", "hades")
end

function run(...)
    local folder = path.join(cache(), task(), ...)
    os.mkdir(folder)
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

function coordination()
    local named = os.getenv(CORPUS_VARIABLE)
    if named and named ~= "" then
        return path.absolute(named)
    end
    return path.join(home(), "Git", "projects", "ios", "coordination")
end

function corpus(...)
    local folder = path.join(coordination(), "corpus")
    if not os.isdir(folder) then
        raise("workspace: no corpus at %s; set %s to the folder that holds corpus/", folder, CORPUS_VARIABLE)
    end
    local parts = {...}
    local wanted = path.join(folder, table.unpack(parts))
    if #parts > 0 and not os.exists(wanted) then
        raise("workspace: the corpus at %s has no %s", folder, path.relative(wanted, folder))
    end
    return wanted
end

function heavy()
    local script = path.join(coordination(), "heavy.sh")
    if not os.isfile(script) then
        raise("workspace: no heavy.sh at %s; set %s to the folder that holds it", script, CORPUS_VARIABLE)
    end
    return script
end

local function sdk_in(installdir)
    return path.join(installdir, "Developer.app", "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs",
                     "iPhoneOS" .. SDK_VERSION .. ".sdk")
end

local function package_sdk(install)
    local scratch = fresh("sdk-resolve")
    io.writefile(path.join(scratch, "xmake.lua"), string.format("add_repositories(%q)\nadd_requires(%q)\n",
                                                                 "charon " .. root(), "iphoneos-sdk " .. SDK_VERSION))
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
                if entry.require == "iphoneos-sdk " .. SDK_VERSION and entry.installdir then
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
        raise("workspace: xmake could not resolve charon's iphoneos-sdk %s package: %s", SDK_VERSION, failure)
    end
    if not result then
        raise("workspace: xmake named no install folder for charon's iphoneos-sdk %s package", SDK_VERSION)
    end
    return sdk_in(result), result
end

function sdk(opt)
    opt = opt or {}
    local named = os.getenv(SDK_VARIABLE)
    if named and named ~= "" then
        if not os.isfile(path.join(named, "SDKSettings.json")) then
            raise("workspace: %s is %s, which holds no SDKSettings.json, so it is not an iPhoneOS SDK", SDK_VARIABLE, named)
        end
        return path.absolute(named)
    end
    if resolved.sdk and not opt.install then
        return resolved.sdk
    end
    local folder, installdir = package_sdk(opt.install)
    if not os.isfile(path.join(folder, "SDKSettings.json")) then
        raise("workspace: the iPhoneOS %s SDK is not there: charon's iphoneos-sdk %s package is not installed at %s. "
              .. "Install it with `xmake l %s sdk --install`, or set %s to an iPhoneOS%s.sdk folder",
              SDK_VERSION, SDK_VERSION, installdir, path.join(root(), "modules", "workspace.lua"), SDK_VARIABLE, SDK_VERSION)
    end
    resolved.sdk = folder
    return folder
end

function main(command, ...)
    local arguments = {...}
    if command == "sdk" then
        print(sdk({install = arguments[1] == "--install"}))
    elseif command == "corpus" then
        print(corpus(table.unpack(arguments)))
    elseif command == "coordination" then
        print(coordination())
    elseif command == "heavy" then
        print(heavy())
    elseif command == "task" then
        print(task())
    elseif command == "run" then
        print(run(table.unpack(arguments)))
    elseif command == "fresh" and arguments[1] then
        print(fresh(arguments[1]))
    else
        raise("usage: xmake l modules/workspace.lua sdk [--install] | corpus [path ...] | coordination | heavy | task | run [path ...] | fresh <name>")
    end
end
