local engine_location = "usr/lib/rev-fw"

local frameworks = {
    {built = "JavaScriptCore", as = "JavaScriptCore", compatibility = "1.0.0",
     replaces = "/System/Library/PrivateFrameworks/JavaScriptCore.framework/JavaScriptCore"},
    {built = "WebCore", as = "WebCore", compatibility = "1.0.0", resources = true,
     replaces = "/System/Library/PrivateFrameworks/WebCore.framework/WebCore",
     omit = {"WebCore", "Headers", "PrivateHeaders", "Modules", "_CodeSignature"},
     flatten = {{from = "modern-media-controls/images/iOS", into = "modern-media-controls/images", patterns = {"*.svg", "*.png"}}}},
    {built = "WebKitLegacy", as = "WebKit", compatibility = "1.0.0",
     replaces = "/System/Library/PrivateFrameworks/WebKit.framework/WebKit"}
}

local runtime = {{built = "libc++.1.0.dylib", renamed = "librev-c++.1.dylib"},
                 {built = "libc++abi.1.0.dylib", renamed = "librev-c++abi.1.dylib"}}

local plist_keys = {"MinimumOSVersion", "UIDeviceFamily", "CFBundleSupportedPlatforms"}

local function toolchain_module(name)
    return import("@addon.revenant." .. name, {anonymous = true})
end

local function otool(arguments, binary)
    return os.iorunv("xcrun", table.join({"otool"}, arguments, {binary}))
end

function compatibility_version(binary)
    local reading = false
    for line in otool({"-l"}, binary):gmatch("[^\n]+") do
        if line:find("cmd LC_ID_DYLIB", 1, true) then
            reading = true
        elseif reading then
            local found = line:match("compatibility version (%S+)")
            if found then
                return found
            end
            if line:find("Load command", 1, true) then
                return nil
            end
        end
    end
end

function retarget(identities, provided)
    local macho = toolchain_module("apple.macho")
    local names = table.copy(provided or {})
    for binary, identity in pairs(identities) do
        local image = macho.images(macho.read(binary))[1]
        if image.identity then
            names[path.filename(image.identity)] = identity
        end
        names[path.filename(identity)] = identity
    end
    for binary, identity in pairs(identities) do
        os.vrunv("xcrun", {"install_name_tool", "-id", identity, binary})
        for _, reference in ipairs(macho.images(macho.read(binary))[1].libraries) do
            local wanted = names[path.filename(reference)]
            if wanted and wanted ~= reference then
                os.vrunv("xcrun", {"install_name_tool", "-change", reference, wanted, binary})
            end
        end
    end
    local problems = {}
    for binary in pairs(identities) do
        for _, reference in ipairs(macho.images(macho.read(binary))[1].libraries) do
            if reference:startswith("@rpath/") then
                table.insert(problems, path.filename(binary) .. " still depends on " .. reference)
            end
        end
    end
    if #problems > 0 then
        raise("the staged engine would not load: %s", table.concat(problems, "; "))
    end
    return names
end

local function copy_resources(source, target, framework)
    local omitted = {}
    for _, name in ipairs(framework.omit or {}) do
        omitted[name] = true
    end
    for _, entry in ipairs(os.filedirs(path.join(source, "*"))) do
        local name = path.filename(entry)
        if name ~= framework.built and not omitted[name] then
            if name:endswith(".lproj") then
                for _, script in ipairs(os.files(path.join(entry, "*.js"))) do
                    os.vcp(script, path.join(target, name) .. "/")
                end
            elseif os.isdir(entry) then
                os.vcp(entry, target .. "/", {symlink = true})
            else
                os.vcp(entry, target .. "/")
            end
        end
    end
    for _, flatten in ipairs(framework.flatten or {}) do
        local origin = path.join(target, flatten.from)
        if os.isdir(origin) then
            for _, pattern in ipairs(flatten.patterns) do
                for _, file in ipairs(os.files(path.join(origin, "**", pattern))) do
                    os.vcp(file, path.join(target, flatten.into) .. "/")
                end
            end
        end
    end
