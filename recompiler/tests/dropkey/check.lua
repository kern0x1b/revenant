local KEY_OLD = "6ebf749e424b403c9d2982e4f3f2397b"
local KEY_NEW = "ad218f8b8c2e41ee86a362a7de7d80b0"
local RECIPE_OLD = "bb6aae4e55cccd6832fe4548281c6675"
local RECIPE_NEW = "3e0039f19c12173d45d2c7690f7b6433"

local function raises(corpus, what, run, expected)
    local raised
    try {
        function ()
            run()
        end,
        catch {
            function (errors)
                raised = tostring(errors)
            end
        }
    }
    if not raised then
        corpus.fail("%s did not stop", what)
    end
    if not raised:find(expected, 1, true) then
        corpus.fail("%s stopped, but not with %s:\n%s", what, expected, raised)
    end
end

local function install(store, key, recipe, generation)
    local folder = path.join(store, "s", "swift-runtime", "6.4.0", key .. (generation or ""))
    os.mkdir(path.join(folder, "lib", "swift", "iphoneos"))
    io.writefile(path.join(folder, "manifest.txt"), string.format('{\n    configs = {\n        recipe = "%s"\n    }\n}\n', recipe))
    for _, name in ipairs({"libswiftCore", "libswiftFoundation"}) do
        io.writefile(path.join(folder, "lib", "swift", "iphoneos", name .. ".dylib"), name .. key)
    end
    return folder
end

local function dependent(store, name, key, against)
    local folder = path.join(store, "s", name, "5.0.1", key)
    os.mkdir(path.join(folder, "lib"))
    io.writefile(path.join(folder, "manifest.txt"), string.format('{\n    deps = {\n        ["swift-runtime"] = {\n            buildhash = "%s",\n            version = "6.4.0"\n        }\n    }\n}\n', against))
    io.writefile(path.join(folder, "lib", "libswiftCryptoKit.dylib"), "CryptoKit" .. key)
    return path.join(folder, "lib", "libswiftCryptoKit.dylib")
end

local function folder_of(out, name, links)
    local libs = path.join(out, name)
    os.tryrm(libs)
    os.mkdir(libs)
    for file, target in pairs(links) do
        os.execv("ln", {"-s", target, path.join(libs, file)})
    end
    return libs
end

function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local build = import("recaptcha_build", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local _
    _, out = corpus.setup("dropkey", out)
    out = path.absolute(out)
    local store = path.join(out, "store")
    os.tryrm(store)
    local old = install(store, KEY_OLD, RECIPE_OLD)
    local new = install(store, KEY_NEW, RECIPE_NEW, ".gda1de88d")
    local root = path.join(out, "root")
    os.tryrm(root)
    os.mkdir(path.join(root, "packages", "s", "swift-runtime", "port"))
    io.writefile(path.join(root, "packages", "s", "swift-runtime", "port", "digest.lua"), string.format('swift_runtime_sources_digest = "%s"\n', RECIPE_NEW))

    local function core(folder)
        return path.join(folder, "lib", "swift", "iphoneos", "libswiftCore.dylib")
    end
    local function foundation(folder)
        return path.join(folder, "lib", "swift", "iphoneos", "libswiftFoundation.dylib")
    end

    local stale = folder_of(out, "libs-stale", {["libswiftCore.dylib"] = core(old), ["libswiftFoundation.dylib"] = foundation(old)})
    raises(corpus, "a runtime of an older recipe", function () build.check_runtime(stale, root) end, "this checkout's recipe is " .. RECIPE_NEW)

    local current = folder_of(out, "libs-current", {["libswiftCore.dylib"] = core(new), ["libswiftFoundation.dylib"] = foundation(new)})
    local runtime = build.check_runtime(current, root)
    if runtime.key ~= KEY_NEW or runtime.recipe ~= RECIPE_NEW then
        corpus.fail("the runtime of the current recipe was read as %s, %s", tostring(runtime.key), tostring(runtime.recipe))
    end
    if runtime.core_sha256 ~= hash.sha256(core(new)) then
        corpus.fail("the digest of libswiftCore is %s, not that of the file", tostring(runtime.core_sha256))
    end

    local named = build.check_runtime(stale, root, KEY_OLD)
    if named.key ~= KEY_OLD then
        corpus.fail("the runtime named by key was read as %s", tostring(named.key))
    end
    raises(corpus, "a runtime that is not the key that was asked for", function () build.check_runtime(current, root, KEY_OLD) end, "not the key " .. KEY_OLD)

    local mixed = folder_of(out, "libs-mixed", {["libswiftCore.dylib"] = core(new), ["libswiftFoundation.dylib"] = foundation(old)})
    raises(corpus, "a folder with the libraries of two runtime installs", function () build.check_runtime(mixed, root) end, "comes from 2")

    local empty = folder_of(out, "libs-empty", {})
    raises(corpus, "a folder with no runtime library", function () build.check_runtime(empty, root) end, "comes from 0")

    local crypto_old = dependent(store, "swift-crypto", "aaaa0000aaaa0000aaaa0000aaaa0000", KEY_OLD)
    local crypto_new = dependent(store, "swift-crypto", "bbbb0000bbbb0000bbbb0000bbbb0000", KEY_NEW)
    local with_old_crypto = folder_of(out, "libs-crypto-old", {["libswiftCore.dylib"] = core(new), ["libswiftCryptoKit.dylib"] = crypto_old})
    raises(corpus, "a CryptoKit built against another runtime", function () build.check_runtime(with_old_crypto, root) end, "was built against the Swift runtime " .. KEY_OLD)
    local with_new_crypto = folder_of(out, "libs-crypto-new", {["libswiftCore.dylib"] = core(new), ["libswiftCryptoKit.dylib"] = crypto_new})
    build.check_runtime(with_new_crypto, root)

    local library = path.join(out, "library.bin")
    io.writefile(library, "\0prefix\0revenant_swift_runtime_" .. KEY_NEW .. "\0suffix")
    build.check_artifact_runtime(library, KEY_NEW)
    raises(corpus, "a library that carries another runtime's mark", function () build.check_artifact_runtime(library, KEY_OLD) end, "carries the Swift runtime marks [" .. KEY_NEW .. "]")
    io.writefile(library, "revenant_swift_runtime_" .. KEY_NEW .. "\0revenant_swift_runtime_" .. KEY_OLD .. "\0")
    raises(corpus, "a library that carries the marks of two runtimes", function () build.check_artifact_runtime(library, KEY_NEW) end, "carries the Swift runtime marks")
    io.writefile(library, "no mark here")
    raises(corpus, "a library that carries no mark", function () build.check_artifact_runtime(library, KEY_NEW) end, "carries the Swift runtime marks []")
    print("dropkey: the runtime of a drop is the install of the current recipe or the named key, and nothing else")
end
