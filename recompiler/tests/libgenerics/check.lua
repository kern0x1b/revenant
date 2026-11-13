local STEPS = {
    {"stepDictionary", {"dictionary.string"}},
}

function main(out, ...)
    local host_only, device_only = false, false
    for _, argument in ipairs({...}) do
        if type(argument) == "table" then
            host_only = argument.host_only or host_only
            device_only = argument.device_only or device_only
        elseif argument == "--host-only" then
            host_only = true
        elseif argument == "--device-only" then
            device_only = true
        end
    end
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("libgenerics", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local libraries = o("xl/LibGenerics.dylib")

    if not device_only then
        local libs = os.getenv("XL_SWIFTOBJC_LIBS")
        if not libs or not os.isdir(libs) then
            raise("XL_SWIFTOBJC_LIBS must name the folder with libswiftCore.dylib (the arm64 runtime of revenant@swift-runtime), libc++.1.dylib and libc++abi.1.dylib the fixture is translated with")
        end
        local swift, layouts = corpus.swift()
        os.execv(path.join(swift, "bin", "swiftc"), {"-target", "arm64-apple-ios12.0", "-sdk", e.sdk, "-Xfrontend", "-read-legacy-type-info-path=" .. layouts,
                                                     "-runtime-compatibility-version", "none", "-emit-library", "-module-name", "LibGenerics",
                                                     "-Xlinker", "-install_name", "-Xlinker", "@rpath/LibGenerics.dylib", "-o", o("LibGenerics.dylib"),
                                                     path.join(here, "fixture.swift")})
        local includes = path.join(e.recompiler, "include", "swiftdemo-includes.h")
        local images = {path.join(libs, "libswiftCore.dylib"), path.join(libs, "libc++.1.dylib"), path.join(libs, "libc++abi.1.dylib")}
        translate.translate(o("LibGenerics.dylib"), includes, o("xl"), images,
                            {XL_LIBRARY = "1", XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib"), XL_SWIFT_HOST_ANCESTORS = "1"})
        if not os.isfile(libraries) or not os.isfile(o("xl/LibGenerics-classes.dylib")) then
            corpus.fail("the library or its registry was not built")
        end
        local flags = {"-O2", "-w", "-fobjc-arc", "-I", path.join(e.recompiler, "include"), "-framework", "Foundation", "-framework", "UIKit"}
        corpus.armv7(e, table.join(flags, {path.join(here, "host.m"), path.join(e.recompiler, "src", "loader", "xl_loader.c"), "-o", o("host")}))
        corpus.sign(e, o("host"))
        if host_only then
            print("ok (host part)")
            return
        end
    elseif not os.isfile(libraries) then
        raise("--device-only needs the translated library %s of an earlier --host-only run", libraries)
    end

    local device = corpus.device()
    local remote = "/var/tmp/xl-libgenerics"
    device.run("rm -rf " .. remote .. " && mkdir -p " .. remote)
    device.copy(libraries, remote .. "/LibGenerics.dylib")
    device.copy(o("xl/LibGenerics-classes.dylib"), remote .. "/LibGenerics-classes.dylib")
    device.copy(o("host"), remote .. "/host")
    local log = {}
    for _, step in ipairs(STEPS) do
        local output = try { function ()
            return device.run("chmod +x " .. remote .. "/host && cd " .. remote .. " && MallocScribble=1 MallocGuardEdges=1 DYLD_FALLBACK_LIBRARY_PATH=" .. remote ..
                              " ./host " .. remote .. "/LibGenerics.dylib LibGenerics " .. step[1] .. " 2>&1; echo exit=$?")
        end } or ""
        table.insert(log, output)
        local text = "\n" .. output:gsub("\r", "")
        for _, name in ipairs(step[2]) do
            if not text:find("\nok " .. name .. "\n", 1, true) then
                io.write(output)
                corpus.fail("%s: the library did not report ok for %s", step[1], name)
            end
        end
        if text:find("\nFAIL ", 1, true) or text:find("malloc: ***", 1, true) or not text:find("\ndone\nexit=0\n", 1, true) then
            io.write(output)
            corpus.fail("%s: the library reported a failure, the heap was corrupted, or the process did not run to its end", step[1])
        end
    end
    device.run("rm -rf " .. remote)
    io.writefile(o("run.txt"), table.concat(log, "\n"))
    print("ok: %d steps ran in a translated library", #STEPS)
end
