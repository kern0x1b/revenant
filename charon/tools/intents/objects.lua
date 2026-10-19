local GROUPS = {
    {"10_0_1", "10.0.1", "port"},
    {"10_3", "10.3", "port"},
    {"11_0", "11.0", "port"},
    {"12_0", "12.0", "newer"},
    {"13_4", "13.4", "port"},
    {"16_0", "16.0", "newer"},
    {"18_0", "18.0", "newer"},
}

local function append(list, items)
    for _, item in ipairs(items) do
        table.insert(list, item)
    end
end

local function sdk_version(sdk)
    return (path.basename(sdk):gsub("^iPhoneOS", ""):gsub("%.sdk$", ""))
end

local function ast_key(sdk, umbrella_text)
    local out = os.iorunv("/bin/sh", {"-c", "find \"$1/System/Library/Frameworks\" -name '*.h' | wc -l; find \"$1/System/Library/Frameworks\" -name '*.h' -print0 | xargs -0 stat -f '%m' | sort -rn | head -1", "sh", sdk})
    return sdk .. "|" .. out:gsub("%s+", " ") .. "|" .. umbrella_text
end

local function ast_dump(sdk, umbrella, umbrella_text, out_file)
    local key = ast_key(sdk, umbrella_text)
    local key_file = out_file .. ".key"
    if os.isfile(out_file) and os.isfile(key_file) and io.readfile(key_file) == key then
        print(string.format("    ast %s: reused", out_file))
        return
    end
    print(string.format("    ast %s: reading %s", out_file, sdk))
    os.runv("xcrun", {"clang", "-target", "arm64-apple-ios" .. sdk_version(sdk), "-isysroot", sdk, "-fsyntax-only", "-x", "objective-c",
        "-Wno-everything", "-Xclang", "-ast-dump=json", umbrella}, {stdout = out_file})
    io.writefile(key_file, key)
end

function main(...)
    local arguments = {...}
    local options = {}
    local index = 1
    while index <= #arguments do
        local key = arguments[index]:match("^%-%-(.+)$")
        if key == nil or arguments[index + 1] == nil then
            raise("usage: xmake l tools/intents/objects.lua --sdk <iPhoneOS 26.2 SDK> --out <dir> [--port-sdk <SDK>] [--work <dir>]")
        end
        options[key] = arguments[index + 1]
        index = index + 2
    end
    local root = path.absolute(path.join(os.scriptdir(), "..", ".."))
    local sdk_newer = options.sdk
    if sdk_newer == nil or not os.isdir(sdk_newer) then
        raise("--sdk names the iPhoneOS 26.2 SDK the surface is read from (CHARON_GEN_SDK in the build): %s", tostring(sdk_newer))
    end
    local sdk_port = options["port-sdk"]
    if sdk_port == nil then
        local found = os.dirs(path.join(os.getenv("HOME"), ".xmake", "packages", "i", "iphoneos-sdk", "*", "*", "Developer.app", "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))
        sdk_port = found[1]
    end
    if sdk_port == nil or not os.isdir(sdk_port) then
        raise("no port SDK: pass --port-sdk (the toolchain's iphoneos-sdk is not in the store)")
    end
    local out = options.out
    if out == nil then
        raise("--out names the folder the objects are written into")
    end
    local work = options.work or path.join(root, ".agent-work", "intents-generation")
    os.mkdir(out)
    os.mkdir(work)

    local umbrella = path.join(work, "umbrella.m")
    local umbrella_text = "#import <Intents/Intents.h>\n"
    io.writefile(umbrella, umbrella_text)
    local port_dump = path.join(work, "ast-port.json")
    local newer_dump = path.join(work, "ast-262.json")
    ast_dump(sdk_port, umbrella, umbrella_text, port_dump)
    ast_dump(sdk_newer, umbrella, umbrella_text, newer_dump)

    local here = os.scriptdir()
    local groups_dir = path.join(here, "groups")
    local carried = path.join(groups_dir, "intents-classes.txt")
    for _, group in ipairs(GROUPS) do
        local name, release, source = group[1], group[2], group[3]
        print("=== " .. name .. " (" .. release .. ")")
        local args = {"l", path.join(here, "gen-intents.lua"), "--sdk", sdk_port, "--dump", port_dump}
        if source == "newer" then
            append(args, {"--dump-newer", newer_dump})
        end
        append(args, {"--classes", path.join(groups_dir, name .. ".txt"), "--release", release, "--carried", carried,
            "--intents", carried, "--out", path.join(out, "IN" .. name .. ".m"), "--report", path.join(work, "report-" .. name .. ".json")})
        os.runv(os.programfile(), args)
    end
    print("objects: " .. #os.files(path.join(out, "IN*.m")) .. " files in " .. out)
end
