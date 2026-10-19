import("fixtures")

-- The packages of a shared runtime: their libraries get absolute names in a tree that is left unsigned, the recipes that stage
-- them carry no ldid, and the program that depends on them writes and signs their Debian packages.
function failures(opt)
    local shared = import("apple.shared_runtime", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    io.writefile(path.join(folder, "base.c"), "int base(void) { return 1; }\n")
    io.writefile(path.join(folder, "top.c"), "extern int base(void);\nint top(void) { return base() + 1; }\n")
    fixtures.link(folder, opt.ld64, "libbase.1.dylib", "armv7-apple-ios6.0", "base.c",
                  {"-dynamiclib", "-install_name", "@rpath/libbase.1.dylib"})
    fixtures.link(folder, opt.ld64, "libtop.1.dylib", "armv7-apple-ios6.0", "top.c",
                  {"-dynamiclib", "-install_name", "@rpath/libtop.1.dylib", "-L.", "-lbase.1"})
    local first, second = "org.example.base-11111111", "org.example.top-11111111"
    local root, described = path.join(folder, "root"), path.join(folder, "shared-packages")
    shared.stage({packages = {
                      {name = first, version = "1.0+11111111", title = "Base", description = "The base library",
                       libraries = {path.join(folder, "libbase.1.dylib")}},
                      {name = second, version = "1.0+11111111", title = "Top", description = "The library above it",
                       depends = {first .. " (= 1.0+11111111)"}, libraries = {path.join(folder, "libtop.1.dylib")}}},
                  root = root, metadata = described, strip = {"-x"}})

    local top = path.join(root, "usr", "lib", "charon", second, "libtop.1.dylib")
    local names = fixtures.run(folder, "xcrun", {"otool", "-L", top}) .. fixtures.run(folder, "xcrun", {"otool", "-D", top})
    if not names:find("/usr/lib/charon/" .. first .. "/libbase.1.dylib", 1, true) or
       not names:find("/usr/lib/charon/" .. second .. "/libtop.1.dylib", 1, true) or names:find("@rpath", 1, true) then
        table.insert(found, "a staged library must be named by its package's folder and reach the library of another package by that one's folder: " .. names)
    end
    local description = shared.metadata(described, second)
    if description.version ~= "1.0+11111111" or description.folder ~= "/usr/lib/charon/" .. second or
       description.depends[1] ~= first .. " (= 1.0+11111111)" then
        table.insert(found, "what a staged package is must be left for the program that writes its Debian package: " .. table.concat(table.keys(description), " "))
    end
    if #os.files(path.join(root, "**", "*.deb")) > 0 then
        table.insert(found, "staging writes no Debian package: that is the program's, which signs the libraries")
    end

    -- written, and signed, by the program
    local outputs = path.join(folder, "debs")
    local written = shared.deb(description, root, opt.ldid, path.join(folder, "work"), outputs)
    local extracted = path.join(folder, "extracted")
    os.mkdir(extracted)
    fixtures.run(extracted, "ar", {"x", written})
    local members = fixtures.run(extracted, "tar", {"tzf", "data.tar.gz"})
    if not members:find("usr/lib/charon/" .. second .. "/libtop.1.dylib", 1, true) or members:find(first, 1, true) then
        table.insert(found, "a package holds its own folder and nothing of another's: " .. members)
    end
    fixtures.run(extracted, "tar", {"xzf", "data.tar.gz"})
    fixtures.run(extracted, "tar", {"xzf", "control.tar.gz"})
    local control = io.readfile(path.join(extracted, "control"))
    if not control:find("Package: " .. second, 1, true) or not control:find("Depends: " .. first .. " (= 1.0+11111111)", 1, true) then
        table.insert(found, "the control file names the package and the exact package it needs: " .. control)
    end
    local inside = path.join(extracted, "usr", "lib", "charon", second, "libtop.1.dylib")
    local signed = fixtures.run(extracted, "xcrun", {"otool", "-l", inside})
    if not signed:find("LC_CODE_SIGNATURE", 1, true) then
        table.insert(found, "the library of a written package must be signed")
    end
    local staged = fixtures.run(folder, "xcrun", {"otool", "-l", top})
    if staged:find("LC_CODE_SIGNATURE", 1, true) then
        table.insert(found, "the staged tree stays unsigned: signing is the program's")
    end

    -- The recipes that stage a package name no host tool as a dependency: what a package depends on, the packages that depend
    -- on it depend on too, and ldid brings the openssl of the host with it.
    for _, recipe in ipairs({"packages/l/libcxx/xmake.lua", "packages/s/swift-runtime/xmake.lua"}) do
        local text = io.readfile(path.join(opt.modules, "..", recipe))
        if text:find("charon@ldid", 1, true) then
            table.insert(found, recipe .. " must not depend on ldid: a host tool's dependencies (openssl) reach every package that depends on this one")
        end
    end

    -- A library the link line names and nothing is bound to is a library the loader opens for nothing, and the ones that
    -- one names open in turn. libtop above binds base and nothing else; libwide is the same code linked with a second
    -- library on its line that its code never calls, and ld64 keeps a dylib named on the command line whether or not a
    -- symbol resolves to it (measured on libswiftSpatial.dylib, which named libswiftDarwin and libswiftsimd and bound
    -- nothing from either). Read from the tools' own output over a linked image, so no fixture text stands for it.
    io.writefile(path.join(folder, "idle.c"), "int idle(void) { return 3; }\n")
    fixtures.link(folder, opt.ld64, "libidle.1.dylib", "armv7-apple-ios6.0", "idle.c",
                  {"-dynamiclib", "-install_name", "@rpath/libidle.1.dylib"})
    fixtures.link(folder, opt.ld64, "libwide.1.dylib", "armv7-apple-ios6.0", "top.c",
                  {"-dynamiclib", "-install_name", "@rpath/libwide.1.dylib", "-L.", "-lbase.1", "-lidle.1"})
    local tight = table.concat(shared.unbound_dependencies(path.join(folder, "libtop.1.dylib"), "armv7"), " ")
    if tight ~= "" then
        table.insert(found, "a library whose code binds every library it names has none that are not, and this one was told " .. tight)
    end
    local wide = table.concat(shared.unbound_dependencies(path.join(folder, "libwide.1.dylib"), "armv7"), " ")
    if wide ~= "libidle.1.dylib" then
        table.insert(found, "a library that names a second library its code never calls is told which: libidle.1.dylib, and it was told '" .. wide .. "'")
    end
    os.tryrm(folder)
    return found
end
