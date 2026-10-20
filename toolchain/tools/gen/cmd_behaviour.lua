local behaviour = import("behaviour", {anonymous = true})
local order = import("order", {anonymous = true})
local emit = import("emit", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})

local function chosen_methods(args, corpus, sdk_release, fw)
    local limit = args.limit and tonumber(args.limit) or behaviour.default_limit()
    assert(limit, "--limit needs a number")
    local out = {}
    for _, m in ipairs(behaviour.methods(corpus, sdk_release, fw)) do
        if (args.selector == nil or m.selector == args.selector) and #out < limit then
            table.insert(out, m)
        end
    end
    return out
end

function run(args)
    local fw = args.framework
    local corpus = args.coordination
    local cache = args.ipsw_cache
    assert(corpus, "--coordination (the corpus folder) is required")
    assert(cache, "--ipsw-cache (the on-disk iOS cache of the --sdk release) is required")
    assert(args.sdk, "behaviour needs --sdk: the iPhoneOS SDK whose release names the corpus tables")
    local sdk_release = sdk_info.discover(args.sdk).version
    local heavy = behaviour.heavy_path(corpus)
    local methods = chosen_methods(args, corpus, sdk_release, fw)
    local pages, done, failed = {}, 0, 0
    for _, m in ipairs(methods) do
        local state = behaviour.new_summary()
        local status, seconds, peak, notes = behaviour.disassemble(heavy, cache, m.address, function(line)
            behaviour.add_line(state, line)
        end)
        print(string.format("cost\t%s\t-[%s %s]\t%s\t%.2f s\t%.0f MB\texit %d", fw, m.cls, m.selector, m.address, seconds, peak, status))
        if status == 0 then
            done = done + 1
            pages[m.cls] = pages[m.cls] or {}
            table.insert(pages[m.cls], {section = m.section, selector = m.selector, address = m.address, summary = state})
        else
            failed = failed + 1
            io.stderr:write(string.format("error: ipsw failed on -[%s %s] (exit %d)\n", m.cls, m.selector, status))
            for _, note in ipairs(notes) do
                io.stderr:write("error:   " .. note .. "\n")
            end
        end
    end
    local files = behaviour.page_files(corpus, sdk_release, fw)
    local names = {}
    for cls in pairs(pages) do
        table.insert(names, cls)
    end
    for _, cls in ipairs(order.strings(names)) do
        emit.file(behaviour.page_path(fw, files, cls), behaviour.page_text(fw, cls, pages[cls], sdk_release))
    end
    print(string.format("behaviour %s: %d methods, %d summarised, %d failed", fw, #methods, done, failed))
    return failed > 0 and 1 or 0
end
