local root = path.absolute(path.directory(os.scriptdir()))

local layout = {
    top = {"AGENTS.md", "README.md", "CONTRIBUTING.md", "SECURITY.md", "LICENSES", "REUSE.toml",
           "xmake.lua", "xmakew", "tools", "docs", "toolchain", "packages", "addons", "emulator", "recompiler",
           "agent-skills", "frameworks", ".agents", ".claude", ".claude-plugin", ".github", ".editorconfig", ".gitattributes",
           ".gitignore"},
    component = {"xmake.lua", "README.md", "LICENSE", "src", "include", "tests", "examples", "tools"},
    plugin = {"README.md", "tests", ".claude-plugin", "skills", "LICENSE", "THIRD-PARTY.md"},
    docs = {"README.md", "tutorials", "guides", "reference", "explanation"},
    agentfiles = {"AGENTS.md", "CLAUDE.md", ".claude", ".agents"},
    addon = {"addon.lua", "includes", "modules", "plugins", "rules", "toolchains"}
}

local addon = {
    plugins = {depth = 4, files = {"xmake.lua", "main.lua"}},
    rules = {depth = 4, files = {"xmake.lua"}},
    toolchains = {depth = 4, files = {"xmake.lua"}},
    includes = {depth = 4, files = {"xmake.lua"}}
}

local COMPONENTS = {"frameworks", "toolchain", "emulator", "recompiler", "agent-skills"}

local UNCONVERTED = {}

local ADDON_PATH = '"toolchain", "' .. "modules" .. '"'

local BY_PATH = {
    ["frameworks/Backports/tests/backports_test.lua"] = true,
    ["frameworks/Backports/tests/uikit_test.lua"] = true,
    ["frameworks/Backports/tools/libraries.lua"] = true,
    ["frameworks/Backports/tools/sdk.lua"] = true,
    ["frameworks/WebKit/tests/device/harness.lua"] = true
}

local REACHING = {}

local function set_of(list)
    local set = {}
    for _, name in ipairs(list) do
        set[name] = true
    end
    return set
end

local function thin_wrapper(text)
    if text:find('@addon.revenant.apple.wrapper', 1, true) then
        return true
    end
    return text:find('includes(\\"', 1, true) ~= nil and text:find('"install"', 1, true) ~= nil
end

