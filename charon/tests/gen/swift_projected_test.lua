-- A property wrapper's projected value (`$url`, `$isOn`, `$selection`) in the Swift skeleton (tools/gen/swift_render.lua projected): the
-- compiler synthesizes it from the wrapper and refuses a declaration of it ("cannot declare entity named '$url'; the '$' prefix is reserved
-- for implicitly-synthesized declarations", 5 modules of the coordinator's sdk run). The skeleton leaves it out; the round trip's compare
-- counts the SDK's row as projected, not missing, so the measured "missing" key does not move. Checked here on a model with a property
-- `url` and its projected value `$url`: the text declares url and not $url, and the compare of the SDK's two rows against the skeleton's
-- one counts the projected row, with no missing row. Run: xmake l tests/gen/swift_projected_test.lua (pure Lua: no toolchain)

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

-- A model row with every cell the renderer reads, "-" where the row says nothing.
local function row(fields)
    local out = {kind = "-", usr = "-", container = "-", name = "-", side = "-", type = "-", params = "-", generic_sig = "-",
                 conformances = "-", superclass = "-", throwing = "-", async = "-", mutating = "-", attributes = "-", accessors = "-",
                 storage = "-", is_let = "-", is_open = "-", requirement = "-", in_extension = "-", owner_module = "-", raw = "-",
                 alias = "-", overriding = "-", init_kind = "-", availability = "-", outer_names = "-"}
    for key, value in pairs(fields) do
        out[key] = value
    end
    return out
end

function main()
    local render = import("gen.swift_render", {rootdir = TOOLS, anonymous = true})
    local roundtrip = import("gen.swift_roundtrip", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local url = row({kind = "swift-property", container = "Field", name = "url", side = "-", type = "Foundation.URL",
                     accessors = "get", usr = "s:Field.url"})
    local projected = row({kind = "swift-property", container = "Field", name = "$url", side = "-", type = "Swift.Int",
                           accessors = "get", usr = "s:Field.$url"})
    local field = row({kind = "swift-struct", name = "Field", usr = "s:Field"})
    local text = render.render({field, url, projected}, "Fix", {Foundation = true}, nil, nil)
    check(string.find(text, "var url: Foundation.URL", 1, true) ~= nil, "the property url is declared")
    check(string.find(text, "$url", 1, true) == nil, "the projected value $url is not declared")
    check(render.projected(projected) and not render.projected(url), "projected() tells $url from url")

    -- the SDK's rows: the struct, url and $url; ours: the struct and url only (the renderer's output, read back as its rows)
    local sdk_rows = {field, url, projected}
    local ours = {field, url}
    local result = roundtrip.compare(sdk_rows, ours, nil)
    check(result.projected == 1, "the SDK's $url is counted as projected: " .. result.projected)
    check(#result.missing == 0, "the SDK's $url is not missing: " .. #result.missing)
    check(result.equal == 2, "the two other rows are equal: " .. result.equal)

    print("swift projected test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
