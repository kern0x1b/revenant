local ORDER = {"crc32", "sha256", "fnv64", "sort", "list", "geometry", "matrix", "text"}

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "scripts")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("devtime", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local flags = {"-O2", "-ffreestanding", "-fno-builtin", "-fno-stack-protector", "-fno-vectorize", "-fno-slp-vectorize"}
    local clang = path.join(e.llvmbin, "clang")
    local armv7 = {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk}

    local kernels = o("kernels-arm64.dylib")
    corpus.ios(e, table.join(flags, {"-dynamiclib", "-install_name", "@rpath/libkernels.dylib", path.join(here, "kernels.c"), "-o", kernels}))
    os.execv(e.xlate, {"--output", o("lifted.bc"), "--layout", o("layout.txt"), "--state-header", o("xl_state.h"), kernels})
    os.execv(clang, {"-target", "armv7-apple-ios6.0", "-marm", "-O2", "-c", o("lifted.bc"), "-o", o("lifted.o")})

    local addresses = {}
    for _, line in ipairs(os.iorunv("nm", {"-gU", kernels}):split("\n")) do
        local fields = line:split("%s+")
        if #fields == 3 and fields[3]:startswith("_k_") then
            addresses[fields[3]:sub(4)] = tonumber(fields[1], 16) + 0x10000000
        end
    end
    local names, values = {}, {}
    for _, name in ipairs(ORDER) do
        table.insert(names, "\"" .. name .. "\"")
        table.insert(values, string.format("0x%xu", assert(addresses[name], "kernels.c exports no k_" .. name)))
    end
    io.writefile(o("kernel_addrs.h"), string.format("static const unsigned kernel_count = %d;\nstatic const char *const kernel_names[] = {%s};\nstatic const uint32_t kernel_addrs[] = {%s};\n",
                                                    #ORDER, table.concat(names, ", "), table.concat(values, ", ")))

    os.execv(clang, table.join(armv7, flags, {"-c", path.join(here, "kernels.c"), "-o", o("kernels-native.o")}))
    os.execv(clang, table.join(armv7, {"-O2", "-c", path.join(here, "native_run.c"), "-o", o("native_run.o")}))
    os.execv(clang, table.join(armv7, {"-O2", "-I", out, "-c", path.join(here, "devtime.c"), "-o", o("devtime.o")}))

    local ok, log = corpus.run("xcrun", table.join({"clang", "-target", "armv7-apple-ios6.0", "-isysroot", e.sdk, "-fuse-ld=" .. e.ld, "-Wl,-no_pie"},
                                                   io.readfile(o("layout.txt")):split("%s+"),
                                                   {o("lifted.o"), o("kernels-native.o"), o("native_run.o"), o("devtime.o"), "-o", o("devtime")}), o("link.log"))
    for _, line in ipairs(log:split("\n")) do
        if not line:find("incompatible-sysroot", 1, true) then
            print("%s", line)
        end
    end
    if not ok then
        corpus.fail("linking devtime failed")
    end
    os.execv(e.ldid, {"-S", o("devtime")})
    os.execv("file", {o("devtime")})
    print("built %s", o("devtime"))
    return o("devtime")
end
