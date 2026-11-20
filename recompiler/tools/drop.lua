local LOADER_FILES = {"src/loader/xl_loader.c", "include/xl_loader.h", "include/xl_guest_image.h", "include/xl_vm_map.h"}
local HELPER_FILES = {"tests/recaptchahelper/helper.m", "tests/recaptchahelper/protocol.h"}
local PRODUCT_FILES = {"proxy-classes.txt", "report.txt", "system-classes.txt"}

function main(name, ...)
    local scripts = os.scriptdir()
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local build = import("recaptcha_build", {rootdir = scripts, anonymous = true})
    local arguments = {...}
    local destination, verify, runtime_key = nil, true, nil
    for index, argument in ipairs(arguments) do
        if argument == "--out" then
            destination = arguments[index + 1]
        elseif argument == "--no-verify" then
            verify = false
        elseif argument == "--runtime-key" then
            runtime_key = arguments[index + 1]
        end
    end
    if not name or name == "" then
        raise("usage: drop.lua NAME [--out DIR] [--no-verify] [--runtime-key BUILDHASH]")
    end
    local sdk = build.sdk_file()
    if not sdk then
        raise("no SDK: set XL_RECAPTCHA_SDK or put RecaptchaEnterprise.dylib in telegram-build/.agent-work/recaptcha-sdk beside this checkout")
    end
    local libs = build.libraries_folder()
    if not libs then
        raise("XL_SWIFTOBJC_LIBS must name the folder with the arm64 Swift runtime libraries, libc++.1.dylib and libc++abi.1.dylib")
    end
    if not os.getenv("BACKPORTS_DIR") or os.getenv("BACKPORTS_DIR") == "" then
        raise("BACKPORTS_DIR must name the folder with the lib*Backports.dylib the library links against")
    end
    local runtime = build.check_runtime(libs, path.absolute(path.join(scripts, "..", "..")), runtime_key)
    local telegram = build.telegram_build()
    destination = destination or (telegram and path.join(telegram, ".agent-work", "recaptcha-real", name))
    if not destination then
        raise("no destination: pass --out DIR, or place this checkout beside telegram-build")
    end
    local started = os.time()
    local function step(text)
        print("drop: %s (%d s)", text, os.time() - started)
    end
    step("build xlate and xlgen")
    os.execv("nice", {"-n", "15", "./xmakew", "build", "-P", ".", "-r", "xlate", "xlgen"}, {curdir = path.directory(path.directory(scripts))})
    local e, out = corpus.setup("recaptcha-" .. name)
    step("translate")
    local xl = build.translate_sdk(e, out, sdk, libs)
    local library = path.join(xl, "RecaptchaEnterprise.dylib")
    local registry = path.join(xl, "RecaptchaEnterprise-classes.dylib")
    if not os.isfile(library) or not os.isfile(registry) then
        raise("the translation left no %s or %s", library, registry)
    end
    build.check_artifact_runtime(library, runtime.key)
    local leftover = {}
    for line in os.iorunv("nm", {"-u", library}):gmatch("[^\r\n]+") do
        local symbol = line:match("^%s*(_xl_%S+)")
        if symbol then
            table.insert(leftover, symbol)
        end
    end
    if #leftover > 0 then
        raise("%s imports the runtime's own symbols, which nothing in the application defines: %s", library, table.concat(leftover, " "))
    end
    os.tryrm(destination)
    os.mkdir(destination)
    for _, file in ipairs({"RecaptchaEnterprise.dylib", "RecaptchaEnterprise-classes.dylib"}) do
        os.cp(path.join(xl, file), path.join(destination, file))
    end
    for _, file in ipairs(PRODUCT_FILES) do
        if os.isfile(path.join(xl, file)) then
            os.cp(path.join(xl, file), path.join(destination, file))
        end
    end
    for _, relative in ipairs(LOADER_FILES) do
        local source = path.join(e.recompiler, relative)
        if os.isfile(source) then
            os.cp(source, path.join(destination, path.filename(relative)))
        end
    end
    local helper = {}
    for _, relative in ipairs(HELPER_FILES) do
        local source, leaf = path.join(e.recompiler, relative), path.filename(relative)
        if not os.isfile(source) then
            raise("the helper's source %s is missing", source)
        end
        os.cp(source, path.join(destination, leaf))
        table.insert(helper, string.format("%s_sha256=%s", (leaf:gsub("%.", "_")), hash.sha256(path.join(destination, leaf))))
    end
    local protocol = io.readfile(path.join(destination, "protocol.h")):match('#define RC_VERSION "(%d+)"')
    if not protocol then
        raise("protocol.h does not define RC_VERSION as a number in quotes")
    end
    io.writefile(path.join(destination, "helper.txt"), string.format("protocol_version=%s\n%s\n", protocol, table.concat(helper, "\n")))
    local sha, registry_sha = hash.sha256(path.join(destination, "RecaptchaEnterprise.dylib")), hash.sha256(path.join(destination, "RecaptchaEnterprise-classes.dylib"))
    io.writefile(path.join(destination, "runtime.txt"), string.format("runtime_key=%s\nruntime_recipe=%s\nlibswiftcore_sha256=%s\n", runtime.key, tostring(runtime.recipe), runtime.core_sha256))
    local checkout = path.absolute(path.join(scripts, "..", ".."))
    local commit = os.iorunv("git", {"-C", checkout, "rev-parse", "HEAD"}):trim()
    local changed = os.iorunv("git", {"-C", checkout, "status", "--porcelain", "--untracked-files=no"}):trim()
    io.writefile(path.join(destination, "source.txt"), string.format("commit=%s\nuncommitted_changes=%s\n", commit, changed == "" and "none" or "yes"))
    local entry = path.join(destination, "recaptcha-sdk.txt")
    io.writefile(entry, string.format("dir=%s\nlibrary=RecaptchaEnterprise.dylib\nsha256=%s\nregistry_sha256=%s\nbase=0x%x\ninstall=Frameworks/RecaptchaEnterprise.dylib\n",
                                      destination, sha, registry_sha, build.guest_base()))
    if verify and telegram and os.isfile(path.join(telegram, "tools", "recaptcha_sdk.lua")) then
        local sdk_module = import("recaptcha_sdk", {rootdir = path.join(telegram, "tools"), anonymous = true})
        sdk_module.verify(sdk_module.read(entry))
        print("drop verified: %s", entry)
    end
    step("ready")
    print("drop: %s", destination)
    print("sha256: %s", sha)
    print("registry_sha256: %s", registry_sha)
end
