-- Where the trace layer writes its outputs: the trace directory under a framework's build directory, and the four files in it.

local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})

-- The name of the trace layer's directory under a framework's build directory.
local TRACE_DIR = "trace"

-- The trace directory of a framework.
function trace_dir(tree, fw)
    return path.join(layout.gen_dir(tree, fw), TRACE_DIR)
end

-- The stubs of a framework: the generated defaults, built only with CHARON_TRACE_DEFAULTS.
function defaults_file(tree, fw)
    return path.join(trace_dir(tree, fw), fw .. "Defaults.m")
end

-- The members the trace layer left out, with the reason each one is left out.
function skipped_file(tree, fw)
    return path.join(trace_dir(tree, fw), "skipped.tsv")
end

-- The skip reasons the trace layer recorded for a framework: api -> reason, as skipped.tsv gives them; {} when the trace layer has not
-- run for the framework.
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

-- One row per stub: the surface row it answers and the kind of member.
function stubs_file(tree, fw)
    return path.join(trace_dir(tree, fw), "stubs.tsv")
end

-- The class-object decision of every candidate class, with its reason.
function classes_file(tree, fw)
    return path.join(trace_dir(tree, fw), "classes.tsv")
end

-- The class-object decisions the trace layer wrote: class -> {generated = bool, reason = text}; {} when the trace layer has not run
-- for the framework (load_class_decisions of tools/gen.py@52253c0650).
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

-- The set of the surface keys the stubs file answers (its first column, one per stub row), or nil when the trace layer has not
-- written the file for the framework (the stub_keys of the scope).
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
