import("fixtures")

local PROJECT = [[
add_rules("mode.release")
target("dep")
    set_kind("shared")
    add_files("dep.c")
target("own")
    set_kind("shared")
    add_files("own.c")
    add_deps("dep")
target("ownstatic")
    set_kind("static")
    add_files("static.c")
]]

local function xmake(folder, argv)
    os.vrunv(os.programfile(), argv, {curdir = folder})
end

local function listing(installdir)
    local listed = {}
    for _, file in ipairs(os.files(path.join(installdir, "lib", "*"))) do
        table.insert(listed, path.filename(file))
    end
    table.sort(listed)
    return table.concat(listed, " ")
end

function failures(opt)
    local wrapper = import("apple.wrapper", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local project = path.join(folder, "project")
    os.mkdir(project)
    io.writefile(path.join(project, "xmake.lua"), PROJECT)
    io.writefile(path.join(project, "dep.c"), "int dep(void) { return 1; }\n")
    io.writefile(path.join(project, "own.c"), "int dep(void);\nint own(void) { return dep(); }\n")
    io.writefile(path.join(project, "static.c"), "int ownstatic(void) { return 2; }\n")
    xmake(project, {"f", "-P", project, "-m", "release", "-y"})
    xmake(project, {"build", "-P", project, "-y"})

    local control = path.join(folder, "control")
    xmake(project, table.join({"install", "-P", project, "-y", "-o", control}, {"own", "ownstatic"}))
    if not listing(control):find("libdep.dylib", 1, true) then
        table.insert(found, "xmake install copies the dylibs its targets depend on: the control install must hold libdep.dylib, got " .. listing(control))
    end

    local native = path.join(folder, "native")
    xmake(project, table.join({"install", "-P", project, "-y", "--libraries=n", "-o", native}, {"own", "ownstatic"}))
    if listing(native) ~= "" then
        table.insert(found, "an install with --libraries=n copies no library, and the wrapper copies its own: got " .. listing(native))
    end

    wrapper.copy_own_libraries(project, path.join(native, "lib"), {"own", "ownstatic"})
    if listing(native) ~= "libown.dylib libownstatic.a" then
        table.insert(found, "a wrapper installs its own shared and static libraries and no dependency: got " .. listing(native))
    end

    local refused = fixtures.refusal(function ()
        wrapper.copy_own_libraries(project, path.join(folder, "absent"), {"absent"})
    end) or ""
    if not refused:find("absent", 1, true) then
        table.insert(found, "a target that builds no library must be refused, naming it: " .. refused)
    end

    local cache = os.getenv("REVENANT_CACHE")
    local ceiling = os.getenv("GIT_CEILING_DIRECTORIES") or ""
    if cache and not (":" .. ceiling .. ":"):find(":" .. cache .. ":", 1, true) then
        table.insert(found, "the wrapper must put its cache in GIT_CEILING_DIRECTORIES, so git apply inside the cache does not find the checkout: got " .. ceiling)
    end
    os.tryrm(folder)
    return found
end
