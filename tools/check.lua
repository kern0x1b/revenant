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
    docs = {"README.md", "tutorials", "guides", "reference", "explanation"},
    third_party = {"xmake.lua", "patches"},
    agentfiles = {"AGENTS.md", "CLAUDE.md", ".claude", ".agents"}
}

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
    for file in files:gmatch("[^\n]+") do
        local parts = path.split(file)
        local component
        if parts[1] == "frameworks" then
            component = #parts > 2 and 2 or nil
        elseif parts[1] == "toolchain" or parts[1] == "emulator" or parts[1] == "recompiler" or parts[1] == "agent-skills" then
            component = 1
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
        elseif component and #parts > component and not allowed.component[parts[component + 1]] then
            wrong(file, "a component holds only " .. table.concat(layout.component, ", "))
        elseif parts[1] == "docs" and not allowed.docs[parts[2]] then
            wrong(file, "docs/ holds only " .. table.concat(layout.docs, ", "))
        elseif parts[1] == "third_party" and #parts > 2 and not allowed.third_party[parts[3]] then
            wrong(file, "a third_party package holds only " .. table.concat(layout.third_party, ", "))
        end
    end
    for _, line in ipairs(errors) do
        print(line)
    end
    assert(#errors == 0, #errors .. " paths break the layout of AGENTS.md")
end

function checks.comments()
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
