local driver = import("driver", {rootdir = os.scriptdir(), anonymous = true})

local function expect(name, condition)
    if not condition then
        raise("%s", name)
    end
end

local function compile(root, name, install, sources, libraries, flags)
    local source = path.join(root, "src", name .. ".c")
    io.writefile(source, string.format("int %s_value(void) { return 1; }\n", name))
    local output = path.join(root, "out", name .. ".dylib")
    local arguments = {"clang", "-dynamiclib", "-o", output, "-install_name", install, source}
    for _, flag in ipairs(flags or {}) do
        table.insert(arguments, flag)
    end
    for _, library in ipairs(libraries or {}) do
        table.insert(arguments, library)
    end
    os.vrunv("xcrun", arguments)
    return output
end

function main()
    local root = path.join(import("@addon.revenant.workspace", {anonymous = true}).scratch(), "runtime-dependency-test")
    os.tryrm(root)
    os.mkdir(path.join(root, "src"))
    os.mkdir(path.join(root, "out"))
    local packages = path.join(root, "packages")
    local folder = path.join(packages, "f", "fakepkg", "1.0", "abcd1234ef56.g1", "lib")
    os.mkdir(folder)

    local base = compile(root, "base", "/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libbase.1.dylib")
    local middle = compile(root, "middle", "/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libmiddle.1.dylib", nil, {base})
    os.cp(base, path.join(folder, "libbase.1.dylib"))
    os.cp(middle, path.join(folder, "libmiddle.1.dylib"))
    local backports = compile(root, "user", "/usr/lib/revenant/org.revenant.backports/libUserBackports.dylib", nil, {middle})
    local plain = compile(root, "plain", "/usr/lib/revenant/org.revenant.backports/libPlainBackports.dylib")

    local closure = driver.dependency_closure({backports}, packages)
    local names = {}
    for _, dependency in ipairs(closure) do
        table.insert(names, dependency.name)
    end
    expect("a library that needs a package library, which needs another, gets both: " .. table.concat(names, ","),
           table.concat(names, ",") == "/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libbase.1.dylib,/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libmiddle.1.dylib")
    for _, dependency in ipairs(closure) do
        expect("each dependency comes from the package folder: " .. dependency.source,
               path.directory(dependency.source) == folder)
    end
    expect("a library with no package dependency has an empty closure", #driver.dependency_closure({plain}, packages) == 0)
    expect("the closure of two libraries counts each dependency once", #driver.dependency_closure({backports, backports}, packages) == 2)

    os.rm(path.join(folder, "libbase.1.dylib"))
    local failure
    try {
        function ()
            driver.dependency_closure({backports}, packages)
        end,
        catch {
            function (raised)
                failure = tostring(raised)
            end
        }
    }
    expect("a dependency that no installed package holds is an error, not a silent skip", failure ~= nil)
    expect("the error names the missing library: " .. tostring(failure), failure:find("libbase.1.dylib", 1, true) ~= nil)

    local first = compile(root, "cyclefirst", "/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libcyclefirst.1.dylib")
    local second = compile(root, "cyclesecond", "/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libcyclesecond.1.dylib", nil, {first})
    local closing = compile(root, "cyclefirst2", "/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libcyclefirst.1.dylib", nil, {second})
    os.cp(closing, path.join(folder, "libcyclefirst.1.dylib"))
    os.cp(second, path.join(folder, "libcyclesecond.1.dylib"))
    local entering = compile(root, "entering", "/usr/lib/revenant/org.revenant.backports/libEnteringBackports.dylib", nil, {closing})
    local cycle = driver.dependency_closure({entering}, packages)
    names = {}
    for _, dependency in ipairs(cycle) do
        table.insert(names, dependency.name)
    end
    expect("two package libraries that need each other end the walk and are listed once each: " .. table.concat(names, ","),
           table.concat(names, ",") == "/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libcyclefirst.1.dylib,/usr/lib/revenant/org.revenant.fakepkg-abcd1234/libcyclesecond.1.dylib")

    local relative = compile(root, "relativelib", "@rpath/librelative.dylib")
    local loader = compile(root, "loaderlib", "@loader_path/libloader.dylib")
    local executable = compile(root, "executablelib", "@executable_path/libexecutable.dylib")
    for _, case in ipairs({{relative, "@rpath/librelative.dylib"}, {loader, "@loader_path/libloader.dylib"}, {executable, "@executable_path/libexecutable.dylib"}}) do
        local user = compile(root, "user" .. path.basename(case[1]), "/usr/lib/revenant/org.revenant.backports/lib" .. path.basename(case[1]) .. "Backports.dylib", nil, {case[1]}, {"-Wl,-not_for_dyld_shared_cache"})
        local refusal
        try {
            function ()
                driver.dependency_closure({user}, packages)
            end,
            catch {
                function (raised)
                    refusal = tostring(raised)
                end
            }
        }
        expect("a dependency by " .. case[2] .. " is an error, not a silent skip", refusal ~= nil)
        expect("the error names " .. case[2] .. ": " .. tostring(refusal), refusal:find(case[2], 1, true) ~= nil)
    end

    local own = compile(root, "ownrpath", "@rpath/libownrpath.dylib", nil, nil, {"-Wl,-not_for_dyld_shared_cache"})
    expect("a library whose own install name is @rpath, and which links nothing relative, is not refused", #driver.dependency_closure({own}, packages) == 0)

    os.tryrm(root)
end
