import("core.base.json")

function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local translate = import("translate", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local e
    e, out = corpus.setup("ordinal", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local function h(file)
        return path.join(here, file)
    end
    local function cc(argv)
        corpus.ios(e, table.join({"-w"}, argv))
    end
    local function xlate(argv, log)
        return corpus.run(e.xlate, argv, log)
    end
    local function superclass_kind(manifest)
        return json.loadfile(manifest).images[1].classes[1].superclass.kind
    end
    local function kind(name)
        local ok, log = xlate({"--objc-manifest", o(name .. ".json"), o(name), o("libfake.dylib")}, o(name .. ".log"))
        if not ok then
            io.write(log)
            corpus.fail("xlate refused %s", name)
        end
        return superclass_kind(o(name .. ".json"))
    end

    cc({"-dynamiclib", "-install_name", "@rpath/libfake.dylib", "-lobjc", h("fake.m"), "-o", o("libfake.dylib")})
    cc({"-dynamiclib", "-install_name", "@rpath/libbridge.dylib", h("bridge.c"), "-o", o("libbridge.dylib")})
    cc({"-framework", "Foundation", h("app.m"), "-o", o("host-app")})
    cc({h("app.m"), o("libfake.dylib"), "-framework", "Foundation", "-o", o("guest-app")})
    if kind("host-app") ~= "import" then
        corpus.fail("a bind to Foundation's NSString was taken by libfake")
    end
    if kind("guest-app") ~= "local" then
        corpus.fail("a bind to libfake's NSString was not resolved to libfake")
    end

    cc({"-framework", "Foundation", h("classref.m"), "-o", o("host-classref")})
    cc({h("classref.m"), o("libfake.dylib"), "-framework", "Foundation", "-o", o("guest-classref")})
    cc({h("call.c"), "-o", o("host-call")})
    cc({h("call.c"), o("libfake.dylib"), "-o", o("guest-call")})
    local passthrough = {}
    for _, line in ipairs((os.iorunv("nm", {"-u", o("host-classref"), o("libfake.dylib")})):split("\n")) do
        if line:startswith("_") then
            passthrough[line] = true
        end
    end
    local names = table.keys(passthrough)
    corpus.sorted(names)
    io.writefile(o("passthrough.txt"), table.concat(names, "\n") .. "\n")
    local function lift(name)
        local ok, log = xlate({"--base", "0x10000000", "--output", o(name .. ".bc"), "--layout", o(name .. ".layout"), "--passthrough", o("passthrough.txt"),
                               "--state-header", o(name .. ".h"), "--bridge", o("libbridge.dylib"), o(name), o("libfake.dylib"), o("libbridge.dylib")}, o(name .. ".err"))
        if not ok then
            io.write(log)
            corpus.fail("xlate refused to lift %s", name)
        end
        os.execv(path.join(e.llvmbin, "llvm-dis"), {o(name .. ".bc"), "-o", o(name .. ".ll")})
        return io.readfile(o(name .. ".ll"))
    end
    if not lift("host-classref"):find('@"OBJC_CLASS_$_NSString" = external', 1, true) then
        corpus.fail("a class reference to Foundation's NSString was taken by libfake")
    end
    if lift("guest-classref"):find('@"OBJC_CLASS_$_NSString"', 1, true) then
        corpus.fail("a class reference to libfake's NSString was not resolved to libfake")
    end

    local ok, log = xlate({"--base", "0x10000000", "--output", o("host-call.bc"), "--layout", o("host-call.layout"), "--passthrough", o("passthrough.txt"),
                           "--state-header", o("host-call.h"), o("host-call"), o("libfake.dylib")}, o("host-call.err"))
    if ok then
        corpus.fail("a call stub to libSystem's getpid was taken by libfake")
    end
    if not log:find("call stub for unresolved import _getpid", 1, true) then
        io.write(log)
        corpus.fail("xlate refused host-call for another reason")
    end
    ok, log = xlate({"--base", "0x10000000", "--output", o("guest-call.bc"), "--layout", o("guest-call.layout"), "--passthrough", o("passthrough.txt"),
                     "--state-header", o("guest-call.h"), o("guest-call"), o("libfake.dylib")}, o("guest-call.err"))
    if not ok then
        io.write(log)
        corpus.fail("a call stub to libfake's getpid was not resolved to libfake")
    end

    os.mkdir(o("a"))
    os.mkdir(o("b"))
    cc({"-dynamiclib", "-install_name", "@rpath/libcoll.dylib", "-lobjc", h("coll_a.m"), "-o", o("a/libcoll.dylib")})
    cc({"-dynamiclib", "-install_name", "@rpath/sub/libcoll.dylib", "-lobjc", h("coll_b.m"), "-o", o("b/libcoll.dylib")})
    cc({"-dynamiclib", "-install_name", "@rpath/libfrombx.dylib", "-lobjc", h("frombx.m"), o("b/libcoll.dylib"), "-o", o("libfrombx.dylib")})
    cc({"-lobjc", h("froma.m"), o("a/libcoll.dylib"), o("libfrombx.dylib"), "-o", o("coll-app")})
    ok, log = xlate({"--objc-manifest", o("coll.json"), o("coll-app"), o("libfrombx.dylib"), o("a/libcoll.dylib"), o("b/libcoll.dylib")}, o("coll.err"))
    if not ok then
        io.write(log)
        corpus.fail("xlate refused coll-app")
    end
    local classes = {}
    for index, image in ipairs(json.loadfile(o("coll.json")).images) do
        for _, class in ipairs(image.classes) do
            classes[class.data.name] = classes[class.data.name] or {}
            table.insert(classes[class.data.name], {index = index, class = class})
        end
    end
    local shared = {}
    for _, entry in ipairs(classes.Shared or {}) do
        shared[entry.index] = entry.class.address
    end
    local function superclass(name)
        local entries = classes[name] or {}
        if #entries ~= 1 or entries[1].class.superclass.kind ~= "local" then
            corpus.fail("a bind to one of two same-named libraries was answered by the other (%s)", name)
        end
        return entries[1].class.superclass.address
    end
    if #table.keys(shared) ~= 2 or superclass("FromA") ~= shared[3] or superclass("FromB") ~= shared[4] then
        corpus.fail("a bind to one of two same-named libraries was answered by the other")
    end

    os.cp(o("a/libcoll.dylib"), o("libcoll-copy.dylib"))
    ok, log = xlate({"--objc-manifest", o("dup.json"), o("coll-app"), o("a/libcoll.dylib"), o("libcoll-copy.dylib")}, o("dup.err"))
    if ok then
        corpus.fail("two images of one install name were accepted")
    end
    if not log:find("libcoll%-copy%.dylib and .*/a/libcoll%.dylib are both @rpath/libcoll%.dylib") then
        io.write(log)
        corpus.fail("the refusal does not name both images")
    end

    os.mkdir(o("guest"))
    cc({"-dynamiclib", "-install_name", "/usr/lib/libsyscoll.1.dylib", "-lobjc", h("coll_a.m"), "-o", o("libsyscoll.1.dylib")})
    cc({"-dynamiclib", "-install_name", "@rpath/libsyscoll.1.dylib", "-lobjc", h("coll_a.m"), "-o", o("guest/libsyscoll.1.dylib")})
    cc({"-lobjc", h("sysbound.m"), o("libsyscoll.1.dylib"), "-o", o("sys-app")})
    ok, log = xlate({"--objc-manifest", o("sys-plain.json"), o("sys-app"), o("guest/libsyscoll.1.dylib")}, o("sys-plain.err"))
    if not ok then
        io.write(log)
        corpus.fail("xlate refused sys-app")
    end
    if superclass_kind(o("sys-plain.json")) ~= "import" then
        corpus.fail("a system-path bind was taken by an image of the same file name")
    end
    if not log:find("--replaces /usr/lib/libsyscoll.1.dylib=", 1, true) then
        io.write(log)
        corpus.fail("no message offers --replaces")
    end
    ok, log = xlate({"--replaces", "/usr/lib/libsyscoll.1.dylib=" .. o("guest/libsyscoll.1.dylib"), "--objc-manifest", o("sys-replaced.json"), o("sys-app"),
                     o("guest/libsyscoll.1.dylib")}, o("sys-replaced.err"))
    if not ok or superclass_kind(o("sys-replaced.json")) ~= "local" then
        corpus.fail("--replaces did not make the guest image answer the system-path bind")
    end
    ok = xlate({"--replaces", "/usr/lib/libsyscoll.1.dylib=" .. o("nothing.dylib"), "--objc-manifest", o("sys-bad.json"), o("sys-app"),
                o("guest/libsyscoll.1.dylib")}, o("sys-bad.err"))
    if ok then
        corpus.fail("--replaces naming a file that is no input was accepted")
    end
    ok, log = xlate({"--replaces", "/usr/lib/libsyscoll.1.dylib=" .. o("guest/libsyscoll.1.dylib"), "--replaces", "/usr/lib/libsyscoll.1.dylib=" .. o("a/libcoll.dylib"),
                     "--objc-manifest", o("sys-twice.json"), o("sys-app"), o("guest/libsyscoll.1.dylib"), o("a/libcoll.dylib")}, o("sys-twice.err"))
    if ok then
        corpus.fail("--replaces naming one library twice was accepted")
    end
    if not log:find("--replaces /usr/lib/libsyscoll.1.dylib is given twice", 1, true) then
        io.write(log)
        corpus.fail("the refusal of a library named twice says something else")
    end
    ok, log = xlate({"--replaces", "@rpath/libcoll.dylib=" .. o("guest/libsyscoll.1.dylib"), "--objc-manifest", o("sys-own.json"), o("sys-app"),
                     o("guest/libsyscoll.1.dylib"), o("a/libcoll.dylib")}, o("sys-own.err"))
    if ok then
        corpus.fail("--replaces on an image's own install name was accepted")
    end
    if not log:find("that is the install name of .*/a/libcoll%.dylib") then
        io.write(log)
        corpus.fail("the refusal of an install name says something else")
    end

    cc({"-dynamiclib", "-install_name", "@rpath/libreexported.dylib", h("reexported.c"), "-o", o("libreexported.dylib")})
    cc({"-dynamiclib", "-install_name", "@rpath/libreexporter.dylib", h("reexporter.c"), "-Wl,-reexport_library," .. o("libreexported.dylib"),
        "-Wl,-rpath," .. out, "-o", o("libreexporter.dylib")})
    cc({h("callre.c"), o("libreexporter.dylib"), "-Wl,-rpath," .. out, "-o", o("re-app")})
    if not os.iorunv("otool", {"-L", o("re-app")}):find("libreexporter.dylib", 1, true) then
        corpus.fail("the fixture does not bind through libreexporter")
    end
    local function resolved(file)
        for _, line in ipairs(io.readfile(file):split("\n")) do
            if line == "_xl_reexported" then
                return true
            end
        end
    end
    if not xlate({"--objc-manifest", o("re.json"), "--resolved-out", o("re-resolved.txt"), o("re-app"), o("libreexporter.dylib"), o("libreexported.dylib")}, o("re.err")) then
        corpus.fail("xlate refused re-app")
    end
    if not resolved(o("re-resolved.txt")) then
        corpus.fail("a name libreexporter re-exports whole from libreexported was not listed as answered")
    end
    if not xlate({"--objc-manifest", o("re-alone.json"), "--resolved-out", o("re-alone-resolved.txt"), o("re-app"), o("libreexporter.dylib")}, o("re-alone.err")) then
        corpus.fail("xlate refused re-app alone")
    end
    if resolved(o("re-alone-resolved.txt")) then
        corpus.fail("a re-export whose target is no input was listed as answered")
    end

    os.cp(path.join(e.recompiler, "include", "uikit-includes.h"), o("includes.h"))
    for _, shape in ipairs({"host", "guest"}) do
        os.tryrm(o(shape .. "-xl"))
        translate.translate(o(shape .. "-app"), o("includes.h"), o(shape .. "-xl"), {o("libfake.dylib")})
    end
    local function listed(file, symbol)
        for _, line in ipairs(io.readfile(file):split("\n")) do
            if line == symbol then
                return true
            end
        end
        return false
    end
    local nsstring = "_OBJC_CLASS_$_NSString"
    if not listed(o("host-xl/imports.txt"), nsstring) then
        corpus.fail("the host's NSString was dropped from imports.txt because an embedded image defines that name")
    end
    if listed(o("host-xl/guest-resolved.txt"), nsstring) then
        corpus.fail("a bind to the host's NSString was listed as answered by a guest image")
    end
    if listed(o("guest-xl/imports.txt"), nsstring) then
        corpus.fail("a bind to libfake's NSString was left in imports.txt")
    end
    if not listed(o("guest-xl/guest-resolved.txt"), nsstring) then
        corpus.fail("a bind to libfake's NSString was not listed as answered by it")
    end
    print("ok")
end
