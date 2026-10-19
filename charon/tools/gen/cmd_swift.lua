local swift = import("swift", {anonymous = true})
local emit = import("emit", {anonymous = true})
local sdk = import("sdk", {anonymous = true})

function run(args)
    assert(args.coordination, "--coordination (the corpus folder) is required")
    assert(args.sdk, "swift needs --sdk: the iPhoneOS SDK whose release names the corpus tables")
    local rows, matched, frameworks = swift.bucket(args.tree, args.coordination, sdk.discover(args.sdk).version)
    emit.file(swift.bucket_path(args.tree), swift.bucket_text(rows))
    print(string.format("swift: %d bucket rows, %d matched by the table (%d frameworks)", #rows, matched, frameworks))
    return 0
end