local function reaches_into_component(text)
    for line in text:gmatch("[^\n]+") do
        if line:find('".."', 1, true) then
            for _, component in ipairs(COMPONENTS) do
                if line:find('"' .. component .. '"', 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function has(list, name)
    for _, entry in ipairs(list) do
        if entry == name then
            return true
        end
    end
    return false
end

local function addon_fault(parts, first)
    local kind, last = parts[first], parts[#parts]
    if kind == "addon.lua" then
        return #parts > first and "addon.lua is a file" or nil
    elseif kind == "modules" then
        if not last:endswith(".lua") then
            return "modules/ holds Lua files only"
        end
    else
        local shape = addon[kind]
        if #parts ~= shape.depth or not has(shape.files, last) then
            return kind .. " folders hold " .. table.concat(shape.files, " and ") .. " only"
        end
    end
end

local function patches_fault(parts)
    if not parts[#parts]:endswith(".patch") then
        return "patches/ holds .patch files only"
    end
end

local function port_fault(parts)
    local name = parts[#parts]
    if #parts ~= 5 then
        return "port/ holds files, not folders: the sources a package builds are in their component's src/"
    elseif name == "project.lua" or name == "config.h" or name:endswith(".lua") or name:endswith(".exp") then
        return nil
    end
    return "port/ holds build files only (project.lua, config.h, generated Lua and .exp lists): the sources a package builds are in their component's src/"
end

local function recipe_fault(parts)
    local kind = parts[1]
    if #parts < 3 then
        return kind .. " holds one folder per recipe, under the first letter of its name"
    elseif #parts[2] ~= 1 or parts[2] ~= parts[3]:sub(1, 1) then
        return kind .. " folders are named <first letter>/<name>"
    elseif kind == "addons" then
        if #parts ~= 4 or parts[4] ~= "xmake.lua" then
            return "addons/<letter>/<name> holds xmake.lua only"
        end
        return nil
    elseif #parts == 4 and parts[4] == "xmake.lua" then
        return nil
    elseif #parts > 4 and parts[4] == "patches" then
        return patches_fault(parts)
    elseif #parts > 4 and parts[4] == "port" then
        return port_fault(parts)
    end
    return "packages/<letter>/<name> holds xmake.lua, patches/ and port/ only"
end

function main()
    local allowed = {}
    for name, list in pairs(layout) do
        allowed[name] = {}
        for _, entry in ipairs(list) do
            allowed[name][entry] = true
        end
    end
    local errors = {}
    local function wrong(file, why)
        table.insert(errors, file .. ": " .. why)
    end
    local files = os.iorunv("git", {"-C", root, "-c", "core.quotepath=false", "ls-files"})
    local present = {}
    local folders = {}
    local recipes = {}
    for file in files:gmatch("[^\n]+") do
        present[file] = true
        local parts = path.split(file)
        if file:lower():find("telegram", 1, true) then
            wrong(file, "the test app's source is not in the repository: see docs/explanation/decisions/0009-telegram-test.md")
        end
        if file:endswith(".py") then
            wrong(file, "Lua only: the repository has no Python")
        elseif file:endswith(".sh") or parts[#parts] == "Makefile" then
            wrong(file, "one entry point, ./xmakew: no shell scripts or Makefiles")
        end
        if file:endswith(".lua") and parts[1] ~= "toolchain" and not BY_PATH[file]
            and io.readfile(path.join(root, file)):find(ADDON_PATH, 1, true) then
            wrong(file, "reaches the addon's modules by path: import them as @addon.revenant.<module>")
        end
        local component
        if parts[1] == "frameworks" then
            component = #parts > 2 and 2 or nil
        elseif parts[1] == "toolchain" or parts[1] == "emulator" or parts[1] == "recompiler" or parts[1] == "agent-skills" then
            component = 1
        end
        local members, listed = allowed.component, layout.component
        if parts[1] == "agent-skills" then
            members, listed = allowed.plugin, layout.plugin
        end
        for i = 2, #parts do
            if allowed.agentfiles[parts[i]] then
                wrong(file, "agent files live only at the top")
            end
        end
        if not allowed.top[parts[1]] then
            wrong(file, "not part of the top layout")
        elseif parts[1] == "frameworks" and #parts == 2 then
            wrong(file, "frameworks/ holds framework folders only")
        elseif parts[1] == "packages" or parts[1] == "addons" then
            local why = recipe_fault(parts)
            if why then
                wrong(file, why)
            end
            if #parts >= 3 then
                recipes[parts[1] .. "/" .. parts[2] .. "/" .. parts[3]] = true
            end
        elseif (parts[1] == "toolchain" and allowed.addon[parts[2]]) or addon[parts[1]] then
            local first = parts[1] == "toolchain" and 2 or 1
            local shape = addon[parts[first]]
            if shape and #parts >= shape.depth then
                folders[table.concat(parts, "/", 1, shape.depth - 1)] = shape.files
            end
            local why = addon_fault(parts, first)
            if why then
                wrong(file, why)
            end
        elseif component and #parts > component and not members[parts[component + 1]] then
            wrong(file, "a component holds only " .. table.concat(listed, ", "))
        elseif parts[1] == "docs" and not allowed.docs[parts[2]] then
            wrong(file, "docs/ holds only " .. table.concat(layout.docs, ", "))
        end
    end
    for _, folder in ipairs(table.orderkeys(folders)) do
        for _, name in ipairs(folders[folder]) do
            if not present[folder .. "/" .. name] then
                wrong(folder, "has no " .. name)
            end
        end
    end
    local unconverted, reaching = set_of(UNCONVERTED), set_of(REACHING)
    for _, recipe in ipairs(table.orderkeys(recipes)) do
        if not present[recipe .. "/xmake.lua"] then
            wrong(recipe, "has no xmake.lua")
        else
            local name = path.filename(recipe)
            local text = io.readfile(path.join(root, recipe, "xmake.lua"))
            if text:find("add_urls", 1, true) then
                if unconverted[name] then
                    wrong(recipe, "has a url, so it is not listed in UNCONVERTED any more: remove it from the list")
                end
                local into = reaches_into_component(text)
                if into and not reaching[name] then
                    wrong(recipe, "reaches into a component folder by a relative path: a component's sources are built through the build graph, not a path into its folder")
                elseif reaching[name] and not into then
                    wrong(recipe, "no longer reaches into a component folder: remove it from REACHING")
                end
            elseif thin_wrapper(text) then
                if unconverted[name] then
                    wrong(recipe, "is a thin wrapper of its component now: remove it from UNCONVERTED")
                end
            elseif not unconverted[name] then
                wrong(recipe, "has no url and is not a thin wrapper: it generates a project that includes one component and installs its targets, and holds no sources of its own")
            end
        end
    end
    for _, file in ipairs(table.orderkeys(BY_PATH)) do
        if not present[file] or not io.readfile(path.join(root, file)):find(ADDON_PATH, 1, true) then
            wrong(file, "no longer reaches the addon's modules by path: remove it from BY_PATH")
        end
    end
    for _, line in ipairs(errors) do
        print(line)
    end
    assert(#errors == 0, #errors .. " paths break the layout of AGENTS.md")
end
