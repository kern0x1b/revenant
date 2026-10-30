local checkout = import("@addon.revenant.checkout", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local ROOT = path.absolute(path.join(BACKPORTS, "..", ".."))
local SRC = path.join(BACKPORTS, "src", "Compression")

local function recipe_commit(package, label)
    local recipe = io.readfile(path.join(ROOT, "packages", package:sub(1, 1), package, "xmake.lua"))
    local commit = recipe:match('add_versions%("' .. label:gsub("%p", "%%%0") .. '", "(%x+)"%)')
    assert(commit, package .. " has no pinned commit for " .. label)
    return commit
end

local function sources()
    local lzfse, lz4, xz = os.getenv("REVENANT_LZFSE_SOURCE"), os.getenv("REVENANT_LZ4_SOURCE"), os.getenv("REVENANT_XZ_SOURCE")
    if lzfse and lz4 and xz then
        return path.absolute(lzfse), path.absolute(lz4), path.absolute(xz)
    end
    local into = path.join(os.projectdir(), ".cache", "compression-sources")
    checkout.pinned(into, {
        {name = "lzfse", url = "https://github.com/lzfse/lzfse.git", tag = "lzfse-1.0", commit = recipe_commit("lzfse", "lzfse-1.0"), sparse = {"src"}},
        {name = "lz4", url = "https://github.com/lz4/lz4.git", tag = "v1.9.2", commit = recipe_commit("lz4", "v1.9.2"), sparse = {"lib"}},
        {name = "xz", url = "https://github.com/tukaani-project/xz.git", tag = "v5.8.4", commit = recipe_commit("xz", "v5.8.4"), sparse = {"src/liblzma/api"}},
    })
    return path.join(into, "lzfse"), path.join(into, "lz4"), path.join(into, "xz")
end

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function macos_sdk()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
end

local function shim(work, lzfse, lz4, xz)
    local include = path.join(work, "include")
    os.mkdir(path.join(include, "zlib"))
    os.cp(path.join(macos_sdk(), "usr", "include", "zlib.h"), path.join(include, "zlib", "zlib.h"))
    os.ln(lzfse, path.join(include, "lzfse"))
    os.ln(path.join(lz4, "lib"), path.join(include, "lz4"))
    local api = path.join(xz, "src", "liblzma", "api")
    os.mkdir(path.join(include, "lzma"))
    os.cp(path.join(api, "lzma.h"), path.join(include, "lzma", "lzma.h"))
    for _, header in ipairs(os.files(path.join(api, "lzma", "*.h"))) do
        os.cp(header, path.join(include, "lzma", path.filename(header)))
    end
    return include
end

local function build(work, name, sources, extra)
    local output = path.join(work, name)
    local flags = {"-O1", "-isysroot", macos_sdk(), "-Wno-deprecated-declarations"}
    os.vrunv(clang(), table.join(flags, extra, sources, {"-o", output}))
    return output
end

local function stub_lzma(work)
    local file = path.join(work, "lzma_stub.c")
    io.writefile(file, table.concat({
        '#include <lzma.h>',
        'lzma_ret lzma_code(lzma_stream *s, lzma_action a) { (void)s; (void)a; return LZMA_PROG_ERROR; }',
        'lzma_ret lzma_easy_encoder(lzma_stream *s, uint32_t p, lzma_check c) { (void)s; (void)p; (void)c; return LZMA_PROG_ERROR; }',
        'lzma_ret lzma_stream_decoder(lzma_stream *s, uint64_t m, uint32_t f) { (void)s; (void)m; (void)f; return LZMA_PROG_ERROR; }',
        'void lzma_end(lzma_stream *s) { (void)s; }',
        'size_t lzma_stream_buffer_bound(size_t n) { return n; }',
        'lzma_ret lzma_easy_buffer_encode(uint32_t p, lzma_check c, const lzma_allocator *a, const uint8_t *i, size_t il, uint8_t *o, size_t *op, size_t os) { (void)p; (void)c; (void)a; (void)i; (void)il; (void)o; (void)op; (void)os; return LZMA_PROG_ERROR; }',
        ''
    }, "\n"))
    return file
end

local function equal_files(a, b)
    return io.readfile(a, {encoding = "binary"}) == io.readfile(b, {encoding = "binary"})
end

local function runs(program, args)
    local ok = false
    try {
        function ()
            os.vrunv(program, args)
            ok = true
        end,
        catch {
            function () ok = false end
        }
    }
    return ok
end

local function deterministic_bytes(count, seed)
    local out, state = {}, seed
    for i = 1, count do
        state = (state * 1103515245 + 12345) % 2147483648
        out[i] = string.char((state >> 16) & 0xff)
    end
    return table.concat(out)
end

function main()
    local lzfse, lz4, xz = sources()
    local work = workspace.fresh("compression-roundtrip")
    local include = shim(work, path.join(lzfse, "src"), lz4, xz)
    local lzfse_sources = {}
    for _, name in ipairs({"lzfse_decode.c", "lzfse_decode_base.c", "lzfse_encode.c", "lzfse_encode_base.c", "lzfse_fse.c", "lzvn_decode_base.c", "lzvn_encode_base.c"}) do
        table.insert(lzfse_sources, path.join(lzfse, "src", name))
    end
    local flags = {"-I" .. include, "-I" .. path.join(xz, "src", "liblzma", "api"), "-I" .. path.join(lzfse, "src"), "-I" .. path.join(lz4, "lib")}
    local backport = build(work, "backport_codec", table.join({path.join(TESTS, "compression", "backport_codec.c"), path.join(SRC, "CompressionBuffer.c"),
        path.join(lz4, "lib", "lz4.c"), stub_lzma(work)}, lzfse_sources), table.join(flags, {"-lz"}))
    local oracle = build(work, "oracle_codec", {path.join(TESTS, "compression", "oracle_codec.c")}, {"-lcompression"})

    local mixed = (function ()
        local out = {}
        for i = 1, 20000 do out[i] = string.char((i * 2654435761) % 251) end
        return table.concat(out)
    end)()
    local inputs = {
        {name = "text", bytes = string.rep("The quick brown fox jumps over the lazy dog. ", 500)},
        {name = "zeros", bytes = string.rep("\0", 65536)},
        {name = "short", bytes = "a"},
        {name = "mixed", bytes = mixed},
        {name = "long", bytes = string.rep(mixed, 15)},
        {name = "random", bytes = deterministic_bytes(200000, 2463534242)},
    }
    local failures = {}
    local function check(name, got, want, what)
        if not equal_files(want, got) then
            table.insert(failures, name .. ": " .. what)
        end
    end
    for _, input in ipairs(inputs) do
        local raw = path.join(work, input.name .. ".raw")
        io.writefile(raw, input.bytes, {encoding = "binary"})
        local function out(suffix) return path.join(work, input.name .. "." .. suffix) end

        os.vrunv(backport, {"encode", raw, out("backport.lzfse")})
        os.vrunv(oracle, {"encode", raw, out("oracle.lzfse")})
        os.vrunv(oracle, {"decode", out("backport.lzfse"), out("oracle-of-backport.raw")})
        check(input.name, out("oracle-of-backport.raw"), raw, "the backport's buffer stream does not decode with macOS libcompression")
        os.vrunv(backport, {"decode", out("oracle.lzfse"), out("backport-of-oracle.raw")})
        check(input.name, out("backport-of-oracle.raw"), raw, "macOS libcompression's buffer stream does not decode with the backport")

        os.vrunv(backport, {"stream-encode", raw, out("backport.stream.lzfse")})
        os.vrunv(oracle, {"stream-decode", out("backport.stream.lzfse"), out("oracle-stream-of-backport.raw")})
        check(input.name, out("oracle-stream-of-backport.raw"), raw, "the backport's stream does not decode with macOS libcompression's stream API")
        os.vrunv(oracle, {"decode", out("backport.stream.lzfse"), out("oracle-buffer-of-backport-stream.raw")})
        check(input.name, out("oracle-buffer-of-backport-stream.raw"), raw, "the backport's stream does not decode as a buffer with macOS libcompression")

        os.vrunv(oracle, {"stream-encode", raw, out("oracle.stream.lzfse")})
        os.vrunv(backport, {"stream-decode", out("oracle.stream.lzfse"), out("backport-stream-of-oracle.raw")})
        check(input.name, out("backport-stream-of-oracle.raw"), raw, "macOS libcompression's stream does not decode with the backport's stream API")
    end

    local control = path.join(work, "corrupt.raw")
    local stream = io.readfile(path.join(work, "text.oracle.lzfse"), {encoding = "binary"})
    local middle = math.floor(#stream / 2)
    local damage = {}
    for at = middle, middle + 15 do
        table.insert(damage, string.char(stream:byte(at) ~ 0xff))
    end
    io.writefile(control, stream:sub(1, middle - 1) .. table.concat(damage) .. stream:sub(middle + 16), {encoding = "binary"})
    local damaged = path.join(work, "corrupt.decoded")
    local decoded = runs(backport, {"decode", control, damaged})
    if decoded and equal_files(path.join(work, "text.raw"), damaged) then
        table.insert(failures, "negative control: a damaged stream decoded to the original, so the comparison proves nothing")
    end

    assert(#failures == 0, "the Compression backport and macOS libcompression disagree:\n  " .. table.concat(failures, "\n  "))
    os.tryrm(work)
    print("COMPRESSION_ROUNDTRIP_TEST passed")
end
