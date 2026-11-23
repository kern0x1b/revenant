local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(sdkfiles.root(), "toolchain/modules"), anonymous = true})

local KEY_FILE = ".input-key"
local ENVIRONMENT = {"REVENANT_GEN_SDK", "REVENANT_BACKPORTS_LIBRARIES"}

local function add_files(lines, folder, label)
    for _, file in ipairs(os.files(path.join(folder, "**"))) do
        local relative = path.relative(file, folder)
        local content = os.islink(file) and ("link " .. tostring(os.readlink(file))) or hash.sha256(file)
        table.insert(lines, label .. "/" .. relative .. "=" .. content)
    end
end

local function add_file(lines, file, label)
    if not os.isfile(file) then
        return false
    end
    table.insert(lines, label .. "=" .. hash.sha256(file))
    return true
end

function key_file(root)
    return path.join(root or sdkfiles.build_root(), "skeleton", KEY_FILE)
end

function read(root)
    local file = key_file(root)
    return os.isfile(file) and io.readfile(file):trim() or nil
end

function write(folder, key)
    if key then
        io.writefile(path.join(folder, KEY_FILE), key .. "\n")
    end
end

function unchanged(root, key)
    return key ~= nil and read(root) == key
end

function compute(opt)
    opt = opt or {}
    local root = opt.root or sdkfiles.root()
    local sdk = opt.sdk or sdkfiles.sdk_folder()
    local tools = opt.tools or path.join(root, "frameworks", "Backports", "tools")
    local src = opt.src or path.join(root, "frameworks", "Backports", "src")
    local modules = opt.modules or path.join(root, "toolchain/modules")
    local xmake = opt.xmake or path.join(root, "frameworks", "Backports", "xmake.lua")
    local inventory = opt.inventory
    local facts = opt.facts or path.join(sdkfiles.shared_root(), opt.facts_key or sdkfiles.cache_key(sdk))
    local lines = {}
    if not os.isdir(facts) or not os.isdir(tools) or not os.isdir(src) then
        return nil
    end
    add_files(lines, tools, "tools")
    add_files(lines, src, "src")
    if os.isdir(modules) then
        add_files(lines, modules, "modules")
    end
    if not add_file(lines, xmake, "xmake") then
        return nil
    end
    if inventory and not add_file(lines, inventory, "inventory") then
        return nil
    end
    add_files(lines, facts, "facts")
    local names = opt.names or sdkfiles.framework_names(sdk)
    for _, name in ipairs(names) do
        table.insert(lines, "framework/" .. name)
        if not os.isfile(path.join(facts, name .. ".tsv")) or not os.isfile(path.join(facts, "install_names.tsv")) then
            return nil
        end
    end
    table.insert(lines, "grep=" .. hash.sha256("/usr/bin/grep"))
    for _, name in ipairs(ENVIRONMENT) do
        local value = opt.env and opt.env[name] or os.getenv(name)
        table.insert(lines, "env/" .. name .. "=" .. tostring(value or ""))
    end
    byteorder.sort(lines)
    return string.sub(hash.strhash128(table.concat(lines, "\n")), 1, 32)
end
