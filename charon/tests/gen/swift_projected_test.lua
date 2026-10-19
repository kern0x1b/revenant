local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

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
