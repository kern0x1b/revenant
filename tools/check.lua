-- xmake l tools/check.lua [<member> ...]
--
-- The checks of hades' members that need no device, no SDK download and no firmware, run from one place. With no
-- argument every member that has one is checked; otherwise only the members named. Exits non-zero on the first failure.
--
--   charon  the light guard (charon/tests/light.lua): its pure-Lua suites
--   shade   a Release build of the emulator with the pinned dynarmic and Boost (third_party), then its ctest suite;
--           the build folder is .build/shade, kept between runs so a second check rebuilds only what changed
--
-- Each member's heavier checks (charon's package gate, shade's boots, eidolon's snapshots) stay in that member's own
-- README: they need firmware, SDKs or a device.
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
