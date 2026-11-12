import("core.package.addon")

local function built_library(project, name)
    local found = {}
    for _, extension in ipairs({"dylib", "a"}) do
        table.join2(found, os.files(path.join(project, "build", "**", "lib" .. name .. "." .. extension)))
    end
    if #found ~= 1 then
        raise("target(%s) builds %d library files named lib%s, and the wrapper installs exactly one", name, #found, name)
    end
    return found[1]
end

function copy_own_libraries(project, libdir, targets)
    for _, name in ipairs(targets) do
        os.mkdir(libdir)
        os.vcp(built_library(project, name), libdir)
    end
end

function install(package, opt)
    local toolchain = assert(package:toolchains(), package:name() .. " is built with the apple-ios toolchain")[1]
    toolchain:load()
    local revenant = addon.addons()[addon.dirname("revenant")] or raise("%s is built with the revenant addon's rules, and no revenant addon is installed", package:name())
    local project = path.absolute(package:name())
    os.mkdir(project)
    local sdk = package:config("apple_sdk") or raise("%s names no iPhoneOS SDK: the apple-ios include gives every wrapper its SDK through add_requireconfs", package:name())
    local lines = {
        "add_repositories(\"revenant " .. opt.root .. "\")",
        "add_addons(\"revenant\", {sourcedir = \"" .. path.join(opt.root, "toolchain") .. "\"})",
        "set_config(\"apple_minimum\", \"" .. toolchain:config("deployment") .. "\")",
        "set_config(\"apple_sdk\", \"" .. sdk .. "\")",
        "includes(\"@addon/revenant/apple-ios\")",
    }
    for _, folder in ipairs(opt.includes) do
        table.insert(lines, "includes(\"" .. folder .. "\")")
    end
    table.join2(lines, opt.lines or {})
    table.join2(lines, {"set_defaultplat(\"iphoneos\")", "set_defaultarchs(\"iphoneos|" .. package:arch() .. "\")", ""})
    io.writefile(path.join(project, "xmake.lua"), table.concat(lines, "\n"))
    io.save(path.join(project, "xmake-addons.lock"), {__meta__ = {version = "1.0"}, revenant = {version = revenant.version}})
    os.vrunv(os.programfile(), {"f", "-P", project, "-p", "iphoneos", "-a", package:arch(), "-m", "release", "-y"}, {curdir = project})
    os.vrunv(os.programfile(), table.join({"build", "-P", project, "-y"}, opt.targets), {curdir = project, envs = {REVENANT_RELEASE = "1"}})
    os.vrunv(os.programfile(), table.join({"install", "-P", project, "-y", "--libraries=n", "-o", package:installdir()}, opt.targets), {curdir = project})
    copy_own_libraries(project, package:installdir("lib"), opt.targets)
    if opt.modules then
        package:setenv("REVENANT_SWIFT_MODULES", path.join(package:installdir("lib"), "swift", "iphoneos"))
    end
    os.vcp(import("@addon.revenant.data", {anonymous = true}).licence(), package:installdir("licenses"))
end
