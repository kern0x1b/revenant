local root = path.directory(os.scriptdir())

local checks = {}

function checks.charon()
    os.execv(os.programfile(), {"l", path.join(root, "charon", "tests", "light.lua")}, {curdir = path.join(root, "charon")})
end

function checks.shade()
    local build = path.join(root, ".build", "shade")
    os.execv("cmake", {"-S", path.join(root, "shade"), "-B", build, "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release"})
    os.execv("cmake", {"--build", build})
    os.execv("ctest", {"--test-dir", build, "--output-on-failure"})
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
