-- The WKWebView host passes the engine's WAKWindowTilingMode values to the engine's window. The backport cannot include the
-- engine's header, since the backport does not depend on the engine's source, so the host mirrors the enum. This test checks
-- the mirror against the header of the pinned engine, which REVENANT_WEBKIT_HEADER names (WAKWindow.h in the WebKit source).
local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local HOST = path.join(BACKPORTS, "src", "WebKit", "RevenantEngineHost.m")

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

function main()
    local header = os.getenv("REVENANT_WEBKIT_HEADER")
    if not header or header == "" then
        print("WEBKIT_TILING_TEST skipped: REVENANT_WEBKIT_HEADER is not set (the WAKWindow.h of the pinned WebKit)")
        return
    end
    local engine = block(io.readfile(header), "typedef enum {", "} WAKWindowTilingMode;")
    assert(not engine:find("=", 1, true), "the engine's tiling modes carry explicit values, so counting them from 0 would not check the values")
    local engineNames = names(engine, "kWAKWindowTilingMode")
    local host = block(io.readfile(HOST), "typedef NS_ENUM%(NSInteger, RevenantWAKWindowTilingMode%) {", "};")
    local hostNames = names(host, "RevenantWAKWindowTilingMode")

    assert(#engineNames == 6, string.format("the engine declares %d tiling modes, and the test expects the six of WebKit at c70a794", #engineNames))
    assert(#hostNames == #engineNames, string.format("the host mirrors %d tiling modes, and the engine declares %d", #hostNames, #engineNames))
    for index, name in ipairs(engineNames) do
        local mirror = hostNames[index]
        -- The engine spells one mode Disable and the host Disabled, so the host's name must start with the engine's.
        assert(mirror:sub(1, #name) == name, string.format("tiling mode %d: the engine declares %s, and the host mirrors %s", index - 1, name, mirror))
    end
    print(string.format("WEBKIT_TILING_TEST passed (%d tiling modes match the engine's header in order, values 0 to %d)", #engineNames, #engineNames - 1))
end
