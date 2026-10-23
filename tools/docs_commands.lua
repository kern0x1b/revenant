local root = path.absolute(path.directory(os.scriptdir()))

local XMAKE_TASKS = {f = true, config = true, build = true, test = true, l = true, lua = true, require = true,
                     package = true, install = true, uninstall = true, run = true, show = true, clean = true, addon = true}
local GLOBAL_VALUES = {P = true, p = true, a = true, j = true, o = true}
local GLOBAL_FLAGS = {y = true, v = true, c = true}
local GLOBAL_LONGS = {menu = true, yes = true, verbose = true, force = true, install = true, remove = true}

local errors = {}
local literals = {}

local function wrong(where, message)
    table.insert(errors, where .. ": " .. message)
end

local function tracked()
    local files = {}
    for file in os.iorunv("git", {"-C", root, "ls-files"}):gmatch("[^\n]+") do
        table.insert(files, file)
    end
    return files
end

local CODE = {lua = true, m = true, mm = true, c = true, cc = true, cpp = true, h = true, hpp = true, swift = true}

local function declarations(files)
    local options = {}
    for _, file in ipairs(files) do
        local extension = file:match("%.([%w]+)$")
        if CODE[extension] then
            local text = io.readfile(path.join(root, file))
            for name in text:gmatch('"([%w_%-%.]+)"') do
                literals[name] = true
            end
            for name in text:gmatch('"%-%-([%w_%-]+)') do
                literals["--" .. name] = true
            end
            for name in text:gmatch('([%w_]+) = "switch"') do
                literals["--" .. name] = true
            end
            for name in text:gmatch('([%w_]+) = "value"') do
                literals["--" .. name] = true
            end
        end
        if file:endswith(".lua") then
            local text = io.readfile(path.join(root, file))
            for name in text:gmatch('option%("([%w_%-]+)"') do
                options[name] = true
            end
        end
    end
    return options
end

local function menus(files)
    local plugins = {}
    for _, file in ipairs(files) do
        local name = file:match("^toolchain/plugins/([^/]+)/xmake%.lua$")
        if name then
            local text = io.readfile(path.join(root, file))
            local menu = {shorts = {}, longs = {}}
            for short, long, kind in text:gmatch('{"(%w)", "([%w_%-]+)", "(k%a*)"') do
                menu.shorts[short] = kind
                menu.longs[long] = kind
            end
            for long, kind in text:gmatch('{nil, "([%w_%-]+)", "(k%a*)"') do
                menu.longs[long] = kind
            end
            plugins[name] = menu
        end
    end
    return plugins
end

