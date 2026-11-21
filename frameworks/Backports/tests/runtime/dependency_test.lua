local driver = import("driver", {rootdir = os.scriptdir(), anonymous = true})

local function expect(name, condition)
    if not condition then
        raise("%s", name)
    end
end

local function compile(root, name, install, sources, libraries)
    local source = path.join(root, "src", name .. ".c")
    io.writefile(source, string.format("int %s_value(void) { return 1; }\n", name))
    local output = path.join(root, "out", name .. ".dylib")
    local arguments = {"clang", "-dynamiclib", "-o", output, "-install_name", install, source}
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

    os.tryrm(root)
end
