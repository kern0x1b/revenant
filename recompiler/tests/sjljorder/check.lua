local RUNS = 6
local PHIS = 12

local CHAINS = {
    {pad = "pad1", from = {{block = "entry", prefix = "a"}, {block = "n1", prefix = "b"}}},
    {pad = "pad2", from = {{block = "n2", prefix = "c"}, {block = "n3", prefix = "d"}}}
}

local function module_text()
    local lines = {"declare i64 @val()", "declare void @may_throw(i64)", "declare void @use(i64)", "declare i32 @__gxx_personality_sj0(...)", "",
                   "define void @f() personality ptr @__gxx_personality_sj0 {"}
    local following = {entry = "n1", n1 = "n2", n2 = "n3", n3 = "done"}
    for _, chain in ipairs(CHAINS) do
        for _, source in ipairs(chain.from) do
            table.insert(lines, source.block .. ":")
            for index = 0, PHIS - 1 do
                table.insert(lines, string.format("  %%%s%d = call i64 @val()", source.prefix, index))
            end
            table.insert(lines, string.format("  invoke void @may_throw(i64 %%%s0) to label %%%s unwind label %%%s", source.prefix, following[source.block], chain.pad))
        end
    end
    table.insert(lines, "done:")
    table.insert(lines, "  ret void")
    for _, chain in ipairs(CHAINS) do
        table.insert(lines, chain.pad .. ":")
        for index = 0, PHIS - 1 do
            table.insert(lines, string.format("  %%%s.p%d = phi i64 [ %%%s%d, %%%s ], [ %%%s%d, %%%s ]", chain.pad, index, chain.from[1].prefix, index, chain.from[1].block,
                                              chain.from[2].prefix, index, chain.from[2].block))
        end
        table.insert(lines, string.format("  %%%s.lp = landingpad { ptr, i32 } cleanup", chain.pad))
        for index = 0, PHIS - 1 do
            table.insert(lines, string.format("  call void @use(i64 %%%s.p%d)", chain.pad, index))
        end
        table.insert(lines, string.format("  resume { ptr, i32 } %%%s.lp", chain.pad))
    end
    table.insert(lines, "}")
    return table.concat(lines, "\n") .. "\n"
end

local function phis_by_block(ir)
    local counts, block = {}, nil
    for line in ir:gmatch("[^\n]+") do
        block = line:match("^([%w%._]+):") or block
        if block and line:find("= phi i64", 1, true) then
            counts[block] = (counts[block] or 0) + 1
        end
    end
    return counts
end

function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local e
    e, out = corpus.setup("sjljorder", out)
    local source = path.join(out, "pads.ll")
    io.writefile(source, module_text())
    local clang = path.join(e.llvmbin, "clang")
    local flags = {"-target", "armv7-apple-ios6.0", "-isysroot", e.sdk, "-O2", "-w", "-mthumb"}

    local optimized = path.join(out, "pads.opt.ll")
    os.tryrm(optimized)
    corpus.output(clang, table.join(flags, {"-x", "ir", "-S", "-emit-llvm", source, "-o", optimized}), path.join(out, "pads.opt.log"))
    local ir = os.isfile(optimized) and io.readfile(optimized) or ""
    local counts = phis_by_block(ir)
    for _, chain in ipairs(CHAINS) do
        local phis = counts[chain.pad] or 0
        if not ir:find("landingpad", 1, true) or phis < PHIS then
            corpus.fail("the optimizer left %d PHIs in the landing pad %s of the check's function, fewer than the %d it needs: the check no longer exercises the demotion of the PHIs of a landing pad",
                        phis, chain.pad, PHIS)
        end
    end

    local seen, order = {}, {}
    for run = 1, RUNS do
        local object = path.join(out, string.format("pads-%d.o", run))
        os.tryrm(object)
        corpus.output(clang, table.join(flags, {"-x", "ir", "-c", source, "-o", object}), path.join(out, string.format("pads-%d.log", run)))
        if not os.isfile(object) then
            corpus.fail("the compile %d of the check's function wrote no object %s", run, object)
        end
        local digest = hash.sha256(object)
        if not seen[digest] then
            seen[digest] = 0
            table.insert(order, digest)
        end
        seen[digest] = seen[digest] + 1
    end
    if #order ~= 1 then
        local counts = {}
        for _, digest in ipairs(order) do
            table.insert(counts, string.format("%d x %s", seen[digest], digest:sub(1, 12)))
        end
        corpus.fail("%d compiles of the same bitcode for armv7 iOS gave %d different objects (%s): the backend demotes the PHIs of a landing pad in the order of their addresses " ..
                    "(SjLjEHPrepare), so the stack slots and the code differ from run to run. The llvm package lacks packages/l/llvm/patches/llvm-sjlj-demote-phis-in-block-order.patch",
                    RUNS, #order, table.concat(counts, ", "))
    end
    print("ok: %d compiles of a function with %d PHIs in each of two landing pads give one object", RUNS, PHIS)
end
