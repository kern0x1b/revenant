local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})

local TRACE_DIR = "trace"

function trace_dir(tree, fw)
    return path.join(layout.gen_dir(tree, fw), TRACE_DIR)
end

function defaults_file(tree, fw)
    return path.join(trace_dir(tree, fw), fw .. "Defaults.m")
end

function skipped_file(tree, fw)
    return path.join(trace_dir(tree, fw), "skipped.tsv")
end

function load_skip_reasons(tree, fw)
    local out = {}
    local text = files.read_text(skipped_file(tree, fw))
    if text then
        for _, row in ipairs(tsv.records(text)) do
            out[row.api] = row.reason
        end
    end
    return out
end

function stubs_file(tree, fw)
    return path.join(trace_dir(tree, fw), "stubs.tsv")
end

function classes_file(tree, fw)
    return path.join(trace_dir(tree, fw), "classes.tsv")
end

function load_class_decisions(tree, fw)
    local out = {}
    local text = files.read_text(classes_file(tree, fw))
    if text then
        for _, row in ipairs(tsv.records(text)) do
            out[row.class] = {generated = row.generated == "yes", reason = row.reason}
        end
    end
    return out
end

function load_stub_keys(tree, fw)
    local text = files.read_text(stubs_file(tree, fw))
    if text == nil then
        return nil
    end
    local out = {}
    local all = tsv.lines(text)
    for i = 2, #all do
        if all[i] ~= "" then
            out[tsv.fields(all[i])[1]] = true
        end
    end
    return out
end
