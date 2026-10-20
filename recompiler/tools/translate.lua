import("core.base.json")
import("async.runjobs")
import("env")
import("macho")
import("absent_on_target")
import("imports")

local CORE_FRAMEWORKS = {Foundation = true, CoreFoundation = true, CoreGraphics = true, UIKit = true, QuartzCore = true,
                         CoreText = true, Security = true}

local function words(text)
    local list = {}
    for word in (text or ""):gmatch("%S+") do
        table.insert(list, word)
    end
    return list
end

local function lines(text)
    local list = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(list, line)
    end
    if list[#list] == "" then
        table.remove(list)
    end
    return list
end

local function sorted(list)
    return env.sorted(list)
end

local function unique(list)
    local seen, result = {}, {}
    for _, item in ipairs(list) do
        if not seen[item] then
            seen[item] = true
            table.insert(result, item)
        end
    end
    return sorted(result)
end

local function readlines(file)
    return lines(io.readfile(file))
end

local function writelines(file, list)
    io.writefile(file, #list > 0 and (table.concat(list, "\n") .. "\n") or "")
end

local function set(list)
    local result = {}
    for _, item in ipairs(list) do
        result[item] = true
    end
    return result
end

local function without(remove, list)
    local removed = set(remove)
    local result = {}
    for _, item in ipairs(list) do
        if not removed[item] then
            table.insert(result, item)
        end
    end
    return result
end

local function difference(list, remove)
    return without(remove, list)
end

local function iorun(program, argv)
    return os.iorunv(program, argv)
end

local function tryiorun(program, argv)
    return try { function () return (os.iorunv(program, argv)) end } or ""
end

local function run(program, argv, opt)
    os.execv(program, argv, opt)
end

local function filesize(file)
    return os.isfile(file) and os.filesize(file) or 0
end

local function basename(file)
    return path.filename(file)
end

local function nm_defined(files)
    local symbols = {}
    for _, line in ipairs(lines(iorun("nm", table.join({"-gU"}, files)))) do
        local fields = words(line)
        if #fields == 3 then
            table.insert(symbols, fields[3])
        end
    end
    return symbols
end

local function nm_undefined(file)
    local symbols = {}
    for _, line in ipairs(lines(tryiorun("nm", {"-u", file}))) do
        local fields = words(line)
        table.insert(symbols, fields[#fields] or "")
    end
    return symbols
end

local function dyld_imports(image)
    local result = {}
    local all = lines(iorun("xcrun", {"dyld_info", "-imports", image}))
    for index = 3, #all do
        local fields = words(all[index])
        local symbol = fields[1] or ""
        if symbol:startswith("0x") then
            symbol = fields[2] or ""
        end
        table.insert(result, {symbol = symbol, weak = all[index]:find("[weak-import]", 1, true) ~= nil})
    end
    return result
end

local function classes_of(symbols)
    local result = {}
    for _, symbol in ipairs(symbols) do
        local class = symbol:match("^_OBJC_CLASS_%$_(.*)$")
        if class then
            table.insert(result, class)
        end
    end
    return result
end

local function otool_libraries(input)
    local result = {}
    for _, line in ipairs(lines(iorun("otool", {"-L", input}))) do
        table.insert(result, {line = line, path = words(line)[1] or ""})
    end
    return result
end

local function embedded_frameworks(input, out, frameworks)
    local images = {}
    for _, library in ipairs(otool_libraries(input)) do
        if library.line:find("@rpath/", 1, true) or library.line:find("@executable_path/", 1, true) or library.line:find("@loader_path/", 1, true) then
            local dep = library.path
            local base = basename(dep)
            local src
            if dep:find("/.*%.framework/") then
                src = path.join(frameworks, basename(path.directory(dep)), base)
            else
                src = path.join(frameworks, base)
            end
            if not os.isfile(src) then
                print("embedded framework not found, skipping: %s", dep)
            else
                local kind = tryiorun("file", {"-b", src})
                if kind:find("Mach-O", 1, true) then
                    local image = src
                    local usable = true
                    if kind:find("universal", 1, true) then
                        image = path.join(out, base .. "-arm64")
                        if not try { function () os.runv("lipo", {src, "-thin", "arm64", "-output", image}); return true end } then
                            print("no arm64 slice, skipping: %s", base)
                            usable = false
                        end
                    end
                    if usable then
                        local swift = 0
                        for _, line in ipairs(lines(tryiorun("nm", {image}))) do
                            if line:find("_$s", 1, true) or line:find("_swift_", 1, true) then
                                swift = swift + 1
                            end
                        end
                        local classes = 0
                        for _, line in ipairs(lines(tryiorun("nm", {"-gj", image}))) do
                            if line:find("_OBJC_CLASS_$_", 1, true) then
                                classes = classes + 1
                            end
                        end
                        if classes == 0 or swift > classes then
                            print("embedded framework is predominantly Swift (%d swift / %d objc), not lifting: %s", swift, classes, base)
                        else
                            print("auto-lifting embedded framework: %s (%d objc classes)", base, classes)
                            table.insert(images, image)
                        end
                    end
                end
            end
        end
    end
    return images
end

local function lift_key(e, input, images, out, replaces, base)
    local parts = {}
    for _, file in ipairs(table.join({e.xlate, input}, images, {path.join(out, "passthrough.txt"), path.join(out, "libxl-guest.dylib")})) do
        table.insert(parts, hash.sha256(file))
    end
    table.insert(parts, table.concat(replaces, " ") .. " " .. base)
    return table.concat(parts, "\n")
end

local function split_compile(e, out, lifted, host, bytes)
    io.stderr:write(string.format("lifted.o: a module of %d bytes does not fit one object's branch range; splitting code, keeping data in one object\n", bytes))
    local split = path.join(out, "split")
    os.tryrm(split)
    os.mkdir(split)
    local clang = path.join(e.llvmbin, "clang")
    local data = path.join(split, "data.bc")
    os.execv(path.join(e.llvmbin, "llvm-extract"), {"--delete", "--rfunc=.*", lifted, "-o", data})
    local jobs = {{bitcode = data, object = path.join(split, "data.o")}}
    os.execv(path.join(e.llvmbin, "llvm-split"), {"-j", "8", "-o", path.join(split, "p"), lifted})
    local pieces = {}
    for _, piece in ipairs(os.files(path.join(split, "p*"))) do
        local name = basename(piece)
        if name:match("^p%d") and not name:endswith(".o") and not name:endswith(".bc") then
            table.insert(pieces, piece)
        end
    end
    sorted(pieces)
    local objects = {path.join(split, "data.o")}
    for _, piece in ipairs(pieces) do
        table.insert(jobs, {piece = piece, bitcode = piece .. ".code.bc", object = piece .. ".o"})
        table.insert(objects, piece .. ".o")
    end
    local count = tonumber(os.getenv("XL_COMPILE_JOBS") or "") or 4
    runjobs("compile", function (index)
        local job = jobs[index]
        if job.piece then
            os.execv(path.join(e.llvmbin, "llvm-extract"), {"--delete", "--rglob=.*", job.piece, "-o", job.bitcode})
        end
        os.execv(clang, table.join(host, {"-c", job.bitcode, "-o", job.object}))
    end, {total = #jobs, comax = count + 1})
    return objects
end

local function compile_lifted(e, out, host)
    local lifted = path.join(out, "lifted.bc")
    local bytes = os.filesize(lifted)
    if bytes > (tonumber(os.getenv("XL_SPLIT_BYTES") or "") or 64000000) then
        return split_compile(e, out, lifted, host, bytes)
    end
    local log = path.join(out, "lifted-cc.log")
    local ok = os.execv(path.join(e.llvmbin, "clang"), table.join(host, {"-c", lifted, "-o", path.join(out, "lifted.o")}),
                        {stderr = log, try = true})
    if ok ~= 0 then
        if io.readfile(log):find("out of range", 1, true) then
            return split_compile(e, out, lifted, host, bytes)
        end
        io.stderr:write(io.readfile(log))
        raise("compiling lifted.bc failed")
    end
    return {path.join(out, "lifted.o")}
end

function translate(input, includes, out, images, opt)
    opt = opt or {}
    local function getenv(name)
        if opt[name] ~= nil then
            return opt[name]
        end
        return os.getenv(name)
    end
    local e = env()
    local lab = e.recompiler
    input = path.absolute(input)
    includes = path.absolute(includes)
    out = path.absolute(out)
    local incdir = path.directory(includes)
    local extra = {}
    for _, image in ipairs(images or {}) do
        table.insert(extra, path.absolute(image))
    end
    local name = basename(input)
    if #name > 6 and name:endswith("-arm64") then
        name = name:sub(1, -7)
    end
    os.mkdir(out)
    local function o(file)
        return path.join(out, file)
    end

    local frameworks = getenv("XL_FRAMEWORKS_DIR")
    if frameworks and frameworks ~= "" then
        table.join2(extra, embedded_frameworks(input, out, frameworks))
    end
    local base = getenv("XL_BASE") or "0x10000000"
    local guest = {"-target", "arm64-apple-ios12.0", "-isysroot", e.sdk, "-O2", "-fno-stack-protector", "-U_FORTIFY_SOURCE", "-D_FORTIFY_SOURCE=0", "-w"}
    local host = {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk, "-O2", "-w"}

    for _, source in ipairs({"runtime", "data"}) do
        run("xcrun", table.join({"clang"}, guest, {"-fno-builtin", "-I", e.blocks, "-c", path.join(e.blocks, source .. ".c"), "-o", o("support-blocks-" .. source .. ".o")}))
    end
    run("xcrun", table.join({"clang"}, guest, {"-fno-builtin", "-c", path.join(lab, "src", "runtime", "int128.c"), "-o", o("support-int128.o")}))
    run("xcrun", table.join({"clang"}, guest, {"-fno-builtin", "-c", path.join(lab, "src", "runtime", "availability.c"), "-o", o("support-availability.o")}))
    local support = sorted(os.files(o("support-*.o")))
    writelines(o("provided.txt"), unique(nm_defined(support)))

    local replaces = {}
    for _, spec in ipairs(words(getenv("XL_REPLACES"))) do
        table.join2(replaces, {"--replaces", spec})
    end
    run(e.xlate, table.join({"--base", base}, replaces, {"--objc-manifest", o("manifest.json"), "--resolved-out", o("guest-resolved.txt"), input}, extra))

    local support_undefined = {}
    for _, line in ipairs(lines(iorun("nm", table.join({"-u"}, support)))) do
        table.insert(support_undefined, line)
    end
    local all = {}
    for _, image in ipairs(table.join({input}, extra)) do
        for _, entry in ipairs(dyld_imports(image)) do
            table.insert(all, entry.symbol)
        end
        table.join2(all, nm_undefined(image))
    end
    for _, line in ipairs(support_undefined) do
        if line:startswith("_") then
            table.insert(all, line)
        end
    end
    table.join2(all, {"_objc_retain", "_objc_release"})
    writelines(o("all-imports.txt"), unique(all))

    local strong, weak = {}, {}
    for _, image in ipairs(table.join({input}, extra)) do
        for _, entry in ipairs(dyld_imports(image)) do
            if entry.weak then
                weak[entry.symbol] = true
            else
                strong[entry.symbol] = true
            end
        end
    end
    for _, line in ipairs(support_undefined) do
        local fields = words(line)
        strong[fields[#fields] or ""] = true
    end
    local weakonly = {}
    for symbol in pairs(weak) do
        if not strong[symbol] and symbol ~= "" then
            table.insert(weakonly, symbol)
        end
    end
    writelines(o("weak-only.txt"), sorted(weakonly))
    local resolved = readlines(o("guest-resolved.txt"))
    writelines(o("provided.txt"), unique(table.join(readlines(o("provided.txt")), resolved)))

    local backport_libs, strip_dylibs = {}, {}
    local backports = getenv("BACKPORTS_DIR")
    if backports ~= nil then
        backport_libs = backports ~= "" and sorted(os.files(path.join(backports, "lib*Backports.dylib"))) or {}
        if #backport_libs == 0 then
            raise("BACKPORTS_DIR='%s' holds no lib*Backports.dylib; unset it to translate without backports", backports)
        end
        strip_dylibs = {"-Wl,-dead_strip_dylibs"}
    end

    local imported = without(resolved, readlines(o("all-imports.txt")))
    writelines(o("imports.txt"), imported)
    local exports = {}
    for _, library in ipairs(backport_libs) do
        table.join2(exports, nm_defined({library}))
    end
    table.join2(exports, readlines(path.join(lab, "src", "runtime", "bridge-provides.txt")))
    writelines(o("backport-exports.txt"), exports)
    writelines(o("linked-exports.txt"), unique(table.join(exports, readlines(o("provided.txt")))))
    writelines(o("weak-absent.txt"), {})
    if filesize(o("weak-only.txt")) > 0 then
        local absent = absent_on_target.absent(path.join(e.dyld, "dyld_shared_cache_armv7"), o("weak-only.txt"), o("linked-exports.txt"))
        writelines(o("weak-absent.txt"), absent)
        imported = without(absent, imported)
        writelines(o("imports.txt"), imported)
        if #absent > 0 then
            print("warning: weak imports absent on the target, left unbound (the app takes its fallback):")
            for _, symbol in ipairs(absent) do
                print("  %s", symbol)
            end
        end
    end

    local entitlements = o("entitlements.plist")
    if os.execv("codesign", {"-d", "--entitlements", ":-", input}, {stdout = entitlements, stderr = os.nuldev(), try = true}) ~= 0 then
        io.writefile(entitlements, "")
    end
    run(e.xlgen, {"--entitlements", entitlements, "--sdk", e.sdk, "--resource-dir", e.resourcedir, "--includes", includes,
                  "--abi-header", path.join(lab, "src", "runtime", "objc_abi.h"), "--symbols", o("imports.txt"), "--guest-provided", o("provided.txt"),
                  "--weak-only", o("weak-only.txt"), "--objc-manifest", o("manifest.json"), "--guest-out", o("guest.m"),
                  "--host-out", o("host.m"), "--passthrough-out", o("passthrough.txt"), "--report-out", o("report.txt")})

    local need = {}
    for _, line in ipairs(imported) do
        need[line:match("^[^:]*")] = true
    end
    local unbridged = {}
    for _, line in ipairs(readlines(o("report.txt"))) do
        if line:find("UNSUPPORTED", 1, true) and need[line:match("^[^:]*")] then
            table.insert(unbridged, "  " .. line)
        end
    end
    writelines(o("unbridged-imports.txt"), unbridged)
    if #unbridged > 0 then
        print("warning: imported symbols without a bridge (a strong import aborts if reached, a weak one is left unbound):")
        for _, line in ipairs(unbridged) do
            print("%s", line)
        end
    end
    local traps = {}
    for trap in io.readfile(o("guest.m")):gmatch("xl_trap_[%w_]*") do
        table.insert(traps, trap)
    end
    local trapflags = {}
    for _, trap in ipairs(unique(traps)) do
        table.insert(trapflags, "-Wl,-U,_" .. trap)
    end
    run("xcrun", table.join({"clang"}, guest, {"-x", "objective-c", "-fno-objc-arc", "-fblocks", "-fno-builtin", "-iquote", incdir,
                                               "-c", o("guest.m"), "-o", o("guest.o")}))
    run("xcrun", table.join({"clang", "-target", "arm64-apple-ios12.0", "-isysroot", e.sdk, "-dynamiclib", "-install_name", "@rpath/libxl-guest.dylib",
                             o("guest.o")}, support, {"-o", o("libxl-guest.dylib")}, trapflags))

    local key = lift_key(e, input, extra, out, replaces, base)
    local lifted_objs
    if os.isfile(o("lift.stamp")) and io.readfile(o("lift.stamp")) == key and os.isfile(o("lifted-objs.txt")) then
        print("lift inputs unchanged since the last run: reusing its lifted objects")
        lifted_objs = words(io.readfile(o("lifted-objs.txt")))
    else
        os.tryrm(o("lift.stamp"))
        run(e.xlate, table.join({"--base", base, "--output", o("lifted.bc"), "--layout", o("layout.txt"), "--passthrough", o("passthrough.txt"),
                                 "--state-header", o("xl_state.h")}, replaces, {"--bridge", o("libxl-guest.dylib"), input}, extra, {o("libxl-guest.dylib")}))
        lifted_objs = compile_lifted(e, out, host)
        io.writefile(o("lifted-objs.txt"), table.concat(lifted_objs, " ") .. "\n")
        io.writefile(o("lift.stamp"), key)
    end

    local extra_cflags = words(getenv("XL_EXTRA_CFLAGS"))
    local clang = path.join(e.llvmbin, "clang")
    local runtime = path.join(lab, "src", "runtime")
    run(clang, table.join(host, {"-I", out, "-I", runtime}, extra_cflags, {"-c", path.join(runtime, "runtime.c"), "-o", o("runtime.o")}))
    for _, source in ipairs({path.join(runtime, "bridge.m"), path.join(runtime, "objc_bridge.m"), path.join(runtime, "swift_classes.m"),
                             path.join(runtime, "objc_compat.m"), o("host.m")}) do
        local object = o(path.basename(source) .. ".o")
        run(clang, table.join(host, {"-fno-objc-arc", "-fblocks", "-I", out, "-I", runtime, "-iquote", incdir}, extra_cflags, {"-c", source, "-o", object}))
        print("renamed %d sections", macho.rename_sections(object, true))
    end

    local libraries = otool_libraries(input)
    local framework_paths = {}
    for _, library in ipairs(libraries) do
        if library.line:find(".framework/", 1, true) then
            table.insert(framework_paths, library.path)
        end
    end
    local framework_flags = {}
    for _, fwpath in ipairs(unique(framework_paths)) do
        if not (fwpath:startswith("@rpath/") or fwpath:startswith("@executable_path/") or fwpath:startswith("@loader_path/")) then
            local fw = basename(fwpath)
            table.join2(framework_flags, {CORE_FRAMEWORKS[fw] and "-framework" or "-weak_framework", fw})
        end
    end
    local extra_libs = {}
    for _, library in ipairs(libraries) do
        if library.line:find("/usr/lib/lib.*%.dylib") then
            local base_name = basename(library.path)
            local stem = base_name
            if stem:startswith("lib") then
                stem = stem:sub(4)
            end
            if stem:endswith(".dylib") then
                stem = stem:sub(1, -7)
            end
            stem = stem:gsub("%.%d+$", "")
            while stem:find("%.%d+$") do
                stem = stem:gsub("%.%d+$", "")
            end
            local skip = ({System = true, ["System.B"] = true, objc = true, ["objc.A"] = true, ["c++"] = true, ["c++abi"] = true, z = true})[stem]
            for _, image in ipairs(extra) do
                if basename(image) == base_name then
                    skip = true
                end
            end
            if not skip then
                table.insert(extra_libs, "-l" .. stem)
            end
        end
    end

    local stock_classes = path.join(e.dyld, "classes_armv7.json")
    local stock = os.isfile(stock_classes) and json.loadfile(stock_classes).classes or nil
    local undef_flags = {}
    if stock then
        local wanted = classes_of(nm_undefined(input))
        for _, image in ipairs(extra) do
            table.join2(wanted, classes_of(nm_undefined(image)))
        end
        wanted = unique(wanted)
        writelines(o("imported-classes-pre.txt"), wanted)
        local covered = table.join(#stock > 0 and stock or {""})
        for _, library in ipairs(backport_libs) do
            table.join2(covered, classes_of(lines(tryiorun("nm", {"-gj", library}))))
        end
        table.join2(covered, classes_of(resolved))
        covered = unique(covered)
        writelines(o("covered-pre.txt"), covered)
        for _, class in ipairs(difference(wanted, covered)) do
            table.insert(undef_flags, "-Wl,-U,_OBJC_CLASS_$_" .. class)
        end
    end

    local binary = o(name)
    local function link(more)
        return os.execv("xcrun", table.join({"clang", "-target", "armv7-apple-ios6.0", "-isysroot", e.sdk, "-fuse-ld=" .. e.ld, "-Wl,-no_pie"},
                                            strip_dylibs, {"-Wl,-no_objc_category_merging", "-Wl,-no_deduplicate"}, words(io.readfile(o("layout.txt"))),
                                            lifted_objs, {o("runtime.o"), o("bridge.o"), o("objc_bridge.o"), o("swift_classes.o"), o("objc_compat.o"), o("host.o")},
                                            words(getenv("XL_EXTRA_OBJ")), backport_libs, framework_flags, undef_flags, more or {},
                                            {"-framework", "Foundation", "-framework", "CoreGraphics", "-framework", "UIKit", "-lobjc", "-lz"},
                                            extra_libs, {"-o", binary}), {stderr = o("link.err"), try = true}) == 0
    end
    if not link() then
        local retry = {}
        for symbol in io.readfile(o("link.err")):gmatch('"(_[%w_$]+)", referenced') do
            table.insert(retry, "-Wl,-U," .. symbol)
        end
        retry = unique(retry)
        io.stderr:write(io.readfile(o("link.err")))
        if #retry == 0 then
            raise("linking %s failed", binary)
        end
        print("relinking, permitting undefined-at-link (resolve at runtime): %s ", table.concat(retry, " "))
        if not link(retry) then
            io.stderr:write(io.readfile(o("link.err")))
            raise("linking %s failed", binary)
        end
    end
    print("renamed %d sections", macho.rename_sections(binary, false))

    if stock then
        local wanted = unique(classes_of(nm_undefined(binary)))
        writelines(o("imported-classes.txt"), wanted)
        local covered = table.join(#stock > 0 and stock or {""})
        for _, library in ipairs(backport_libs) do
            table.join2(covered, classes_of(lines(tryiorun("nm", {"-gj", library}))))
        end
        covered = unique(covered)
        writelines(o("covered-classes.txt"), covered)
        local uncovered = {}
        for _, class in ipairs(difference(wanted, covered)) do
            table.insert(uncovered, "_OBJC_CLASS_$_" .. class)
        end
        writelines(o("uncovered-classes.txt"), uncovered)
        if #uncovered > 0 then
            print("weak-binding %d uncovered class ref(s)", #uncovered)
            print("weakened %d symtab + %d bind-opcode entries", macho.weaken_classrefs(binary, uncovered))
        end
    end
    run(e.ldid, {"-S", binary})

    local bad = false
    for _, line in ipairs(lines(iorun("nm", {binary}))) do
        local fields = words(line)
        if fields[3] and fields[3]:startswith("_xl_guest_class_") and "_xl_guest_class_" .. fields[1] ~= fields[3] then
            print("misplaced %s at %s", fields[3], fields[1])
            bad = true
        end
    end
    local class
    for _, line in ipairs(lines(iorun("otool", {"-ov", binary}))) do
        if line:match("^[^ ]") then
            class = words(line)[1]
        end
        if line:find("instanceSize +0$") then
            print("zero instanceSize: %s", tostring(class))
            bad = true
        end
    end
    if bad then
        raise("%s fails the layout checks above", binary)
    end
    for _, line in ipairs(imports.report(path.join(e.dyld, "dyld_shared_cache_armv7"), {binary})) do
        print("%s", line)
    end
    return binary
end

function main(input, includes, out, ...)
    if not input or not includes or not out then
        raise("usage: ./xmakew l recompiler/tools/translate.lua INPUT INCLUDES OUT [GUEST-IMAGE ...]")
    end
    translate(input, includes, out, {...})
end
