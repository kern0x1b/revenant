import("fixtures")

function failures(opt)
    local source = import("emulator_source", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local root = fixtures.scratch()
    os.mkdir(path.join(root, "emulator", "src"))
    io.writefile(path.join(root, "emulator", "src", "a.cpp"), "one\n")
    io.writefile(path.join(root, "emulator", "b.h"), "two\n")
    local first = source.requirement_configs(root).sources
    if first == nil then
        table.insert(found, "the sources of an emulator folder must give the emulator package a sources config")
    end
    io.writefile(path.join(root, "emulator", "src", "a.cpp"), "three\n")
    if source.requirement_configs(root).sources == first then
        table.insert(found, "a changed emulator source must change the emulator package's sources config, or xmake reuses the old emulator")
    end
    io.writefile(path.join(root, "emulator", "src", "a.cpp"), "one\n")
    if source.requirement_configs(root).sources ~= first then
        table.insert(found, "restoring an emulator source must restore the sources config")
    end
    local empty = fixtures.scratch()
    if source.requirement_configs(empty).sources ~= nil then
        table.insert(found, "a checkout without emulator sources must pass no sources config")
    end
    local addon = io.readfile(path.join(os.scriptdir(), "../../includes/emulate/xmake.lua"))
    if not addon:find("requirement_configs", 1, true) then
        table.insert(found, "the emulate addon must give the emulator package its sources config from the checkout, so a changed source is a new package")
    end
    os.tryrm(root)
    os.tryrm(empty)
    return found
end