end

local function finish(package, binaries)
    local macho = toolchain_module("apple.macho")
    local signing = toolchain_module("apple.signing")
    local ldid = path.join(package:dep("ldid"):installdir(), "bin", "ldid")
    for binary, framework in pairs(binaries) do
        if macho.encrypted(binary) then
            raise("%s carries LC_ENCRYPTION_INFO, which iOS 6 refuses in a library it loads", binary)
        end
        if framework then
            local found = compatibility_version(binary)
            if found ~= framework.compatibility then
                raise("%s declares compatibility version %s, and the system's clients of this framework recorded %s",
                      binary, tostring(found), framework.compatibility)
            end
            os.vrunv("xcrun", {"strip", "-S", "-x", binary})
        end
        signing.sign(ldid, binary)
    end
end

local function binary_plists(root)
    for _, plist in ipairs(os.files(path.join(root, "**.plist"))) do
        os.vrunv("plutil", {"-convert", "binary1", plist})
    end
end

function verify_plists(root, location)
    local problems, checked = {}, 0
    for _, framework in ipairs(frameworks) do
        if framework.resources then
            local plist = path.join(root, location, framework.as .. ".framework", "Info.plist")
            if not os.isfile(plist) then
                table.insert(problems, plist .. " is missing, and the engine opens this framework as a bundle")
            else
                checked = checked + 1
                local missing = {}
                for _, key in ipairs(table.join(plist_keys, {"CFBundleName"})) do
                    local value = try { function () return os.iorunv("plutil", {"-extract", key, "json", "-o", "-", plist}) end }
                    local text = value and value:trim() or ""
                    if text == "" or text == "\"\"" or text == "[]" then
                        table.insert(missing, key)
                    end
                end
                if #missing > 0 then
                    table.insert(problems, plist .. " lacks " .. table.concat(missing, ", ") .. ": it is the plist CMake generates, not the one the engine processes")
                end
            end
        end
    end
    if #problems > 0 then
        raise("staged framework plists missing or unprocessed:\n  %s", table.concat(problems, "\n  "))
    end
    return checked
end

local function libcxx_lib(package)
    return path.join(package:dep("libcxx"):installdir(), "lib")
end

function system(package, ctx)
    local root = path.join(package:installdir(), "stage")
    os.tryrm(root)
    local engine = path.join(root, engine_location)
    local identities, binaries = {}, {}
    for _, framework in ipairs(frameworks) do
        local destination = path.join(engine, framework.as .. ".framework", framework.as)
        os.mkdir(path.directory(destination))
        os.vcp(path.join(ctx.build, framework.built .. ".framework", framework.built), destination)
        identities[destination] = framework.replaces
        binaries[destination] = framework
        if framework.resources then
            copy_resources(path.join(ctx.build, framework.built .. ".framework"), path.directory(destination), framework)
        end
    end
    for _, library in ipairs(runtime) do
        local destination = path.join(root, "usr", "lib", library.renamed)
        os.mkdir(path.directory(destination))
        os.vcp(path.join(libcxx_lib(package), library.built), destination)
        identities[destination] = "/usr/lib/" .. library.renamed
        binaries[destination] = false
    end
    retarget(identities)
    finish(package, binaries)
    binary_plists(root)
    verify_plists(root, engine_location)
    batteries(package, ctx)
end

