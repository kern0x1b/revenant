local root = path.absolute(path.directory(os.scriptdir()))

local checks = {}

function checks.toolchain()
    os.execv(os.programfile(), {"l", path.join(root, "toolchain", "tests", "light.lua")}, {curdir = path.join(root, "toolchain")})
end

function checks.emulator()
    os.execv(os.programfile(), {"f", "-P", root, "-y"}, {curdir = root})
    os.execv(os.programfile(), {"build", "-P", root, "emulator"}, {curdir = root})
    os.execv(os.programfile(), {"test", "-P", root, "emulator_*/*"}, {curdir = root})
end

function checks.recompiler()
    os.execv(os.programfile(), {"f", "-P", root, "-y"}, {curdir = root})
    os.execv(os.programfile(), {"build", "-P", root, "xlate", "xlgen"}, {curdir = root})
    os.execv(os.programfile(), {"test", "-P", root, "recompiler_corpus/*"}, {curdir = root})
end

local layout = {
    top = {"AGENTS.md", "README.md", "CONTRIBUTING.md", "SECURITY.md", "CHANGELOG.md", "LICENSES", "REUSE.toml",
           "xmake.lua", "xmakew", "tools", "docs", "third_party", "toolchain", "emulator", "recompiler", "agent-skills",
           "frameworks", ".agents", ".claude", ".claude-plugin", ".github", ".editorconfig", ".gitattributes", ".gitignore"},
    component = {"xmake.lua", "README.md", "src", "include", "patches", "tests", "examples", "tools"},
    plugin = {"README.md", "tests", ".claude-plugin", "skills", "LICENSE", "THIRD-PARTY.md"},
    docs = {"README.md", "tutorials", "guides", "reference", "explanation"},
    third_party = {"xmake.lua", "patches"},
    agentfiles = {"AGENTS.md", "CLAUDE.md", ".claude", ".agents"},
    addon = {"addon.lua", "addons", "includes", "modules", "packages", "plugins", "rules", "toolchains"}
}

local addon = {
    plugins = {depth = 4, files = {"xmake.lua", "main.lua"}},
    rules = {depth = 4, files = {"xmake.lua"}},
    toolchains = {depth = 4, files = {"xmake.lua"}},
    includes = {depth = 4, files = {"xmake.lua"}},
    packages = {depth = 5, files = {"xmake.lua"}},
    addons = {depth = 5, files = {"xmake.lua"}}
}

local function has(list, name)
    for _, entry in ipairs(list) do
        if entry == name then
            return true
        end
    end
    return false
end

local function addon_fault(parts)
    local kind, last = parts[2], parts[#parts]
    if kind == "addon.lua" then
        return #parts > 2 and "addon.lua is a file" or nil
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

function checks.layout()
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
    for file in files:gmatch("[^\n]+") do
        present[file] = true
        local parts = path.split(file)
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
        elseif parts[1] == "toolchain" and allowed.addon[parts[2]] then
            local shape = addon[parts[2]]
            if shape and #parts >= shape.depth then
                folders[table.concat(parts, "/", 1, shape.depth - 1)] = shape.files
            end
            local why = addon_fault(parts)
            if why then
                wrong(file, why)
            end
        elseif component and #parts > component and not members[parts[component + 1]] then
            wrong(file, "a component holds only " .. table.concat(listed, ", "))
        elseif parts[1] == "docs" and not allowed.docs[parts[2]] then
            wrong(file, "docs/ holds only " .. table.concat(layout.docs, ", "))
        elseif parts[1] == "third_party" and #parts > 2 and not allowed.third_party[parts[3]] then
            wrong(file, "a third_party package holds only " .. table.concat(layout.third_party, ", "))
        end
    end
    for _, folder in ipairs(table.orderkeys(folders)) do
        for _, name in ipairs(folders[folder]) do
            if not present[folder .. "/" .. name] then
                wrong(folder, "has no " .. name)
            end
        end
    end
    for _, line in ipairs(errors) do
        print(line)
    end
    assert(#errors == 0, #errors .. " paths break the layout of AGENTS.md")
end

function checks.comments()
    os.execv(os.programfile(), {"l", path.join(root, "tools", "comments.lua"), "test"}, {curdir = root})
    os.execv(os.programfile(), {"l", path.join(root, "tools", "comments.lua"), "check"}, {curdir = root})
end

function main(...)
    local members = {...}
    if #members == 0 then
        members = table.orderkeys(checks)
    end
    for _, member in ipairs(members) do
        assert(checks[member], "no check for " .. member .. " (there are: " .. table.concat(table.orderkeys(checks), ", ") .. ")")
        print("== " .. member)
        checks[member]()
    end
end
