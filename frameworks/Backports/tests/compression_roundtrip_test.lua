local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "Compression")

local function source_root(variable, suffix)
    local root = os.getenv(variable)
    assert(root and root ~= "", variable .. " must name the " .. suffix .. " source tree the Compression backport links against")
    return path.absolute(root)
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

function main()
    local lzfse = source_root("REVENANT_LZFSE_SOURCE", "lzfse")
    local lz4 = source_root("REVENANT_LZ4_SOURCE", "lz4")
    local xz = source_root("REVENANT_XZ_SOURCE", "xz")
    local work = path.join(os.tmpdir(), "compression-roundtrip")
    os.tryrm(work)
    os.mkdir(work)
    local include = shim(work, path.join(lzfse, "src"), lz4, xz)
    local lzfse_sources = {}
    for _, name in ipairs({"lzfse_decode.c", "lzfse_decode_base.c", "lzfse_encode.c", "lzfse_encode_base.c", "lzfse_fse.c", "lzvn_decode_base.c", "lzvn_encode_base.c"}) do
        table.insert(lzfse_sources, path.join(lzfse, "src", name))
    end
    local flags = {"-I" .. include, "-I" .. path.join(xz, "src", "liblzma", "api"), "-I" .. path.join(lzfse, "src"), "-I" .. path.join(lz4, "lib")}
    local backport = build(work, "backport_codec", table.join({path.join(TESTS, "compression", "backport_codec.c"), path.join(SRC, "CompressionBuffer.c"),
        path.join(lz4, "lib", "lz4.c"), stub_lzma(work)}, lzfse_sources), table.join(flags, {"-lz"}))
    local oracle = build(work, "oracle_codec", {path.join(TESTS, "compression", "oracle_codec.c")}, {"-lcompression"})

    local inputs = {
        {name = "text", bytes = string.rep("The quick brown fox jumps over the lazy dog. ", 500)},
        {name = "zeros", bytes = string.rep("\0", 65536)},
        {name = "short", bytes = "a"},
        {name = "mixed", bytes = (function ()
            local out = {}
            for i = 1, 20000 do out[i] = string.char((i * 2654435761) % 251) end
            return table.concat(out)
        end)()},
    }
    local failures = {}
    for _, input in ipairs(inputs) do
        local raw = path.join(work, input.name .. ".raw")
        io.writefile(raw, input.bytes)
        local backport_stream = path.join(work, input.name .. ".backport.lzfse")
        local native_stream = path.join(work, input.name .. ".native.lzfse")
        os.vrunv(backport, {"encode", raw, backport_stream})
        os.vrunv(oracle, {"encode", raw, native_stream})
        local back_native = path.join(work, input.name .. ".back-native.raw")
        local native_back = path.join(work, input.name .. ".native-back.raw")
        os.vrunv(oracle, {"decode", backport_stream, back_native})
        os.vrunv(backport, {"decode", native_stream, native_back})
        if not equal_files(raw, back_native) then table.insert(failures, input.name .. ": the backport's stream does not decode with macOS libcompression") end
        if not equal_files(raw, native_back) then table.insert(failures, input.name .. ": macOS libcompression's stream does not decode with the backport") end
    end

    local control = path.join(work, "corrupt.raw")
    local stream = io.readfile(path.join(work, "text.native.lzfse"), {encoding = "binary"})
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
    print("COMPRESSION_ROUNDTRIP_TEST passed")
end