function batteries(package, ctx)
    local root = path.join(package:installdir(), "batteries")
    os.tryrm(root)
    local shell
    for _, candidate in ipairs({path.join(ctx.build, "jsc"), path.join(ctx.build, "bin", "jsc")}) do
        if os.isfile(candidate) then
            shell = candidate
        end
    end
    if not shell then
        raise("the engine build left no jsc shell, which the JavaScript batteries run under")
    end
    local frameworks = path.join(root, "Frameworks")
    local signed = {}
    local jsc = path.join(root, "jsc")
    os.mkdir(root)
    os.vcp(shell, jsc)
    signed[jsc] = false
    local core = path.join(frameworks, "JavaScriptCore.framework", "JavaScriptCore")
    os.mkdir(path.directory(core))
    os.vcp(path.join(ctx.build, "JavaScriptCore.framework", "JavaScriptCore"), core)
    signed[core] = false
    for _, library in ipairs(runtime) do
        local destination = path.join(frameworks, (library.built:gsub("%.1%.0%.dylib$", ".1.dylib")))
        os.vcp(path.join(libcxx_lib(package), library.built), destination)
        signed[destination] = false
    end
    finish(package, signed)
end

-- The frameworks a build carries: carried=jsc carries JavaScriptCore alone, the one a React Native host links.
local function carried(ctx)
    local found = {}
    for _, framework in ipairs(frameworks) do
        if ctx.carried == "all" or framework.built == "JavaScriptCore" then
            table.insert(found, framework)
        end
    end
    return found
end

function bundle(package, ctx)
    -- A copy of the frameworks as the build left them, for the org.revenant.webkit-engine deb:
    -- the bundle below names the build's own binaries in place, so the deb must take its copy first.
    local deb = path.join(package:installdir(), "deb")
    os.tryrm(deb)
    os.mkdir(deb)
    for _, framework in ipairs(carried(ctx)) do
        local copied = path.join(deb, framework.built .. ".framework")
        os.vcp(path.join(ctx.build, framework.built .. ".framework"), deb .. "/")
        for _, name in ipairs({"Headers", "PrivateHeaders", "Modules", "_CodeSignature"}) do
            os.tryrm(path.join(copied, name))
        end
    end
    local root = path.join(package:installdir(), "bundle")
    os.tryrm(root)
    local folder = path.join(root, "Frameworks")
    local identities, binaries = {}, {}
    for _, framework in ipairs(carried(ctx)) do
        local source = path.join(ctx.build, framework.built .. ".framework")
        local destination = path.join(folder, framework.built .. ".framework")
        os.vcp(source, folder .. "/", {symlink = true})
        for _, name in ipairs({"Headers", "PrivateHeaders", "Modules", "_CodeSignature"}) do
            os.tryrm(path.join(destination, name))
        end
        local binary = path.join(destination, framework.built)
        identities[binary] = "@executable_path/Frameworks/" .. framework.built .. ".framework/" .. framework.built
        binaries[binary] = framework
    end
    local macho = toolchain_module("apple.macho")
    local provided = {}
    for _, library in ipairs(runtime) do
        local identity = macho.images(macho.read(path.join(libcxx_lib(package), library.built)))[1].identity or library.built
        provided[path.filename(identity)] = "@executable_path/Frameworks/" .. path.filename(identity)
    end
    retarget(identities, provided)
    finish(package, binaries)
    local frameworks_dir = path.join(package:installdir(), "frameworks")
    os.tryrm(frameworks_dir)
    for _, framework in ipairs(carried(ctx)) do
        os.vcp(path.join(ctx.build, framework.built .. ".framework"), frameworks_dir .. "/", {symlink = true})
        -- A consumer links these, and the link records the install name in the binary: the build's own is the phone's
        -- framework, so the binary takes the bundle's, the name the application embeds it under.
        local binary = framework.built
        os.cp(path.join(root, "Frameworks", framework.built .. ".framework", binary), path.join(frameworks_dir, framework.built .. ".framework", binary))
    end
    local headers = package:installdir("include")
    for _, folder_name in ipairs({{"WebKitLegacy", "Headers"}, {"WTF", "Headers"}}) do
        local source = path.join(ctx.build, folder_name[1], folder_name[2])
        if os.isdir(source) then
            os.vcp(path.join(source, "*"), headers .. "/")
        end
    end
    local private = path.join(ctx.build, "WebCore.framework", "PrivateHeaders")
    if os.isdir(private) then
        os.vcp(private, path.join(package:installdir(), "webcore") .. "/")
    end
end
