-- The WKWebView host passes the engine's WAKWindowTilingMode values to the engine's window. The backport cannot include the
-- engine's header, since the backport does not depend on the engine's source, so the host mirrors the enum. This test checks
-- the mirror against tests/data/webkit-tiling-modes.txt, which holds the enum as the pinned WebKit declares it. That file is
-- checked in, so CI runs the check. When REVENANT_WEBKIT_HEADER names the pinned WAKWindow.h, the file is also checked against
-- that header, names and lines.
local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local HOST = path.join(BACKPORTS, "src", "WebKit", "RevenantEngineHost.m")
local FACTS = path.join(TESTS, "data", "webkit-tiling-modes.txt")

-- The text between the opening and closing patterns, both Lua patterns.
local function block(text, opening, closing)
    local body = text:match(opening .. "(.-)" .. closing)
    assert(body, "no block between the patterns " .. opening .. " and " .. closing)
    return body
end

local function names(body, prefix)
    local found = {}
    for name in body:gmatch(prefix .. "(%w+)") do
        table.insert(found, name)
    end
    return found
end

-- The modes of the facts file in declaration order, each with the line it is declared on in the engine's header.
local function facts()
    local found = {}
    for line in io.readfile(FACTS):gmatch("[^\n]+") do
        if not line:find("^#") then
            local number, name = line:match("^(%d+) (%w+)$")
            assert(number and name, "the facts file has a line that is not a mode: " .. line)
            table.insert(found, {line = tonumber(number), name = name})
        end
    end
    return found
end

-- The modes of the header's WAKWindowTilingMode enum, each with the line it is declared on.
local function header_modes(text)
    local found, number, open = {}, 0, false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        number = number + 1
        if line:find("typedef enum {", 1, true) then
            open, found = true, {}
        elseif open and line:find("^}") then
            if line:find("} WAKWindowTilingMode;", 1, true) then
                return found
            end
            open = false
        elseif open then
            assert(not line:find("=", 1, true), "the engine's tiling modes carry explicit values, so counting them from 0 would not check the values")
            local name = line:match("^%s*(kWAKWindowTilingMode%w+),$")
            if name then
                table.insert(found, {line = number, name = name})
            end
        end
    end
    error("the header has no WAKWindowTilingMode enum")
end

function main()
    local modes = facts()
    assert(#modes == 6, string.format("the facts file lists %d tiling modes, and the engine declares six at c70a794", #modes))

    local host = block(io.readfile(HOST), "typedef NS_ENUM%(NSInteger, RevenantWAKWindowTilingMode%) {", "};")
    assert(not host:find("=", 1, true), "the host's tiling modes carry explicit values, so counting them from 0 would not check the values")
    local hostNames = names(host, "RevenantWAKWindowTilingMode")
    assert(#hostNames == #modes, string.format("the host mirrors %d tiling modes, and the engine declares %d", #hostNames, #modes))
    for index, mode in ipairs(modes) do
        local suffix = mode.name:match("^kWAKWindowTilingMode(%w+)$")
        assert(hostNames[index] == suffix, string.format("tiling mode %d: the engine declares %s, and the host mirrors %s", index - 1, mode.name, hostNames[index]))
    end

    local against = "the pinned header was not given in REVENANT_WEBKIT_HEADER, so the facts file was not compared with it"
    local header = os.getenv("REVENANT_WEBKIT_HEADER")
    if header and header ~= "" then
        local declared = header_modes(io.readfile(header))
        assert(#declared == #modes, string.format("the header declares %d tiling modes, and the facts file lists %d", #declared, #modes))
        for index, mode in ipairs(modes) do
            local found = declared[index]
            assert(found.name == mode.name, string.format("tiling mode %d: the facts file has %s, and the header declares %s", index - 1, mode.name, found.name))
            assert(found.line == mode.line, string.format("%s: the facts file has line %d, and the header declares it on line %d", mode.name, mode.line, found.line))
        end
        against = "and the facts file match the header in REVENANT_WEBKIT_HEADER, names and lines"
    end
    print(string.format("WEBKIT_TILING_TEST passed (%d tiling modes match the host's mirror in order, values 0 to %d; %s)", #modes, #modes - 1, against))
end
