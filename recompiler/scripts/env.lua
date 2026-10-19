import("core.project.config")
import("core.project.project")

local function installdir(name)
    local instance = project.required_package(name)
    local dir = instance and instance:installdir()
    if not dir or not os.isdir(dir) then
        raise("the package %s is not installed for this configuration: configure the host first (./xmakew f -y)", name)
    end
    return dir, instance
end

local function targetfile(name)
    local target = project.target(name)
    if not target then
        raise("no target %s: configure revenant for the host (./xmakew f -y), not for iphoneos", name)
    end
    local file = path.absolute(target:targetfile(), os.projectdir())
    if not os.isfile(file) then
        raise("%s is not built: ./xmakew build xlate xlgen", file)
    end
    return file
end

function sorted(list)
    import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "toolchain", "modules"), anonymous = true}).sort(list)
    return list
end

function main()
    if _g.env then
        return _g.env
    end
    if not config.get("plat") then
        config.load()
    end
    local root = os.projectdir()
    local llvm = config.get("recompiler_llvm")
    local sdks = os.dirs(path.join(installdir("iphoneos-sdk"), "Developer.app", "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))
    if #sdks ~= 1 then
        raise("the iphoneos-sdk package holds %d SDKs, not one", #sdks)
    end
    local env = {
        root = root,
        recompiler = path.join(root, "recompiler"),
        modules = path.join(root, "toolchain", "modules"),
        builddir = path.absolute(config.builddir(), root),
        xlate = targetfile("xlate"),
        xlgen = targetfile("xlgen"),
        llvm = llvm,
        llvmbin = path.join(llvm, "bin"),
        resourcedir = path.join(llvm, "lib", "clang", "23"),
        sdk = sdks[1],
        ld = path.join(installdir("ld64"), "bin", "ld"),
        ldid = path.join(installdir("ldid"), "bin", "ldid"),
        blocks = path.join(installdir("blocksruntime"), "src"),
        dyld = path.join(os.getenv("HOME"), ".revenant", "dyld", "6.0")
    }
    _g.env = env
    return env
end
