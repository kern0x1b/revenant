-- `swiftiface`: writes spec/<F>/swiftinterface.tsv, the Swift declarations of each Swift module of the SDK as its interface text states
-- them (swift_interface.lua reads the text). --sdk is the SDK folder. A module gets a shard when its spec folder exists (the folder
-- of its declaration shard); a module with no folder has none. One line per module. The surface model reads these rows for the
-- introductions the digester's dump does not carry (an extension's @available, a nested type's own) and for the members the dump
-- leaves out.

local emit = import("emit", {anonymous = true})
local files = import("files", {anonymous = true})
local layout = import("layout", {anonymous = true})
local swift_interface = import("swift_interface", {anonymous = true})

local SHARD_FILE = "swiftinterface.tsv"
local SUFFIX = ".swiftmodule"
local INTERFACE = "arm64e-apple-ios.swiftinterface"

-- The module a Swift interface file belongs to: its .swiftmodule folder's name.
local function module_of(filepath)
    local folder = files.parent_name(filepath)
    return (string.gsub(folder, "%.swiftmodule$", ""))
end

-- Returns the exit status: 0 when the shards are written.
function run(args)
    assert(args.sdk, "swiftiface needs --sdk: the iOS SDK folder the interface texts are read from")
    local root = path.join(args.tree, layout.constants().SNAP_ROOT)
    -- A module can have two interface texts: the framework's, and a re-export stub under usr/lib/swift. The one with the declarations wins.
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
