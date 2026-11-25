local macho = import("@addon.revenant.apple.macho", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local ATTACH = "_revenant_backports_attach"
local LOAD = "_revenant_backports_load"
local STUB = "^_revenant_stub_"
local USAGE = "usage: ./xmakew l -P . frameworks/Backports/tests/init_order_test.lua test | check FOLDER"

function describe(data, found)
    local description = {categories = false, stubs = false, unreadable = not found.symtab}
    local initialisers = {}
    local width, layout = 4, "<I4"
    if found.wide then
        width, layout = 8, "<I8"
    end
    for _, section in ipairs(found.sections) do
        if section.name == "__port_catlist" and section.size > 0 then
            description.categories = true
        elseif section.name == "__mod_init_func" then
            description.initialisers = found.base + section.offset
            for offset = 0, section.size - width, width do
                table.insert(initialisers, string.unpack(layout, data, description.initialisers + offset + 1) & ~1)
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
    if description.unreadable then
        return {name .. ": it has no symbol table, so neither its initialisers nor its stubs can be read"}
    end
    if description.categories and not description.attach then
        table.insert(found, name .. ": it has categories of its own and revenant_backports_attach is not among its initialisers, so they are never added")
    end
    if description.stubs and not description.load then
        table.insert(found, name .. ": it has stubs and revenant_backports_load is not among its initialisers, so they are never registered")
    end
    if description.attach and description.load and description.attach > description.load then
        table.insert(found, string.format("%s: revenant_backports_load (initialiser %d) runs before revenant_backports_attach (initialiser %d), so a stub would take the place of a member the library implements in a category",
            name, description.load, description.attach))
    end
    return found
end

local function swapped(data, found, description)
    local width = found.wide and 8 or 4
    local first = description.initialisers + (description.attach - 1) * width
    local second = description.initialisers + (description.load - 1) * width
    return data:sub(1, first) .. data:sub(second + 1, second + width) .. data:sub(first + width + 1, second) ..
        data:sub(first + 1, first + width) .. data:sub(second + width + 1)
end

local function check(folder)
    local libraries = os.files(path.join(folder, "*.dylib"))
    table.sort(libraries)
    local checked, failures, sample = 0, {}, nil
    for _, library in ipairs(libraries) do
        local data = macho.read(library)
        local both = false
        for _, found in ipairs(macho.images(data)) do
            local description = describe(data, found)
            local wrong = problems(path.filename(library), description)
            if description.attach and description.load then
                both = true
                if not sample and #wrong == 0 and description.categories and description.stubs then
                    sample = {data = data, found = found, description = description, name = path.filename(library)}
                end
            end
            table.join2(failures, wrong)
        end
        if both then
            checked = checked + 1
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
    if not sample then
        raise("init order: no library in %s has categories, stubs and both initialisers, so the reading of one of them is broken", folder)
    end
    local turned = swapped(sample.data, sample.found, sample.description)
    if #problems(sample.name, describe(turned, sample.found)) ~= 1 then
        raise("init order: %s with its two initialisers swapped is not reported, so the order is not read from its bytes", sample.name)
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
    expect(#problems("a", {categories = false, stubs = false, unreadable = true}) == 1, "a library without a symbol table is refused")
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
