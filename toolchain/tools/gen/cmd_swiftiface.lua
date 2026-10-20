local emit = import("emit", {anonymous = true})
local files = import("files", {anonymous = true})
local layout = import("layout", {anonymous = true})
local swift_interface = import("swift_interface", {anonymous = true})

local SHARD_FILE = "swiftinterface.tsv"
local SUFFIX = ".swiftmodule"
local INTERFACE = "arm64e-apple-ios.swiftinterface"

local function module_of(filepath)
    local folder = files.parent_name(filepath)
    return (string.gsub(folder, "%.swiftmodule$", ""))
end

function run(args)
    assert(args.sdk, "swiftiface needs --sdk: the iOS SDK folder the interface texts are read from")
    local root = path.join(args.tree, "..", layout.constants().SNAP_ROOT)
    local best = {}
    for _, filepath in ipairs(files.glob(args.sdk .. "/**/" .. INTERFACE)) do
        local module = module_of(filepath)
        if string.sub(filepath, -#INTERFACE) == INTERFACE and string.find(filepath, SUFFIX, 1, true) then
            local text, count = swift_interface.shard_text(files.read_text(filepath), module)
            if best[module] == nil or count > best[module].count then
                best[module] = {text = text, count = count}
            end
        end
    end
    local modules = {}
    for module in pairs(best) do
        table.insert(modules, module)
    end
    table.sort(modules)
    local written, skipped, declarations = 0, 0, 0
    for _, module in ipairs(modules) do
        local folder = path.join(root, module)
        if os.isdir(folder) then
            emit.file(path.join(folder, SHARD_FILE), best[module].text)
            written = written + 1
            declarations = declarations + best[module].count
        else
            skipped = skipped + 1
        end
    end
    print(string.format("swiftiface: %d shards, %d declarations; %d interface modules with no spec folder", written, declarations, skipped))
    return 0
end
