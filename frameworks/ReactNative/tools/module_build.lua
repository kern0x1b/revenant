local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/module_build.lua FOLDER CACHE EXTRA_MODULES
  Builds the isolated host FOLDER (made by isolate.lua copy) with the 25 base real modules plus EXTRA_MODULES (comma separated
  Expo packages whose recipes are in packages/; the add_deps of their recipes that are packages here join the list), under one budget claim for the whole build, so that the per-package probes
  and the nested configures do not each wait in the budget queue. It prints the budget state and elapsed seconds to stderr.
  The log of the build is FOLDER-build.log. Run it with run_in_background and a timeout of at most 1200000 (20 minutes).]]

local BASE = "expo-image-picker,expo-sqlite,expo-notifications,expo-haptics,expo-sharing,expo-audio,expo-clipboard,expo-font,expo-file-system,expo-document-picker,expo-image-manipulator,expo-image,expo-camera,expo-secure-store,expo-network,expo-device,expo-brightness,expo-linear-gradient,expo-store-review,expo-web-browser,expo-blur,expo-screen-orientation,expo-mail-composer,expo-sms,expo-print"

function recipe_deps(root, name)
    local file = path.join(root, "packages", name:sub(1, 1), name, "xmake.lua")
    local deps = {}
    if os.isfile(file) then
        for line in io.readfile(file):gmatch("[^\n]*add_deps%(([^)]*)%)") do
            for dep in line:gmatch('"([^"]+)"') do
                table.insert(deps, dep)
            end
        end
    end
    return deps
end

function closure(root, names)
    local result, seen = {}, {}
    local rows = {}
    for _, row in ipairs(import("core.base.json").decode(io.readfile(path.join(root, "frameworks", "ReactNative", "src", "coverage.json"))).rows or {}) do
        rows[row.id] = true
    end
    local function visit(name)
        if seen[name] then
            return
        end
        seen[name] = true
        table.insert(result, name)
        for _, dep in ipairs(recipe_deps(root, name)) do
            if rows[dep] then
                visit(dep)
            end
        end
    end
    for _, name in ipairs(names) do
        visit(name)
    end
    return result
end

function run(folder, cache, extra, execute)
    local root = os.curdir()
    local started = os.time()
    local function say(text)
        io.stderr:write(string.format("[+%ds] %s\n", os.time() - started, text))
    end
    local status = os.iorunv("./xmakew", {"l", "-P", ".", "tools/budget.lua", "status"}) or ""
    for _, key in ipairs({"capacity", "queued", "held"}) do
        say("budget " .. (status:match(key .. "[^\n]*") or key .. "?"))
    end
    local real = BASE .. (extra and extra ~= "" and ("," .. extra) or "")
    real = table.concat(closure(root, real:split(",")), ",")
    local envs = {
        REVENANT_CACHE = path.absolute(cache),
        REVENANT_PATH = root,
        REVENANT_PREBUILT = "kern0x1b/revenant",
        REVENANT_PREBUILT_ONLY = "llvm,swift,swift-runtime,ld64",
        RN_HERMES = "1",
    }
    say("build start")
    local status = execute("./xmakew", {"l", "-P", ".", "tools/budget.lua", "run", "--class", "normal", "--jobs", "4", "--min", "1", "--",
        "./xmakew", "l", "-P", ".", "frameworks/ReactNative/tools/isolate.lua", "build", path.absolute(folder),
        "--cache", path.absolute(cache), "--target", "RNHost", "--real", real, "--log", path.absolute(folder) .. "-build.log"},
        {envs = envs, try = true})
    say("build end, status " .. tostring(status))
    return status
end

function main(folder, cache, extra)
    if not folder or not cache then
        print(USAGE)
        os.exit(1)
    end
    local status = run(folder, cache, extra, os.execv)
    if status ~= 0 then
        os.exit(status)
    end
end
