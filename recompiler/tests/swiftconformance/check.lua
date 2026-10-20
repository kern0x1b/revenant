import("core.package.package")

local function swift_toolchain()
    local installs = os.dirs(path.join(package.installdir(), "s", "swift", "*", "*"))
    table.sort(installs)
    for _, install in ipairs(installs) do
        local layouts = path.join(install, "share", "swift-source", "stdlib", "toolchain", "legacy_layouts", "iphoneos", "layouts-arm64.yaml")
        if os.isfile(path.join(install, "bin", "swiftc")) and os.isfile(layouts) then
            return install, layouts
        end
    end
    raise("no revenant@swift install under %s carries its own legacy_layouts source cache (docs/reference/recompiler/corpus.md says why it is needed)", path.join(package.installdir(), "s", "swift"))
end

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("swiftconformance", out)
    local function o(file)
        return path.join(out, file)
    end
    local libs = os.getenv("XL_SWIFTCONFORMANCE_LIBS")
    if not libs or not os.isdir(libs) then
        raise("XL_SWIFTCONFORMANCE_LIBS must name the folder with libswiftCore.dylib, libc++.1.dylib and libc++abi.1.dylib the demo is translated with")
    end
    local swift, layouts = swift_toolchain()
    os.execv(path.join(swift, "bin", "swiftc"), {"-target", "arm64-apple-ios12.0", "-sdk", e.sdk, "-Xfrontend", "-read-legacy-type-info-path=" .. layouts,
                                                 "-runtime-compatibility-version", "none", "-o", o("fixture-arm64"), path.join(os.scriptdir(), "fixture.swift")})
    local includes = path.join(e.recompiler, "include", "swiftdemo-includes.h")
    local images = {path.join(libs, "libswiftCore.dylib"), path.join(libs, "libc++.1.dylib"), path.join(libs, "libc++abi.1.dylib")}
    local function run(input, folder, flags)
        translate.translate(input, includes, folder, images, {XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib"), XL_EXTRA_CFLAGS = flags})
    end
    run(o("fixture-arm64"), o("normal"), "")
    run(o("fixture-arm64"), o("control"), "-DXL_TEST_NO_DYLD_IMAGE_BRIDGE=1")

    local device = corpus.device()
    local function on_device(binary, name, log)
        device.copy(binary, "/var/tmp/" .. name)
        local output = try { function ()
            return device.run(string.format("chmod +x /var/tmp/%s && /var/tmp/%s; echo exit=$?; rm -f /var/tmp/%s", name, name, name))
        end } or ""
        io.writefile(log, output)
        return output
    end
    local normal = on_device(o("normal/fixture"), "xl-fixture-normal", o("run-normal.txt"))
    local control = on_device(o("control/fixture"), "xl-fixture-control", o("run-control.txt"))
    if not ("\n" .. normal):find("\nhashable\n", 1, true) then
        io.write(normal)
        corpus.fail("normal build (bridge active) did not find Widget's conformance")
    end
    if not ("\n" .. control):find("\nnot%-hashable\n") then
        io.write(control)
        corpus.fail("control (bridge compiled out) unexpectedly found the conformance anyway")
    end
    print("ok: conformance found with the bridge (hashable), not found without it (not-hashable)")

    if os.getenv("XL_SWIFTCONFORMANCE_ALSO_DEMO") == "1" then
        local demo = os.getenv("XL_SWIFTCONFORMANCE_DEMO")
        if not demo or not os.isfile(demo) then
            corpus.fail("XL_SWIFTCONFORMANCE_ALSO_DEMO=1 but XL_SWIFTCONFORMANCE_DEMO names no demo binary")
        end
        run(demo, o("demo-normal"), "")
        run(demo, o("demo-control"), "-DXL_TEST_NO_DYLD_IMAGE_BRIDGE=1")
        local name = path.basename(demo):gsub("%-arm64$", "")
        local demo_normal = on_device(o("demo-normal/" .. name), "xl-demo-normal", o("run-demo-normal.txt"))
        local demo_control = on_device(o("demo-control/" .. name), "xl-demo-control", o("run-demo-control.txt"))
        if not ("\n" .. demo_control):find("\nexit=139\n", 1, true) then
            io.write(demo_control)
            corpus.fail("demo control did not crash (exit 139) as expected")
        end
        if ("\n" .. demo_normal):find("\nexit=139\n", 1, true) then
            io.write(demo_normal)
            corpus.fail("demo normal build still crashed the same way")
        end
        print("ok: demo control still crashes (exit 139) without the bridge, normal build runs past it")
    end
end
