import("fixtures")

local NAME = "org.revenant.backports"
local FOLDER = "/usr/lib/revenant/" .. NAME
local BASE = "org.example.base-11111111"

local function members(deb)
    local content = io.readfile(deb, {encoding = "binary"})
    assert(content:startswith("!<arch>\n"), deb .. " is not an ar archive")
    local found, order, offset = {}, {}, 8
    while offset < #content do
        local header = content:sub(offset + 1, offset + 60)
        local name = header:sub(1, 16):trim():gsub("/$", "")
        local size = tonumber(header:sub(49, 58):trim())
        found[name] = content:sub(offset + 61, offset + 60 + size)
        table.insert(order, name)
        offset = offset + 60 + size + size % 2
    end
    return found, order
end

local function target(name, file)
    return {name = function () return name end, targetfile = function () return file end}
end

local function unpack(deb, folder)
    local parts = members(deb)
    os.mkdir(folder)
    io.writefile(path.join(folder, "control.tar.gz"), parts["control.tar.gz"], {encoding = "binary"})
    io.writefile(path.join(folder, "data.tar.gz"), parts["data.tar.gz"], {encoding = "binary"})
    os.runv("tar", {"-xzf", path.join(folder, "control.tar.gz"), "-C", folder})
    os.runv("tar", {"-xzf", path.join(folder, "data.tar.gz"), "-C", folder})
end

