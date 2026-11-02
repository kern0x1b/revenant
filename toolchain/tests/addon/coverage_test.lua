function failures(opt)
    local root = path.join(path.directory(opt.modules), "..")
    local coverage = import("coverage", {rootdir = path.join(root, "frameworks", "ReactNative", "tools"), anonymous = true})
    local json = import("core.base.json")
    local found = {}
    local none = {stubs = {}}
    local sample = {sdk = "1", reactNative = "2", device = "a phone", rows = {
        {id = "a|b", group = "sdk", version = "1.0", native = true, status = "real", verified = "phone", note = "x"},
        {id = "c", group = "core", version = "", native = false, status = "impossible", verified = "none", note = "why"}}}
    local text = coverage.render(sample, none)
    if not text:find("| a\\|b | 1.0 | yes | real | phone | x |", 1, true) then
        table.insert(found, "a row must be one table line with the bar escaped")
    end
    if not text:find("| real | built from the module's own sources, with no stub and no substitute | 1 |", 1, true) then
        table.insert(found, "the status table must count the rows")
    end
    if #coverage.validate(sample, none, root) ~= 0 then
        table.insert(found, "a sound sample must have no problems")
    end
    sample.rows[2].note = ""
    sample.rows[1].status = "fine"
    if #coverage.validate(sample, none, root) ~= 2 then
        table.insert(found, "an unknown status and a stub without a note must both be named")
    end
    local data = json.decode(io.readfile(path.join(root, "frameworks", "ReactNative", "src", "coverage.json")))
    local stubs = json.decode(io.readfile(path.join(root, "frameworks", "ReactNative", "src", "stubs.json")))
    local problems = coverage.validate(data, stubs, root)
    if #problems > 0 then
        table.insert(found, "coverage.json: " .. table.concat(problems, "; "))
    end
    if io.readfile(path.join(root, "docs", "reference", "react-native", "coverage.md")) ~= coverage.render(data, stubs) then
        table.insert(found, "docs/reference/react-native/coverage.md is not what coverage.json makes; run tools/coverage.lua")
    end
    return found
end
