local macho = import("@addon.revenant.apple.macho", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local ATTACH = "_revenant_backports_attach"
local LOAD = "_revenant_backports_load"
local STUB = "^_revenant_stub_"
local USAGE = "usage: ./xmakew l -P . frameworks/Backports/tests/init_order_test.lua test | check FOLDER"

function describe(data, found)
    local description = {categories = false, stubs = false}
    local initialisers = {}
    for _, section in ipairs(found.sections) do
        if section.name == "__port_catlist" and section.size > 0 then
            description.categories = true
        elseif section.name == "__mod_init_func" then
            for offset = 0, section.size - 4, 4 do
                table.insert(initialisers, string.unpack("<I4", data, found.base + section.offset + offset + 1) & ~1)
            end
        end
    end
    local function position(symbol)
        local address = macho.symbol(data, found, symbol)
        if address then
            for index, initialiser in ipairs(initialisers) do
                if initialiser == address & ~1 then
                    return index
                end
            end
        end
    end
    description.attach = position(ATTACH)
    description.load = position(LOAD)
    for _, entries in pairs(macho.code_symbols(data, found)) do
        for _, entry in ipairs(entries) do
            if entry.name:find(STUB) then
                description.stubs = true
            end
        end
    end
    return description
end

function problems(name, description)
    local found = {}
    if description.categories and not description.attach then
        table.insert(found, name .. ": it has categories of its own and revenant_backports_attach is not among its initialisers, so they are never added")
    end
    if description.stubs and not description.load then
        table.insert(found, name .. ": it has stubs and revenant_backports_load is not among its initialisers, so they are never registered")
    end
    if description.attach and description.load and description.attach > description.load then
        table.insert(found, string.format("%s: revenant_backports_load (initialiser %d) runs before revenant_backports_attach (initialiser %d), so a stub takes the place of a member the library implements in a category",
            name, description.load, description.attach))
    end
    return found
end

local function check(folder)
    local libraries = os.files(path.join(folder, "*.dylib"))
    table.sort(libraries)
    local checked, failures = 0, {}
    for _, library in ipairs(libraries) do
        local data = macho.read(library)
        for _, found in ipairs(macho.images(data)) do
            local description = describe(data, found)
            if description.attach and description.load then
                checked = checked + 1
            end
            table.join2(failures, problems(path.filename(library), description))
        end
    end
    for _, failure in ipairs(failures) do
        print(failure)
    end
    if #failures > 0 then
        raise("init order: %d problem(s) in %s", #failures, folder)
    end
    if checked == 0 then
        raise("init order: no library in %s has both initialisers; a check that reads nothing would pass for every library", folder)
    end
    print(string.format("init order: revenant_backports_attach runs before revenant_backports_load in %d of %d libraries; none is out of order", checked, #libraries))
end

local function test()
    local function expect(condition, message)
        assert(condition, "init order test: " .. message)
    end
    expect(#problems("a", {categories = true, stubs = true, attach = 1, load = 2}) == 0, "the right order has no problem")
    local reversed = problems("a", {categories = true, stubs = true, attach = 2, load = 1})
    expect(#reversed == 1 and reversed[1]:find("runs before revenant_backports_attach", 1, true), "load before attach is a problem")
    expect(#problems("a", {categories = true, stubs = false, load = 1}) == 1, "categories without their initialiser are a problem")
    expect(#problems("a", {categories = false, stubs = true, attach = 1}) == 1, "stubs without their initialiser are a problem")
    expect(#problems("a", {categories = false, stubs = false}) == 0, "a library with neither has no problem")
    local empty = workspace.fresh("init-order-empty")
    local refused = false
    try { function () check(empty) end, catch { function () refused = true end } }
    os.tryrm(empty)
    expect(refused, "a folder with no library is refused")
    print("init order tests passed")
end

function main(command, folder)
    if command == "test" then
        test()
    elseif command == "check" and folder then
        test()
        check(folder)
    else
        raise(USAGE)
    end
end
