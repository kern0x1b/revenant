local root = path.absolute(path.directory(os.scriptdir()))

local checks = {}

function checks.toolchain()
    os.execv(os.programfile(), {"l", path.join(root, "toolchain", "tests", "light.lua")}, {curdir = path.join(root, "toolchain")})
end

function checks.emulator()
    os.execv(os.programfile(), {"f", "-P", root, "-y"}, {curdir = root})
    os.execv(os.programfile(), {"build", "-P", root, "emulator"}, {curdir = root})
    os.execv(os.programfile(), {"test", "-P", root, "emulator_*/*"}, {curdir = root})
end

function checks.recompiler()
    os.execv(os.programfile(), {"f", "-P", root, "-y"}, {curdir = root})
    os.execv(os.programfile(), {"build", "-P", root, "xlate", "xlgen"}, {curdir = root})
    os.execv(os.programfile(), {"test", "-P", root, "recompiler_corpus/*"}, {curdir = root})
end

function checks.comments()
    os.execv(os.programfile(), {"l", path.join(root, "tools", "comments.lua"), "check"}, {curdir = root})
end

function main(...)
    local members = {...}
    if #members == 0 then
        members = table.orderkeys(checks)
    end
    for _, member in ipairs(members) do
        assert(checks[member], "no check for " .. member .. " (there are: " .. table.concat(table.orderkeys(checks), ", ") .. ")")
        print("== " .. member)
        checks[member]()
    end
end
