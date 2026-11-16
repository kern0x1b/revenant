local EXPECTED = {
    "client.bump", "client.make", "client.block", "client.dyncast", "client.sametype", "objc.responds", "objc.perform", "objc.kind",
    "objc.hash", "sub.vtable", "sub.dispatch", "sub.dyncast", "sub.superclass", "ivars.released", "ivars.released.sub",
    "host.create", "host.dispatch", "host.subtype", "host.init", "name.plain", "name.client",
    "anycollection.int", "anycollection.string", "mirror.children", "describe.struct", "describe.class"
}

local function check_error_bridge(corpus, libs)
    local core = path.join(libs, "libswiftCore.dylib")
    local text = os.iorunv("otool", {"-arch", "arm64", "-tV", core})
    local _, label = text:find("\n__swift_stdlib_bridgeErrorToNSError:\n", 1, true)
    if not label then
        corpus.fail("%s has no _swift_stdlib_bridgeErrorToNSError", core)
    end
    local class_line, read_line
    local index = 0
    for line in text:sub(label + 1, label + 20000):gmatch("[^\n]+") do
        index = index + 1
        if line:match("^%S+:$") then
            break
        end
        if not class_line and line:find("_swift_getClass", 1, true) then
            class_line = index
        end
        if not read_line and line:match("\tldar\t") then
            read_line = index
        end
    end
    if not class_line or not read_line or class_line > read_line then
        corpus.fail("_swift_stdlib_bridgeErrorToNSError of %s reads an error's domain through the layout of the Swift error box before it asks whether the object is a real NSError (the class at instruction %s, the first load-acquire at %s)", core, tostring(class_line), tostring(read_line))
    end
end

local IMAGES = {"libswiftCore", "libc++.1", "libc++abi.1"}

local BRIDGED_WRAPPERS = {"CFDictionaryGetCount", "CFDictionaryContainsKey", "CFDictionaryGetValue", "CFArrayGetCount", "CFDataGetLength", "CFStringGetLength"}

function main(out, ...)
    local host_only, device_only = false, false
    for _, argument in ipairs({...}) do
        if type(argument) == "table" then
            host_only = argument.host_only or host_only
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
    e, out = corpus.setup("swiftobjc", out)
    local libs = os.getenv("XL_SWIFTOBJC_LIBS")
    if not device_only and (not libs or not os.isdir(libs)) then
        raise("XL_SWIFTOBJC_LIBS must name the folder with libswiftCore.dylib (the arm64 runtime of revenant@swift-runtime), libc++.1.dylib and libc++abi.1.dylib the fixture is translated with")
    end
    if not device_only then
        local swift, layouts = corpus.swift()
        os.execv(path.join(swift, "bin", "swiftc"), {"-target", "arm64-apple-ios12.0", "-sdk", e.sdk, "-Xfrontend", "-read-legacy-type-info-path=" .. layouts,
                                                     "-runtime-compatibility-version", "none", "-o", path.join(out, "fixture-arm64"), path.join(os.scriptdir(), "fixture.swift")})
        check_error_bridge(corpus, libs)
        local includes = path.join(e.recompiler, "include", "swiftdemo-includes.h")
        local images = {}
        for _, name in ipairs(IMAGES) do
            table.insert(images, path.join(libs, name .. ".dylib"))
        end
        translate.translate(path.join(out, "fixture-arm64"), includes, path.join(out, "xl"), images,
                            {XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib"), XL_SWIFT_HOST_ANCESTORS = "1"})
        local host_source = io.readfile(path.join(out, "xl", "host.m"))
        for _, name in ipairs(BRIDGED_WRAPPERS) do
            local wrapper = host_source:match("void xl_h_" .. name .. "%b()%s*(%b{})")
            if not wrapper then
                corpus.fail("the translation has no host wrapper for %s, so the check of a Swift object passed to Core Foundation proves nothing", name)
            end
            if not wrapper:find("xl_object_in", 1, true) then
                corpus.fail("the host wrapper of %s does not take its object argument through xl_object_in, so a Swift object of a guest class would reach Core Foundation as a raw guest pointer", name)
            end
        end
        local _, owned = host_source:gsub("xl_object_in_owned%(", "")
        local expected_owned, listed = 0, {}
        for line in io.readfile(path.join(out, "xl", "report.txt")):gmatch("[^\n]+") do
            local class, selector, result = line:match("^[-+]%[(%S+) (%S+)%]: host IMP from .* as (.)")
            if selector then
                local name = selector:gsub("^_+", "")
                local family = name:match("^alloc") or name:match("^new") or name:match("^copy") or name:match("^mutableCopy")
                if family and not name:sub(#family + 1, #family + 1):match("%l") and result == "@" then
                    expected_owned = expected_owned + 1
                    listed[class .. " " .. selector] = true
                end
            end
        end
        if not listed["FixtureClient copyMade:"] or not listed["FixtureClient newToken:"] or listed["FixtureClient make:"] then
            corpus.fail("the report does not list the host IMPs of copyMade: and newToken: of FixtureClient as owned results, or lists make: as one")
        end
        if owned ~= expected_owned then
            corpus.fail("the translation has %d host wrappers that take the result of the guest as owned, the report lists %d selectors of the alloc, new, copy and mutableCopy families with an object result, so one of them hands a result to the host at the wrong count", owned, expected_owned)
        end
        if host_only then
            print("ok (host part)")
            return
        end
    elseif not os.isfile(path.join(out, "xl", "fixture")) then
        raise("--device-only needs the translated fixture %s of an earlier --host-only run", path.join(out, "xl", "fixture"))
    end

    local device = corpus.device()
    local remote = device.scratch .. "/xl-fixture-swiftobjc"
    device.copy(path.join(out, "xl", "fixture"), remote)
    local output = try { function ()
        return device.run(string.format("chmod +x %s && %s; echo exit=$?; rm -f %s", remote, remote, remote))
    end } or ""
    io.writefile(path.join(out, "run.txt"), output)
    local text = "\n" .. output:gsub("\r", "")
    for _, name in ipairs(EXPECTED) do
        if not text:find("\nok " .. name .. "\n", 1, true) then
            io.write(output)
            corpus.fail("the fixture did not report ok for %s", name)
        end
    end
    if text:find("\nFAIL ", 1, true) then
        io.write(output)
        corpus.fail("the fixture reported a failure")
    end
    if not text:find("\ndeinit Token 9\n", 1, true) then
        io.write(output)
        corpus.fail("the Swift deinit of a Token (reached through the host's dealloc) did not run")
    end
    if not text:find("\ndone\nexit=0\n", 1, true) then
        io.write(output)
        corpus.fail("the fixture did not run to its end with exit 0")
    end
    print("ok: Swift classes with an NSObject ancestor construct, dispatch, subclass and deinit (%d checks)", #EXPECTED)
end