function failures(opt)
    local backports = import("apple.backports_package", {rootdir = opt.modules, anonymous = true})
    local shared = import("apple.shared_runtime", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    io.writefile(path.join(folder, "base.c"), "int base(void) { return 1; }\n")
    io.writefile(path.join(folder, "foo.c"), "extern int base(void);\nint foo(void) { return base() + 1; }\n")
    io.writefile(path.join(folder, "bar.c"), "int bar(void) { return 3; }\n")
    fixtures.link(folder, opt.ld64, "libbase.1.dylib", "armv7-apple-ios6.0", "base.c",
                  {"-dynamiclib", "-install_name", "@rpath/libbase.1.dylib"})
    shared.stage({packages = {{name = BASE, version = "1.0+11111111", title = "Base", description = "The base library",
                               libraries = {path.join(folder, "libbase.1.dylib")}}},
                  root = path.join(folder, "shared-root"), metadata = path.join(folder, "shared-packages"), strip = {"-x"}})
    local base = path.join(folder, "shared-root", "usr", "lib", "revenant", BASE, "libbase.1.dylib")
    fixtures.link(folder, opt.ld64, "libFooBackports.dylib", "armv7-apple-ios6.0", "foo.c",
                  {"-dynamiclib", "-install_name", "@rpath/libFooBackports.dylib", "-L.", "-lbase.1"})
    fixtures.link(folder, opt.ld64, "libBarBackports.dylib", "armv7-apple-ios6.0", "bar.c",
                  {"-dynamiclib", "-install_name", "@rpath/libBarBackports.dylib"})

    local held = "/usr/lib/revenant/" .. BASE .. "/libbase.1.dylib"
    local packages = {{name = BASE, version = "1.0+11111111", held = {[held] = true}}}
    local provided = {["libbase.1.dylib"] = held}
    local targets = {target("FooBackports", path.join(folder, "libFooBackports.dylib")),
                     target("BarBackports", path.join(folder, "libBarBackports.dylib"))}
    local outputs = path.join(folder, "debs")
    local written = backports.write({targets = targets, ldid = opt.ldid, packages = packages, provided = provided,
                                     workdir = path.join(folder, "work"), outputdir = outputs})

    if written.name ~= NAME or written.relation ~= "=" or not written.version:find("^%d[%d%.]*%+%x%x%x%x%x%x%x%x$") then
        table.insert(found, "the package is named " .. NAME .. " and pinned by an exact version with the build's hash, got " ..
                     tostring(written.name) .. " " .. tostring(written.relation) .. " " .. tostring(written.version))
    end
    if table.concat(written.depends, ", ") ~= BASE .. " (= 1.0+11111111)" then
        table.insert(found, "the package needs the shared package whose library it names, and no other: " .. table.concat(written.depends, ", "))
    end
    if path.filename(written.deb) ~= NAME .. "_" .. written.version .. "_iphoneos-arm.deb" or not os.isfile(written.deb) then
        table.insert(found, "the package is written as Package_Version_Architecture.deb: " .. written.deb)
    end
    if os.isdir(path.join(folder, "work")) then
        table.insert(found, "the staging folder is removed once the package is written")
    end

    local parts, order = members(written.deb)
    if table.concat(order, ",") ~= "debian-binary,control.tar.gz,data.tar.gz" then
        table.insert(found, "dpkg reads debian-binary, control and data in that order, got " .. table.concat(order, ","))
    end
    local extracted = path.join(folder, "extracted")
    os.mkdir(extracted)
    io.writefile(path.join(extracted, "control.tar.gz"), parts["control.tar.gz"], {encoding = "binary"})
    io.writefile(path.join(extracted, "data.tar.gz"), parts["data.tar.gz"], {encoding = "binary"})
    os.runv("tar", {"-xzf", path.join(extracted, "control.tar.gz"), "-C", extracted})
    os.runv("tar", {"-xzf", path.join(extracted, "data.tar.gz"), "-C", extracted})
    local control = io.readfile(path.join(extracted, "control"))
    for _, expected in ipairs({"Package: " .. NAME, "Architecture: iphoneos-arm", "\nVersion: " .. written.version .. "\n",
                               "\nDepends: " .. BASE .. " (= 1.0+11111111)\n", "\nInstalled-Size: "}) do
        if not control:find(expected, 1, true) then
            table.insert(found, "the control file carries " .. expected:gsub("\n", "") .. ": " .. control)
        end
    end

    local files = {}
    for _, file in ipairs(os.files(path.join(extracted, "usr", "**"))) do
        table.insert(files, path.relative(file, extracted))
    end
    table.sort(files)
    local expected = {"usr/lib/revenant/" .. NAME .. "/libBarBackports.dylib", "usr/lib/revenant/" .. NAME .. "/libFooBackports.dylib"}
    if table.concat(files, ",") ~= table.concat(expected, ",") then
        table.insert(found, "the package holds the libraries and nothing else: " .. table.concat(files, ","))
    end

    local foo = path.join(extracted, "usr", "lib", "revenant", NAME, "libFooBackports.dylib")
    local names = fixtures.run(folder, "xcrun", {"otool", "-L", foo}) .. fixtures.run(folder, "xcrun", {"otool", "-D", foo})
    if not names:find("/usr/lib/revenant/" .. NAME .. "/libFooBackports.dylib", 1, true) or
       not names:find("/usr/lib/revenant/" .. BASE .. "/libbase.1.dylib", 1, true) or names:find("@rpath", 1, true) then
        table.insert(found, "a library of the package is named by its folder and names the shared library by its package's folder: " .. names)
    end
    if not fixtures.run(extracted, "xcrun", {"otool", "-l", foo}):find("LC_CODE_SIGNATURE", 1, true) then
        table.insert(found, "the libraries of a written package are signed")
    end
    local staged_names = fixtures.run(folder, "xcrun", {"otool", "-L", path.join(folder, "libFooBackports.dylib")})
    if staged_names:find("LC_CODE_SIGNATURE", 1, true) or staged_names:find("/usr/lib/revenant/" .. NAME, 1, true) then
        table.insert(found, "the built library is left as the build made it: signing and naming are the package's")
    end

    local errors = fixtures.refusal(function ()
        backports.write({targets = targets, ldid = opt.ldid, packages = {}, provided = provided, workdir = path.join(folder, "refused"), outputdir = outputs})
    end)
    if not errors or not errors:find("which no package of the platform holds", 1, true) then
        table.insert(found, "a library that names a shared library no package holds must be refused: " .. tostring(errors))
    end
    errors = fixtures.refusal(function ()
        backports.write({targets = targets, ldid = opt.ldid, packages = packages, provided = {}, workdir = path.join(folder, "unnamed"), outputdir = outputs})
    end)
    if not errors or not errors:find("still depends on @rpath/libbase.1.dylib", 1, true) then
        table.insert(found, "a library that names a shared library by @rpath, which the package cannot resolve, must be refused: " .. tostring(errors))
    end
    local unbuilt = fixtures.refusal(function ()
        backports.write({targets = {target("MissingBackports", path.join(folder, "missing.dylib"))}, ldid = opt.ldid, packages = {},
                         provided = {}, workdir = path.join(folder, "unbuilt"), outputdir = outputs})
    end)
    if not unbuilt or not unbuilt:find("is not built", 1, true) then
        table.insert(found, "a target that is not built must be refused, not packaged as nothing: " .. tostring(unbuilt))
    end

    io.writefile(path.join(folder, "abi.c"), "int abi(void) { return 5; }\n")
    io.writefile(path.join(folder, "cxx.c"), "extern int abi(void);\nint cxx(void) { return abi() + 1; }\n")
    io.writefile(path.join(folder, "vision.c"), "extern int cxx(void);\nint vision(void) { return cxx() + 1; }\n")
    fixtures.link(folder, opt.ld64, "libc++abi.1.0.dylib", "armv7-apple-ios6.0", "abi.c",{"-dynamiclib", "-install_name", "@rpath/libc++abi.1.dylib"})
    fixtures.link(folder, opt.ld64, "libc++.1.0.dylib", "armv7-apple-ios6.0", "cxx.c", {"-dynamiclib", "-install_name", "@rpath/libc++.1.dylib", "-L.", "-lc++abi.1.0"})
    fixtures.link(folder, opt.ld64, "libVisionFixture.dylib", "armv7-apple-ios6.0", "vision.c", {"-dynamiclib", "-install_name", "@rpath/libVisionFixture.dylib", "-L.", "-lc++.1.0"})
    local runtime = path.join(folder, "runtime", "lib")
    os.mkdir(runtime)
    os.cp(path.join(folder, "libc++.1.0.dylib"), runtime .. "/")
    os.cp(path.join(folder, "libc++abi.1.0.dylib"), runtime .. "/")
    os.ln(path.join(runtime, "libc++.1.0.dylib"), path.join(runtime, "libc++.1.dylib"))
    os.ln(path.join(runtime, "libc++abi.1.0.dylib"), path.join(runtime, "libc++abi.1.dylib"))
    local libcxx = {installdir = function () return path.join(folder, "runtime") end}
    local carried = backports.carried_runtime(libcxx)
    local pairs_found = {}
    for _, library in ipairs(carried) do
        table.insert(pairs_found, library.leaf .. "=" .. path.filename(library.file))
    end
    if table.concat(pairs_found, ",") ~= "libc++.1.dylib=libc++.1.0.dylib,libc++abi.1.dylib=libc++abi.1.0.dylib" then
        table.insert(found, "the carried runtime is the libc++ and libc++abi of the C++ runtime by their real files, not their links: " .. table.concat(pairs_found, ","))
    end

    local vision = path.join(folder, "libVisionFixture.dylib")
    local withRuntime = backports.write({targets = {target("VisionBackports", vision)}, ldid = opt.ldid, packages = {}, provided = {},
                                        runtime = carried, workdir = path.join(folder, "runtime-work"), outputdir = path.join(folder, "runtime-debs")})
    local unpacked = path.join(folder, "runtime-unpacked")
    unpack(withRuntime.deb, unpacked)
    local dir = path.join(unpacked, "usr", "lib", "revenant", NAME)
    local listed = {}
    for _, file in ipairs(os.files(path.join(unpacked, "usr", "**"))) do
        table.insert(listed, path.relative(file, unpacked))
    end
    table.sort(listed)
    local expected = {"usr/lib/revenant/" .. NAME .. "/libVisionFixture.dylib", "usr/lib/revenant/" .. NAME .. "/libc++.1.dylib", "usr/lib/revenant/" .. NAME .. "/libc++abi.1.dylib"}
    table.sort(expected)
    if table.concat(listed, ",") ~= table.concat(expected, ",") then
        table.insert(found, "the package carries the runtime's pair beside the libraries, under the package's folder: " .. table.concat(listed, ","))
    end
    local vision_names = fixtures.run(folder, "xcrun", {"otool", "-L", path.join(dir, "libVisionFixture.dylib")})
    if vision_names:find("@rpath", 1, true) or not vision_names:find(FOLDER .. "/libc++.1.dylib", 1, true) then
        table.insert(found, "a Backports library that links the C++ runtime names the carried libc++ in the package's folder, not @rpath: " .. vision_names)
    end
    local libcxx_names = fixtures.run(folder, "xcrun", {"otool", "-D", path.join(dir, "libc++.1.dylib")}) ..
                         fixtures.run(folder, "xcrun", {"otool", "-L", path.join(dir, "libc++.1.dylib")})
    if not libcxx_names:find(FOLDER .. "/libc++.1.dylib", 1, true) or not libcxx_names:find(FOLDER .. "/libc++abi.1.dylib", 1, true) or libcxx_names:find("@rpath", 1, true) then
        table.insert(found, "the carried libc++ is named by the package's folder and names the carried libc++abi there: " .. libcxx_names)
    end
    local abi_names = fixtures.run(folder, "xcrun", {"otool", "-D", path.join(dir, "libc++abi.1.dylib")})
    if not abi_names:find(FOLDER .. "/libc++abi.1.dylib", 1, true) then
        table.insert(found, "the carried libc++abi is named by the package's folder: " .. abi_names)
    end
    for _, file in ipairs({"libVisionFixture.dylib", "libc++.1.dylib", "libc++abi.1.dylib"}) do
        if not fixtures.run(unpacked, "xcrun", {"otool", "-l", path.join(dir, file)}):find("LC_CODE_SIGNATURE", 1, true) then
            table.insert(found, "the carried runtime is signed like the libraries: " .. file)
        end
    end
    local collision = fixtures.refusal(function ()
        backports.write({targets = {target("VisionBackports", vision)}, ldid = opt.ldid, packages = {}, provided = {},
                         runtime = {{leaf = "libVisionFixture.dylib", file = carried[1].file}}, workdir = path.join(folder, "collision"), outputdir = outputs})
    end)
    if not collision or not collision:find("already is", 1, true) then
        table.insert(found, "a carried runtime that names a library of the package must be refused: " .. tostring(collision))
    end

    os.tryrm(folder)
    return found
end
