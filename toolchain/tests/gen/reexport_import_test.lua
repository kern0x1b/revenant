local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "reexport-import-test")

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"))
    handle:write(text)
    handle:close()
end

local function row(framework, kind, usr, name, header, typ, params)
    local out = {framework, kind, usr, "-", name, "-", header, "1", "ios=13.0/-/-/0", "-", typ, params}
    for column = 13, 21 do
        out[column] = "-"
    end
    return out
end

local function run()
    local cmd = import("gen.cmd_headers", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    os.rm(SCRATCH)
    local sdk = path.join(SCRATCH, "sdk")
    local frameworks = path.join(sdk, "System", "Library", "Frameworks")
    write(path.join(frameworks, "FixPublic.framework", "Headers", "FixPublic.h"),
          "#pragma clang system_header\n#import <_FixPrivate/FixPrivate.h>\n")
    write(path.join(frameworks, "_FixPrivate.framework", "Headers", "FixPrivate.h"), "#pragma clang system_header\n")
    write(path.join(frameworks, "_FixPrivate.framework", "Headers", "FixPrivateTypes.h"), "#pragma clang system_header\n")
    write(path.join(frameworks, "FixUser.framework", "Headers", "FixUser.h"), "#pragma clang system_header\n")
    local rows = {
        row("_FixPrivate", "typedef", "c:@T@FixPrivateType", "FixPrivateType", "FixPrivateTypes.h", "int", "-"),
        row("FixUser", "var", "c:@FixUserVar", "FixUserVar", "FixUser.h", "FixPrivateType", "-"),
    }
    local lines = {}
    for index, columns in ipairs(rows) do
        lines[index] = table.concat(columns, "\t")
    end
    local ir = path.join(SCRATCH, "full.tsv")
    write(ir, table.concat(lines, "\n") .. "\n")
    local tree = path.join(SCRATCH, "tree")
    os.mkdir(path.join(tree, "packages", "frameworks", "apple-backports", "registry"))

    local out = path.join(SCRATCH, "out")
    local port_values = path.join(SCRATCH, "port-values-empty.tsv")
    write(port_values, "# triple=armv7-apple-ios6.1.3 (no values)\n")
    cmd.run({tree = tree, ir = ir, sdk = sdk, out = out, port_values = port_values})

    local user = io.readfile(path.join(out, "Frameworks", "FixUser.framework", "Headers", "FixUser.h")) or ""
    check(string.find(user, "#import <FixPublic/FixPublic.h>", 1, true) ~= nil,
          "a header imports the public umbrella that re-exports the private framework")
    check(string.find(user, "_FixPrivate", 1, true) == nil, "no header imports a private framework's path")
    check(string.find(user, "FixUserVar", 1, true) ~= nil, "the variable is declared")

    os.rm(SCRATCH)
    print("reexport import test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

run()
