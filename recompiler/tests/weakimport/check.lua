function main(out, opt)
    opt = type(opt) == "table" and opt or {}
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local macho = import("macho", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("weakimport", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local function cc(argv)
        corpus.ios(e, table.join({"-O2", "-w"}, argv))
    end

    cc({"-dynamiclib", "-install_name", "@rpath/libweaklib.dylib", path.join(here, "weaklib.c"), "-o", o("libweaklib.dylib")})
    cc({path.join(here, "strong.c"), o("libweaklib.dylib"), "-o", o("strong")})
    cc({path.join(here, "weakonly.c"), o("libweaklib.dylib"), "-o", o("weakonly")})
    macho.unbind(o("strong"), o("strong-unbound"))
    macho.unbind(o("libweaklib.dylib"), o("libweaklib-unbound.dylib"))
    io.writefile(o("passthrough.txt"), "")
    local function lift(name, library)
        return corpus.run(e.xlate, {"--base", "0x10000000", "--output", o(name .. ".bc"), "--layout", o(name .. ".layout"), "--passthrough", o("passthrough.txt"),
                                    "--state-header", o(name .. ".h"), o(name), o(library or "libweaklib.dylib")}, o(name .. ".err"))
    end
    local ok, log = lift("strong")
    if ok then
        corpus.fail("strong's call stub to getppid passed because libweaklib imports it weakly")
    end
    if not log:find("strong: call stub for unresolved import _getppid", 1, true) then
        io.write(log)
        corpus.fail("strong was refused for another reason")
    end
    if log:find("libweaklib.dylib: call stub", 1, true) then
        corpus.fail("libweaklib's weak stub was refused")
    end
    ok, log = lift("strong-unbound")
    if ok then
        corpus.fail("a strong stub with no bind entry passed because libweaklib imports getppid weakly")
    end
    if not log:find("strong-unbound: call stub for unresolved import _getppid", 1, true) then
        io.write(log)
        corpus.fail("strong-unbound was refused for another reason")
    end
    ok, log = lift("weakonly", "libweaklib-unbound.dylib")
    if not ok then
        io.write(log)
        corpus.fail("a weak stub with no bind entry was refused")
    end
    ok, log = lift("weakonly")
    if not ok then
        io.write(log)
        corpus.fail("a call stub that only libweaklib makes, weakly, was refused")
    end
    if opt.host_only then
        print("ok (host part)")
        return
    end

    cc({path.join(here, "main.c"), "-o", o("WeakImport-arm64")})
    os.cp(path.join(e.recompiler, "p3", "includes.h"), o("includes.h"))
    translate.translate(o("WeakImport-arm64"), o("includes.h"), o("xl"))
    os.execv("xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-isysroot", e.sdk, "-fuse-ld=" .. e.ld, "-Wl,-no_pie", "-O2", "-w",
                       path.join(here, "main.c"), "-o", o("WeakImportNative")})
    os.execv(e.ldid, {"-S", o("WeakImportNative")})
    local device = corpus.device()
    device.copy(o("xl/WeakImport"), "/var/tmp/WeakImport")
    device.copy(o("WeakImportNative"), "/var/tmp/WeakImportNative")
    io.writefile(o("run-native.txt"), device.run("chmod +x /var/tmp/WeakImportNative && /var/tmp/WeakImportNative; rm -f /var/tmp/WeakImportNative"))
    io.writefile(o("run.txt"), device.run("chmod +x /var/tmp/WeakImport && /var/tmp/WeakImport; rm -f /var/tmp/WeakImport"))
    corpus.same(path.join(here, "..", "data", "weakimport", "expected.txt"), o("run-native.txt"), "iOS 6 itself printed something else than expected.txt")
    corpus.same(path.join(here, "..", "data", "weakimport", "expected.txt"), o("run.txt"), "the translated program printed something else than iOS 6 does")
    print("ok")
end
