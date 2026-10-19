local protocol_headers = import("protocol_headers", {anonymous = true})
local emit = import("emit", {anonymous = true})
local layout = import("layout", {anonymous = true})

function run(args)
    assert(args.framework, "protocolheaders needs --framework")
    local fw = args.framework
    local files = protocol_headers.protocol_header_files(args.tree, fw)
    local count = 0
    for name, text in pairs(files) do
        emit.file(path.join(args.out or layout.gen_dir(args.tree, fw), name), text)
        count = count + 1
    end
    if count == 0 then
        print("protocolheaders: " .. fw .. " has no rows in spec/protocol-headers.tsv")
        return 1
    end
    print(string.format("protocolheaders %s: %d header(s)", fw, count))
    return 0
end
