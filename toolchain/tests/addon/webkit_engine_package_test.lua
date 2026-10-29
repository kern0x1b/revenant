import("fixtures")

local NAME = "org.revenant.webkit-engine"
local FOLDER = "/usr/lib/revenant/webkit-engine"
local LIBCXX = "org.example.libcxx-11111111"
local TRIPLE = "armv7-apple-ios6.0"
local FRAMEWORKS = {"JavaScriptCore", "WebCore", "WebKitLegacy"}

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

function failures(opt)
    local engine = import("apple.webkit_engine_package", {rootdir = opt.modules, anonymous = true})
    import("apple.platform", {rootdir = opt.modules, anonymous = true})
    import("packaging", {rootdir = opt.modules, anonymous = true})
    -- The recipe's bundle step, parsed from the engine package's modules: it runs only at a build.
    import("stage", {rootdir = path.join(path.directory(path.directory(opt.modules)), "frameworks", "WebKit", "src", "modules"), anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    io.writefile(path.join(folder, "cxx.c"), "int cxx(void) { return 1; }\n")
    io.writefile(path.join(folder, "jsc.c"), "extern int cxx(void);\nint jsc(void) { return cxx() + 2; }\n")
    io.writefile(path.join(folder, "webcore.c"), "extern int cxx(void);\nint webcore(void) { return cxx() + 1; }\n")
    io.writefile(path.join(folder, "webkit.c"), "extern int webcore(void);\nextern int jsc(void);\nint webkit(void) { return webcore() + jsc(); }\n")
    fixtures.link(folder, opt.ld64, "libc++.1.dylib", TRIPLE, "cxx.c", {"-dynamiclib", "-install_name", "@rpath/libc++.1.dylib"})

    -- The frameworks as the prefixed build leaves them: siblings named by @executable_path, the C++
    -- runtime named by its install name. WebKitLegacy links the built siblings themselves, so it
    -- records their install names.
    local build = path.join(folder, "build")
    for _, framework in ipairs(FRAMEWORKS) do
        os.mkdir(path.join(build, framework .. ".framework"))
    end
    fixtures.link(folder, opt.ld64, "build/JavaScriptCore.framework/JavaScriptCore", TRIPLE, "jsc.c",
                  {"-dynamiclib", "-install_name", "@executable_path/Frameworks/JavaScriptCore.framework/JavaScriptCore", "-L.", "-lc++.1"})
    fixtures.link(folder, opt.ld64, "build/WebCore.framework/WebCore", TRIPLE, "webcore.c",
                  {"-dynamiclib", "-install_name", "@executable_path/Frameworks/WebCore.framework/WebCore", "-L.", "-lc++.1"})
    fixtures.link(folder, opt.ld64, "build/WebKitLegacy.framework/WebKitLegacy", TRIPLE, "webkit.c",
                  {"-dynamiclib", "-install_name", "@executable_path/Frameworks/WebKitLegacy.framework/WebKitLegacy", "-L.", "-lc++.1",
                   path.join(build, "WebCore.framework", "WebCore"), path.join(build, "JavaScriptCore.framework", "JavaScriptCore")})

    -- The engine recipe copies the frameworks into its deb folder before the bundle names them.
    local deb = path.join(folder, "engine", "deb")
    os.mkdir(deb)
    for _, framework in ipairs(FRAMEWORKS) do
        os.vcp(path.join(build, framework .. ".framework"), deb .. "/")
    end

    local held = "/usr/lib/revenant/" .. LIBCXX .. "/libc++.1.dylib"
    local packages = {{name = LIBCXX, version = "1.0+11111111", held = {[held] = true}}}
    local provided = {["libc++.1.dylib"] = held}
    local outputs = path.join(folder, "debs")
    local written = engine.write({installdir = deb, ldid = opt.ldid, packages = packages, provided = provided,
                                  workdir = path.join(folder, "work"), outputdir = outputs})

    if written.name ~= NAME or written.relation ~= "=" or not written.version:find("^%d[%d%.]*%+%x%x%x%x%x%x%x%x$") then
        table.insert(found, "the package is named " .. NAME .. " and pinned by an exact version with the build's hash, got " ..
                     tostring(written.name) .. " " .. tostring(written.relation) .. " " .. tostring(written.version))
    end
    if table.concat(written.depends, ", ") ~= LIBCXX .. " (= 1.0+11111111)" then
        table.insert(found, "the package needs the shared C++ runtime it names, and no other: " .. table.concat(written.depends, ", "))
    end
    if #written.shared ~= 1 or written.shared[1] ~= packages[1] then
        table.insert(found, "the package hands the shared package it needs to the program that writes it beside the package: " .. tostring(#written.shared))
    end
    if path.filename(written.deb) ~= NAME .. "_" .. written.version .. "_iphoneos-arm.deb" or not os.isfile(written.deb) then
        table.insert(found, "the package is written as Package_Version_Architecture.deb: " .. written.deb)
    end
    if os.isdir(path.join(folder, "work")) then
        table.insert(found, "the staging folder is removed once the package is written")
    end
    if not os.isfile(path.join(deb, "WebCore.framework", "WebCore")) or fixtures.run(deb, "xcrun", {"otool", "-D", path.join(deb, "WebCore.framework", "WebCore")}):find(FOLDER, 1, true) then
        table.insert(found, "the engine's deb folder is left as the build made it: the package works from a copy")
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
                               "\nDepends: " .. LIBCXX .. " (= 1.0+11111111)\n", "\nInstalled-Size: "}) do
        if not control:find(expected, 1, true) then
            table.insert(found, "the control file carries " .. expected:gsub("\n", "") .. ": " .. control)
        end
    end

    local files = {}
    for _, file in ipairs(os.files(path.join(extracted, "usr", "**"))) do
        table.insert(files, path.relative(file, extracted))
    end
    table.sort(files)
    local expected = {}
    for _, framework in ipairs(FRAMEWORKS) do
        table.insert(expected, "usr/lib/revenant/webkit-engine/" .. framework .. ".framework/" .. framework)
    end
    table.sort(expected)
    if table.concat(files, ",") ~= table.concat(expected, ",") then
        table.insert(found, "the package holds the three frameworks and nothing else: " .. table.concat(files, ","))
    end

    for _, framework in ipairs(FRAMEWORKS) do
        local binary = path.join(extracted, "usr", "lib", "revenant", "webkit-engine", framework .. ".framework", framework)
        local names = fixtures.run(folder, "xcrun", {"otool", "-D", binary})
        if not names:find(FOLDER .. "/" .. framework .. ".framework/" .. framework, 1, true) or names:find("@", 1, true) then
            table.insert(found, "a framework is named by its folder under the package: " .. framework .. " " .. names)
        end
        if not fixtures.run(extracted, "xcrun", {"otool", "-l", binary}):find("LC_CODE_SIGNATURE", 1, true) then
            table.insert(found, "the frameworks of a written package are signed: " .. framework)
        end
    end
    local webkit = path.join(extracted, "usr", "lib", "revenant", "webkit-engine", "WebKitLegacy.framework", "WebKitLegacy")
    local webkit_names = fixtures.run(folder, "xcrun", {"otool", "-L", webkit})
    for _, wanted in ipairs({FOLDER .. "/WebCore.framework/WebCore", FOLDER .. "/JavaScriptCore.framework/JavaScriptCore", held}) do
        if not webkit_names:find(wanted, 1, true) then
            table.insert(found, "WebKitLegacy names " .. wanted .. " once it is written: " .. webkit_names)
        end
    end
    if webkit_names:find("@", 1, true) then
        table.insert(found, "no install name of a written framework is relative: " .. webkit_names)
    end

    local missing = fixtures.refusal(function ()
        engine.write({installdir = path.join(folder, "empty"), ldid = opt.ldid, packages = packages, provided = provided,
                      workdir = path.join(folder, "missing"), outputdir = outputs})
    end)
    if not missing or not missing:find("holds no JavaScriptCore.framework", 1, true) then
        table.insert(found, "an engine without its frameworks must be refused, not packaged: " .. tostring(missing))
    end
    local unnamed = fixtures.refusal(function ()
        engine.write({installdir = deb, ldid = opt.ldid, packages = {}, provided = provided,
                      workdir = path.join(folder, "unnamed"), outputdir = outputs})
    end)
    if not unnamed or not unnamed:find("which no package of the platform holds", 1, true) then
        table.insert(found, "a framework that names a shared library no package holds must be refused: " .. tostring(unnamed))
    end
    local relative = fixtures.refusal(function ()
        engine.write({installdir = deb, ldid = opt.ldid, packages = packages, provided = {},
                      workdir = path.join(folder, "relative"), outputdir = outputs})
    end)
    if not relative or not relative:find("still depends on @rpath/libc++.1.dylib", 1, true) then
        table.insert(found, "a framework that names the C++ runtime by @rpath, which the package cannot resolve, must be refused: " .. tostring(relative))
    end

    os.tryrm(folder)
    return found
end
