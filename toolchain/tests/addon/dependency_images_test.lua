import("fixtures")

local PROJECT = [[
set_project("dependency_images")
add_repositories("revenant %s")
add_addons("revenant", {sourcedir = "%s"})
set_config("apple_minimum", "6.0")
includes("@addon/revenant/apple-ios")
%s
]]

local KEYS = [[
import("core.project.config")
import("private.action.require.impl.package")

function main(output, wanted)
    config.load()
    local found = {}
    for _, name in ipairs(wanted:split(",")) do
        local requirement = "revenant@" .. name
        for _, instance in ipairs(package.load_packages({requirement}, {requires_extra = {[requirement] = {system = false}}})) do
            if instance:name() == name then
                found[name] = instance:buildhash()
            end
        end
    end
    io.save(output, found)
end
]]

local LINKED = {"boringssl", "swift-runtime", "webkit-engine", "tesseract", "zxing-cpp"}
local ARCHIVES = {"double-conversion", "fmt", "glog", "leptonica", "yoga"}

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local root = path.absolute(path.join(opt.modules, "..", ".."))
    local script = path.join(folder, "keys.lua")
    io.writefile(script, KEYS)

    local function keys(name, requireconfs)
        local project = path.join(folder, name)
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), string.format(PROJECT, opt.repository or root, path.join(root, "toolchain"), requireconfs))
        local output = path.join(project, "keys")
        os.vrunv(os.programfile(), {"f", "-y", "-c", "-p", "iphoneos", "-a", "armv7", "-P", project}, {curdir = project})
        os.vrunv(os.programfile(), {"l", "-P", project, script, output, table.concat(table.join(LINKED, ARCHIVES), ",")}, {curdir = project})
        return io.load(output)
    end

    local plain = keys("plain", "")
    local packaged = keys("packaged", "add_requireconfs(\"libcxx\", {configs = {packaged = true}})\nadd_requireconfs(\"**.libcxx\", {configs = {packaged = true}})")
    for _, name in ipairs(LINKED) do
        if not plain[name] or plain[name] == packaged[name] then
            table.insert(found, string.format("%s links the C++ runtime or writes where it is, and a packaged runtime does not move it: %s and %s", name, tostring(plain[name]), tostring(packaged[name])))
        end
    end
    for _, name in ipairs(ARCHIVES) do
        if not plain[name] or plain[name] ~= packaged[name] then
            table.insert(found, string.format("%s is static libraries which a packaged runtime does not change, and its key moves: %s and %s", name, tostring(plain[name]), tostring(packaged[name])))
        end
    end

    os.tryrm(folder)
    return found
end
