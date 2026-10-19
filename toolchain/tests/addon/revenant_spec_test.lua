function failures(opts)
    local found = {}
    local S = import("spec", {rootdir = opts.driver, anonymous = true})
    local spec_bind, spec_load, spec_substitute = S.spec_bind, S.spec_load, S.spec_substitute
    local spec_placeholders = S.spec_placeholders
    local decl_path, decl_using, decl_variant = S.decl_path, S.decl_using, S.decl_variant
    local decl_variants, decl_for_variant = S.decl_variants, S.decl_for_variant
    local decl_targets, decl_target, decl_generates = S.decl_targets, S.decl_target, S.decl_generates
    local decl_pipeline, decl_tiers, decl_tier = S.decl_pipeline, S.decl_tiers, S.decl_tier
    local decl_transport_binder, decl_conf_required = S.decl_transport_binder, S.decl_conf_required
    local decl_task, decl_require, decl_platform = S.decl_task, S.decl_require, S.decl_platform
    spec_bind(opts.driver)
    local function keys_of(map)
        return S.spec_toml().keys(map)
    end

    local function check(condition, message)
        if not condition then
            table.insert(found, message)
        end
    end

    local function refused(fn)
        local message = nil
        try { function () fn() end, catch { function (e) message = tostring(e) end } }
        return message
    end

    local counter = 0
    local function folder_with(files)
        counter = counter + 1
        local root = path.join(opts.scratch, "case-" .. counter)
        os.mkdir(root)
        for name, text in pairs(files) do
            local target = path.join(root, name)
            os.mkdir(path.directory(target))
            io.writefile(target, text)
        end
        return root
    end

    local function list_equal(got, want)
        if #got ~= #want then
            return false
        end
        for index = 1, #want do
            if got[index] ~= want[index] then
                return false
            end
        end
        return true
    end

    local MANIFEST = [==[
[port]
name = "example"
version = "1.0"

[paths]
tasks = "steps"

[use]
engine-toolchain = "cmake/mine.cmake"

[variants]
system = {}
prefixed = { options = ["prefixed=True"] }

[[static-library]]
name = "compat"
sources = ["compat/a.c"]

[[device-library]]
name = "tweak"
cmake = "platform"

[conf]
"user.example:thing" = "why this port needs it"

[tests]
transport = "tests/harness.py:bind"

[tests.scripts]
runs = ["tools/rule-test.py"]
needs = []

[tests.gate]
runs = ["tests/run.py:run_gate"]
needs = ["device"]

[tasks]
audit = "steps/audit.py --build {build}"

[pipeline]
system = ["task:audit", "build:engine"]
]==]

    local KNOWN = {build = "/port/build/system", sdk = "/sdks/iPhoneOS16.4.sdk"}

    do
        local root = folder_with({["revenant.toml"] = '[port]\nname = "p"\nversion = "1"\n'
                                  .. '[pipeline]\nsystem = ["build:device-library"]\n'})
        local declared = spec_load(root)
        local names = keys_of(decl_variants(declared))
        check(list_equal(names, {"system"}),
              "a manifest with one pipeline and no [variants] must build that pipeline as its variant: got " ..
              table.concat(names, ","))
        local two = folder_with({["revenant.toml"] = '[port]\nname = "p"\nversion = "1"\n[variants.a]\n'
                                 .. '[pipeline]\na = ["build:device-library"]\nb = ["build:device-library"]\n'})
        local listed = keys_of(decl_variants(spec_load(two)))
        check(list_equal(listed, {"a"}),
              "declared [variants] must not gain the pipeline names: got " .. table.concat(listed, ","))
    end

    do
        local root = folder_with({["revenant.toml"] = MANIFEST})
        local declared = spec_load(root)
        check(spec_load(path.join(root, "nowhere")) == nil, "a folder with no revenant.toml must read as no declaration")
        check(decl_path(declared, "tasks") == path.join(root, "steps"), "a declared path must win over the default")
        check(decl_path(declared, "build") == path.join(root, "build"), "an undeclared path must fall back to the convention")
        check(decl_path(declared, "profiles") == nil, "a path declared empty means Revenant generates it, so it reads as absent")
        check(refused(function () decl_path(declared, "nonsense") end) ~= nil, "an unknown path name must be refused")
        check(decl_using(declared, "engine-toolchain") == path.join(root, "cmake", "mine.cmake"),
              "an escape hatch must resolve against the port")
        check(decl_using(declared, "recipe") == nil, "an undeclared escape hatch must read as absent")

        check(spec_substitute("{sdk} and {build}", KNOWN) == "/sdks/iPhoneOS16.4.sdk and /port/build/system",
              "known names must resolve")
        check(spec_substitute("-I{include:libpsl} {lib:woff2:woff2dec}", KNOWN) == "-I{include:libpsl} {lib:woff2:woff2dec}",
              "graph names must survive for the recipe to resolve")
        check(refused(function () spec_substitute("-D{invented}", KNOWN) end) ~= nil,
              "an unknown name must be refused rather than emptied")
        check(refused(function () spec_substitute("{include:libpsl}", KNOWN, false) end) ~= nil,
              "a graph name must be refused where no graph exists")
        local placed = spec_placeholders("{a} {b:c} literal")
        check(list_equal(placed, {"a", "b:c"}), "placeholders must be reported by name")

        check(list_equal(keys_of(decl_variant(declared, "prefixed")), {"options"})
              and decl_variant(declared, "prefixed").options[1] == "prefixed=True",
              "a declared variant must come back as declared")
        check(refused(function () decl_variant(declared, "nope") end) ~= nil, "an undeclared variant must be refused")

        local compat = decl_targets(declared, "static-library")
        check(#compat == 1 and compat[1].name == "compat", "targets must be listed by kind")
        check(decl_generates(decl_target(declared, "static-library", "compat")),
              "a target without cmake= must be generated")
        check(not decl_generates(decl_target(declared, "device-library", "tweak")),
              "a target with cmake= must not be generated")
        check(refused(function () decl_target(declared, "device-library", "absent") end) ~= nil,
              "an undeclared target must be refused")

        local pipeline = decl_pipeline(declared, "system")
        check(list_equal(pipeline, {"task:audit", "build:engine"}), "a declared pipeline must come back as declared")
        check(refused(function () decl_pipeline(declared, "prefixed") end) ~= nil,
              "a variant with no pipeline must be refused rather than running nothing")

        local tiers = keys_of(decl_tiers(declared))
        table.sort(tiers)
        check(list_equal(tiers, {"gate", "scripts"}),
              "declared tiers must be listed, and the transport key must not read as one")
        check(list_equal(decl_tier(declared, "gate").needs, {"device"}), "a tier must come back with what it needs")
        check(decl_transport_binder(declared) == "tests/harness.py:bind",
              "the transport binder must be readable on its own")
        check(refused(function () decl_tier(declared, "nope") end) ~= nil, "an undeclared tier must be refused")

        local conf = decl_conf_required(declared)
        check(conf["user.example:thing"] == "why this port needs it",
              "a declared configuration key must come back with the reason the port gave")

        check(string.find(decl_task(declared, "audit"), "{build}", 1, true) ~= nil,
              "a task must come back with its placeholders intact")
        check(refused(function () decl_task(declared, "missing") end) ~= nil, "an undeclared task must be refused")
        check(refused(function () decl_require(declared, "port", "index") end) ~= nil,
              "a required key that is absent must be refused")
    end

    do
        local PLATFORMED = [==[
[port]
name = "example"
version = "1.0"

[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"
distribution = "jailbreak"

[target]
cpu = "cortex-a9"

[variants.armv7]

[variants.arm64.platform]
arch = "armv8"
os-version = "7.0"
]==]
        local root = folder_with({["revenant.toml"] = PLATFORMED})
        local declared = spec_load(root)
        local platform = decl_platform(declared)
        check(platform.os == "iOS" and platform.arch == "armv7" and platform["os-version"] == "6.0"
              and platform.sdk == "iphoneos", "a platform must answer os, arch, release and SDK")
        local tools = platform["tool-requires"]
        local has_ld64, has_sdk = false, false
        for _, reference in ipairs(tools) do
            if reference == "ld64/956.6@revenant/stable" then
                has_ld64 = true
            end
            if string.sub(reference, 1, #"iphoneos-sdk/") == "iphoneos-sdk/" then
                has_sdk = true
            end
        end
        check(has_ld64 and has_sdk, "armv7 on apple-ios must bring the SDK and ld64")
        local wide = decl_platform(decl_for_variant(declared, "arm64"))
        check(wide.arch == "armv8" and wide["os-version"] == "7.0" and wide.distribution == "jailbreak",
              "a variant's [platform] must override the keys it names and keep the rest")
        check((wide.distributed or {}).applications == "/Applications",
              "a platform must hand on what its chosen distribution says")
        local stray = false
        for _, reference in ipairs(wide["tool-requires"]) do
            if string.sub(reference, 1, #"ld64/") == "ld64/" then
                stray = true
            end
        end
        check(not stray, "an architecture's own tools must not reach another architecture")

        local REFUSED = {
            {"a platform nobody defines", 'use = "palm-os"', "neither the port nor Revenant defines"},
            {"an architecture the platform does not build", 'arch = "x86"', "which builds for"},
            {"a release older than the architecture allows", 'os-version = "5.1"', "starts at 6.0"},
            {"a distribution the platform does not know", 'distribution = "floppy"', "does not know"},
            {"a key Revenant does not read", 'flavour = "sweet"', "does not read"},
        }
        for _, case in ipairs(REFUSED) do
            local description, line, reason = case[1], case[2], case[3]
            local key = string.match(line, "^([^ ]+) =")
            local kept = {}
            local body = string.match(PLATFORMED, "^(.-)%[target%]")
            for row in string.gmatch(body, "[^\n]+") do
                if string.sub(row, 1, #key + 2) ~= key .. " =" then
                    table.insert(kept, row)
                end
            end
            table.insert(kept, line)
            local bad = folder_with({["revenant.toml"] = table.concat(kept, "\n") .. "\n"})
            local message = refused(function () decl_platform(spec_load(bad)) end)
            if message == nil then
                table.insert(found, description .. " must be refused")
            elseif string.find(message, reason, 1, true) == nil then
                table.insert(found, description .. " must be refused for that reason: " .. message)
            end
        end

        local repeated = folder_with({["revenant.toml"] = string.gsub(PLATFORMED, 'cpu = "cortex%-a9"',
                                                                    'arch = "armv7"')})
        local message = refused(function () decl_platform(spec_load(repeated)) end)
        if message == nil then
            table.insert(found, "[target] repeating what the platform says must be refused")
        elseif string.find(message, "one place", 1, true) == nil then
            table.insert(found, "a repeated key must be refused for that reason: " .. message)
        end

        local own = folder_with({
            ["revenant.toml"] = string.gsub(PLATFORMED, 'os%-version = "6.0"', 'os-version = "5.1"'),
            ["platforms/apple-ios.toml"] = 'os = "iOS"\n[distributions.jailbreak]\n[architectures.armv7]\n'
                                            .. 'os-version = { min = "5.0" }\n',
        })
        local overridden = refused(function () decl_platform(spec_load(own)) end)
        if overridden ~= nil then
            table.insert(found, "a port's own platform definition must be used before Revenant's: " .. overridden)
        elseif decl_platform(spec_load(own))["os-version"] ~= "5.1" then
            table.insert(found, "a port's own platforms/ must override Revenant's platform of the same name")
        end
    end

    do
        local VARIANTS = [==[
[port]
name = "example"
version = "1.0"

[target]
arch = "armv7"
os = "iOS"
os-version = "6.0"

[package]
control = "packaging/app/control"

[application]
name = "Host"
sources = ["app/main.m"]
strip = "-S -x"

[variants.armv7]

[variants.arm64.target]
arch = "armv8"
os-version = "7.0"

[variants.arm64.targets.Host]
exclude = ["app/Debug*.m"]

[variants.tweak.package]
control = "packaging/tweak/control"

[variants.broken.targets.Nobody]
strip = ""
]==]
        local root = folder_with({["revenant.toml"] = VARIANTS})
        local declared = spec_load(root)
        local arm64 = decl_for_variant(declared, "arm64")
        check(arm64.content.target.arch == "armv8" and arm64.content.target["os-version"] == "7.0",
              "a variant's [target] must override the port's")
        check(arm64.content.target.os == "iOS", "a key the variant leaves out must come from the port's [target]")
        local host = arm64.content.application
        check(list_equal(host.exclude, {"app/Debug*.m"}) and host.strip == "-S -x",
              "a variant's override of a target must merge into it, not replace it")
        check(arm64.content["for-variant"] == "arm64", "a declaration written for a variant must carry that variant's name")
        check(declared.content.target.arch == "armv7" and declared.content.application.exclude == nil,
              "writing a variant must not change the port's own declaration")
        check(decl_for_variant(declared, "tweak").content.package.control == "packaging/tweak/control",
              "a variant's [package] must replace the port's")
        check(refused(function () decl_for_variant(declared, "broken") end) ~= nil,
              "a variant overriding a target nothing declares must be refused")
    end

    return found
end
