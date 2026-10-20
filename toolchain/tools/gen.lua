local BOOLEAN_OPTIONS = {all = true, record = true, members = true, catalyst = true, doc = true, verify = true}
local VALUE_OPTIONS = {tree = true, framework = true, ledger = true, sdk = true, owned = true, measured = true,
                       ["ios-constants"] = true, repin = true, class = true, out = true, limit = true, selector = true,
                       ["catalyst-sdk"] = true, corpus = true, ["ipsw-cache"] = true, sdk16 = true,
                       ir = true, compare = true, dump = true, release = true, gate = true, rows = true, ["ledger-rows"] = true,
                       scope = true, headers = true, vfs = true, clang = true, ["swift-rendered"] = true, ["port-values"] = true}
local COMMANDS = {"input", "pin", "gen", "check", "trace", "diff", "sources", "doc", "scope", "protocols",
                  "functions", "objc", "swift", "swiftshard", "swiftmodel", "swiftcode", "roundtrip", "behaviour", "members",
                  "headers", "sdk", "surface", "swiftiface", "ledger", "worklist", "verify", "protocolheaders", "impl-index"}

local function parse(argv)
    local args = {}
    local i = 1
    while i <= #argv do
        local name = string.match(argv[i], "^%-%-(.+)$")
        assert(name, "expected an option, got " .. argv[i])
        local key = string.gsub(name, "%-", "_")
        if BOOLEAN_OPTIONS[name] then
            args[key] = true
            i = i + 1
        elseif VALUE_OPTIONS[name] then
            args[key] = argv[i + 1]
            assert(args[key], "option " .. argv[i] .. " needs a value")
            i = i + 2
        else
            error("unknown option " .. argv[i])
        end
    end
    return args
end

local FRAMEWORK = {input = true, pin = true, gen = true, check = true, trace = true, diff = true, doc = true, protocols = true,
                   functions = true, behaviour = true}
local EVERY_FRAMEWORK = {input = true, gen = true, check = true, trace = true, doc = true, protocols = true, functions = true}

local function known(command)
    for _, name in ipairs(COMMANDS) do
        if name == command then
            return true
        end
    end
    return false
end

function main(command, ...)
    if not known(command) then
        print("usage: xmake l tools/gen.lua <command> [--tree T] [options]; --tree T is the checkout to read and write (default: the one "
              .. "this script is in); commands: " .. table.concat(COMMANDS, ", "))
        os.exit(2)
    end
    local module = path.join(os.scriptdir(), "gen", "cmd_" .. command .. ".lua")
    if not os.isfile(module) then
        print("gen: " .. command .. " has no module (tools/gen/cmd_" .. command .. ".lua)")
        os.exit(2)
    end
    local args = parse({...})
    args.tree = args.tree or path.normalize(path.join(os.scriptdir(), ".."))
    if args.sdk then
        args.sdk = path.normalize(path.absolute(args.sdk))
    end
    assert(not FRAMEWORK[command] or args.framework or (args.all and EVERY_FRAMEWORK[command]),
           command .. " needs --framework" .. (EVERY_FRAMEWORK[command] and " (or --all)" or ""))
    local status = import("gen.cmd_" .. command, {rootdir = os.scriptdir(), anonymous = true}).run(args)
    if status ~= 0 then
        os.exit(status)
    end
end
