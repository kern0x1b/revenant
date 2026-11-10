import("fixtures")

local versions = import("@addon.revenant.apple.backports_versions", {anonymous = true})

local LIBRARY = versions.folder() .. "/libUIKitBackports.dylib"
local SYSTEM = "/usr/lib/libSystem.B.dylib"
local CONSUMER = "@rpath/libswiftUniformTypeIdentifiers.dylib"
local ONE = 65536
local TWO = 131072

local function word(value)
    return string.char(value % 256, math.floor(value / 256) % 256, math.floor(value / 65536) % 256, math.floor(value / 16777216) % 256)
end

local function dylib(command, name, current, compatibility)
    local text = name .. "\0"
    while #text % 4 ~= 0 do
        text = text .. "\0"
    end
    return word(command) .. word(24 + #text) .. word(24) .. word(2) .. word(current) .. word(compatibility) .. text
end

local function image(identity, loads)
    local commands = {}
    if identity then
        table.insert(commands, dylib(0xD, identity[1], identity[2], identity[3]))
    end
    for _, load in ipairs(loads) do
        table.insert(commands, dylib(0xC, load[1], load[2], load[3]))
    end
    local body = table.concat(commands)
    return word(0xFEEDFACE) .. word(12) .. word(9) .. word(6) .. word(#commands) .. word(#body) .. word(0) .. body
end

function failures()
    local found = {}
    local function expect(name, condition, detail)
        if not condition then
            table.insert(found, string.format("%s: %s", name, detail))
        end
    end

    expect("the policy version is 1.0.0", versions.version() == "1.0.0" and versions.packed("1.0.0") == ONE
        and versions.packed("2.0.0") == TWO, "got " .. versions.version())
    expect("the link flags declare the policy version both ways",
        table.concat(versions.flags(), " ") == "-Wl,-current_version,1.0.0 -Wl,-compatibility_version,1.0.0",
        "got " .. table.concat(versions.flags(), " "))

    local passed = versions.problems(image({LIBRARY, ONE, ONE}, {}))
    expect("a Backports library declaring the policy version both ways passes", #passed == 0, "refused: " .. table.concat(passed, "; "))

    local zero = versions.problems(image({LIBRARY, 0, 0}, {}))
    expect("a Backports library declaring 0.0.0 is refused and named",
        #zero == 1 and zero[1]:find(LIBRARY, 1, true) ~= nil and zero[1]:find("0.0.0", 1, true) ~= nil,
        "got " .. table.concat(zero, "; "))

    local skewed = versions.problems(image({LIBRARY, TWO, ONE}, {}))
    expect("a Backports library whose current and compatibility versions differ is refused",
        #skewed == 1 and skewed[1]:find("2.0.0", 1, true) ~= nil, "got " .. table.concat(skewed, "; "))

    local consumed = versions.problems(image({CONSUMER, 0, 0}, {{LIBRARY, ONE, ONE}}))
    expect("a consumer loading a Backports library at the policy version passes", #consumed == 0, "refused: " .. table.concat(consumed, "; "))

    local above = versions.problems(image({CONSUMER, 0, 0}, {{LIBRARY, ONE, TWO}}))
    expect("a consumer loading a Backports library above the policy version is refused and named",
        #above == 1 and above[1]:find(LIBRARY, 1, true) ~= nil and above[1]:find("2.0.0", 1, true) ~= nil,
        "got " .. table.concat(above, "; "))

    local lower = versions.problems(image({CONSUMER, 0, 0}, {{LIBRARY, 0, 0}}))
    expect("a consumer loading a Backports library at 0.0.0 passes", #lower == 0, "refused: " .. table.concat(lower, "; "))

    local system = versions.problems(image({CONSUMER, 0, 0}, {{SYSTEM, TWO, TWO}}))
    expect("a load of a system library is left to the system", #system == 0, "refused: " .. table.concat(system, "; "))

    local folder = fixtures.scratch()
    local file = path.join(folder, "libUIKitBackports.dylib")
    io.writefile(file, image({LIBRARY, 0, 0}, {}), {encoding = "binary"})
    local refused
    try {
        function ()
            versions.check(file)
        end,
        catch {
            function (errors)
                refused = tostring(errors)
            end
        }
    }
    expect("the gate refuses a built library whose versions differ from the policy, naming it",
        refused ~= nil and refused:find(LIBRARY, 1, true) ~= nil, "message " .. tostring(refused))
    os.tryrm(folder)

    return found
end