local function matches(name, pattern)
    local lua_pattern = "^" .. (pattern:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1"):gsub("%*", ".*")) .. "$"
    return name:match(lua_pattern) ~= nil
end

local function placeholder(word)
    return word == "" or word == "|" or word:find("[<>$|()]") ~= nil or word:find("...", 1, true) ~= nil
end

local function words(rest)
    local cut = (rest:gsub("%s#.*$", ""))
    local list = {}
    for word in cut:gmatch("%S+") do
        if word == "&&" or word:find("^[;<>]") or word:find("^%d?>") then
            break
        end
        table.insert(list, (word:gsub("[%[%]\"'`]", "")))
    end
    return list
end

local function check_script(where, list, first)
    local script = list[first]
    if placeholder(script) then
        return
    end
    local full = path.join(root, script)
    if not os.isfile(full) and not os.isdir(full) then
        wrong(where, "no file or folder at " .. script)
        return
    end
    for index = first + 1, #list do
        local long = list[index]:match("^%-%-([%w_%-]+)")
        if long and not literals["--" .. long] then
            wrong(where, script .. " has no option --" .. long)
        end
    end
end

local function check_command(where, rest, plugins, options, opening)
    local list = words(rest)
    local task, index = nil, 1
    while index <= #list do
        local word = list[index]
        if word:sub(1, 1) ~= "-" then
            task = word
            break
        end
        if word:sub(1, 2) ~= "--" and #word == 2 and GLOBAL_VALUES[word:sub(2, 2)] then
            index = index + 1
        end
        index = index + 1
    end
    if not task then
        return
    end
    if opening == "./xmakew" then
        local pinned = false
        for _, word in ipairs(list) do
            if word == "-P" then
                pinned = true
            end
        end
        if not pinned then
            wrong(where, "./xmakew " .. task .. " has no -P: in a worktree xmake would build another checkout's project")
        end
    end
    local menu = plugins[task]
    if not menu and not XMAKE_TASKS[task] then
        wrong(where, "no xmake task named " .. task)
        return
    end
    if task == "l" then
        local position = index + 1
        while position <= #list do
            local word = list[position]
            if word:sub(1, 1) ~= "-" then
                if not placeholder(word) then
                    check_script(where, list, position)
                end
                return
            end
            if #word == 2 and GLOBAL_VALUES[word:sub(2, 2)] then
                position = position + 1
            end
            position = position + 1
        end
        return
    end
    local positionals = {}
    local position = index + 1
    while position <= #list do
        local word = list[position]
        if word:sub(1, 2) == "--" then
            local name = word:match("^%-%-([%w_%-]+)")
            local inline = word:find("=", 1, true) ~= nil
            if menu then
                local kind = menu.longs[name]
                if not kind and not GLOBAL_LONGS[name] then
                    wrong(where, "--" .. name .. " is not an option of xmake " .. task)
                elseif kind == "kv" and not inline then
                    position = position + 1
                end
            elseif not options[name] and not GLOBAL_LONGS[name] then
                wrong(where, "--" .. name .. " is not an option the project declares")
            end
        elseif word:sub(1, 1) == "-" and #word >= 2 then
            local letter = word:sub(2, 2)
            local kind = menu and menu.shorts[letter]
            if kind then
                if kind == "kv" and #word == 2 then
                    position = position + 1
                end
            elseif GLOBAL_VALUES[letter] then
                if #word == 2 then
                    position = position + 1
                end
            elseif not GLOBAL_FLAGS[letter] then
                wrong(where, "-" .. letter .. " is not an option of xmake " .. task)
            end
        elseif not placeholder(word) then
            table.insert(positionals, word)
        end
        position = position + 1
    end
    if task == "build" or task == "test" then
        for _, word in ipairs(positionals) do
            local first = word:match("^([^/]+)")
            if first then
                local known = literals[first]
                if first:find("*", 1, true) then
                    known = false
                    for name in pairs(literals) do
                        if matches(name, first) then
                            known = true
                        end
                    end
                end
                if not known then
                    wrong(where, "no target named " .. first)
                end
            end
        end
    end
    if task == "require" then
        for _, word in ipairs(positionals) do
            local name = word:match("^revenant@([%w_%-%.]+)$")
            if name and not os.isfile(path.join(root, "packages", name:sub(1, 1), name, "xmake.lua")) then
                wrong(where, "no package revenant@" .. name)
            end
        end
    end
end

function main()
    local files = tracked()
    local options = declarations(files)
    local plugins = menus(files)
    for _, file in ipairs(files) do
        if file:endswith(".md") and (file:find("^docs/") or file:find("README%.md$")) then
            local text = io.readfile(path.join(root, file))
            local number = 0
            for line in (text .. "\n"):gmatch("(.-)\n") do
                number = number + 1
                local where = file .. ":" .. number
                for _, opening in ipairs({"./xmakew", "`xmake "}) do
                    local position = 1
                    while true do
                        local start, finish = line:find(opening, position, true)
                        if not start then
                            break
                        end
                        local rest = line:sub(finish + 1):match("^([^`]*)")
                        local following = rest:find(opening, 1, true)
                        if following then
                            rest = rest:sub(1, following - 1)
                        end
                        check_command(where, rest, plugins, options, opening)
                        position = finish + 1
                    end
                end
            end
        end
    end
    for _, line in ipairs(errors) do
        print(line)
    end
    assert(#errors == 0, #errors .. " documented commands do not match the code")
end
