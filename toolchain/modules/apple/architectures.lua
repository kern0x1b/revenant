import("core.base.semver")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

ARCHITECTURES = {
    armv6 = {first = "2.0", last = "4.2.1"},
    armv7 = {first = "3.0"},
    armv7s = {first = "6.0"},
    arm64 = {first = "7.0"}
}

function names()
    return table.orderkeys(ARCHITECTURES)
end

local function runs(architecture, release)
    local bounds = ARCHITECTURES[architecture]
    return semver.compare(release, bounds.first) >= 0 and (not bounds.last or semver.compare(release, bounds.last) <= 0)
end

function deployment(architecture, declared)
    local bounds = ARCHITECTURES[architecture]
    if not bounds then
        raise("toolchain(apple-ios) builds %s, not %s", table.concat(table.orderkeys(ARCHITECTURES), ", "), architecture)
    end
    if bounds.last and semver.compare(declared, bounds.last) > 0 then
        raise("apple_minimum %s is newer than %s, the last release an %s device runs", declared, bounds.last, architecture)
    end
    if semver.compare(declared, bounds.first) >= 0 then
        return declared
    end
    local reached = {}
    for name in pairs(ARCHITECTURES) do
        if runs(name, declared) then
            table.insert(reached, name)
        end
    end
    byteorder.sort(reached)
    raise("apple_minimum %s is older than %s, the first release an %s device runs; %s", declared, bounds.first, architecture,
          #reached > 0 and ("%s runs it, so build that architecture, or raise apple_minimum to %s"):format(table.concat(reached, " and "), bounds.first)
                        or ("no architecture this toolchain builds runs it, so raise apple_minimum to %s"):format(bounds.first))
end
