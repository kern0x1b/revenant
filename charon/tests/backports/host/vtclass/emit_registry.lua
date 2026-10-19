-- emit_registry.lua - EMITS THE VIDEOTOOLBOX REGISTRY ROWS AND THE FACTS FILE, from the SDK's own headers.
-- A MODULE: import("emit_registry", {rootdir = os.scriptdir()}); emit.lua calls build_rows and write.
-- Port of emit-registry.py, function for function, under the Python names. Python's import-by-path loaders
-- (_availability, _members) become import() of the same modules from this directory; the __file__ assertion
-- those loaders made has no counterpart, because a module is reached only by its name in this directory.
--
-- gen_body names used (code written against these; gen_body.lua is being ported by another agent):
--     gen_body.BRANCH_TABLE()        the shared branch table, as a table (Python's dict BRANCH_TABLE)
--     gen_body.load_branch_table()   the table load_branch_table() returns (Python's default path)
--     gen_body.branch_of(a, b)       the branch of a (class number, objc pointer) row
-- _is_cf is the only caller of these, and nothing in this module calls _is_cf.
--
-- sdk_text is Python's dict {path: text}. Both callers build it from a sorted glob, so Python's dict order
-- is path order; here the order is taken as byte order of the paths (sorted_keys), which gives the same
-- order for those callers.

local S = import("pystr", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})
local J = import("registry_json", {rootdir = os.scriptdir()})

-- Module constants --------------------------------------------------------------------------------------

function PROPERTY()
    return "@property"
end

function CLASS_ROW_STATUS()
    return "implemented"
end

-- Helpers -----------------------------------------------------------------------------------------------

-- Python's repr() of a str, for the ASCII names this module prints.
local function py_repr(s)
    local quote = "'"
    if string.find(s, "'", 1, true) and not string.find(s, '"', 1, true) then
        quote = '"'
    end
    local out = {quote}
    for i = 1, #s do
        local c = string.sub(s, i, i)
        local b = string.byte(c)
        if c == "\\" then
            out[#out + 1] = "\\\\"
        elseif c == quote then
            out[#out + 1] = "\\" .. c
        elseif c == "\n" then
            out[#out + 1] = "\\n"
        elseif c == "\r" then
            out[#out + 1] = "\\r"
        elseif c == "\t" then
            out[#out + 1] = "\\t"
        elseif b < 32 or b == 127 then
            out[#out + 1] = string.format("\\x%02x", b)
        else
            out[#out + 1] = c
        end
    end
    out[#out + 1] = quote
    return table.concat(out)
end

-- The texts of an sdk_text, in Python's dict order (path byte order).
local function texts_in_order(sdk_text)
    local out = {}
    for _, path in ipairs(V.sorted_keys(sdk_text)) do
        out[#out + 1] = sdk_text[path]
    end
    return out
end

-- Python's _availability(): availability.py, loaded from this directory.
function _availability()
    return import("availability", {rootdir = os.scriptdir()})
end

-- Python's _members(): members.py, loaded from this directory.
function _members()
    return import("members", {rootdir = os.scriptdir()})
end

-- Python's _is_cf(gen_body, prop): whether a property's type is a CF reference, from the compiler's answer
-- the way the store line asks. The branch table is loaded once when it is empty.
function _is_cf(gen_body, prop)
    local branch_table = gen_body.BRANCH_TABLE()
    local name = prop.type
    if prop.obj then
        name = name .. " *"
    end
    if V.count_entries(branch_table) == 0 then
        for key, value in pairs(gen_body.load_branch_table()) do
            branch_table[key] = value
        end
    end
    local row = branch_table[name] or branch_table[prop.type]
    if row == nil then
        V.fail(name .. ": the type probe has no row for " .. py_repr(name)
            .. " - run the probe before generating")
    end
    return gen_body.branch_of(table.unpack(row)) == "CF"
end

-- Python's _introduction(sdk_text, class_name): (ios version, "file:line") from availability_of() and
-- nothing else. Raises when the class has no availability; the error is raised from here unchanged.
function _introduction(sdk_text, class_name)
    local joined = table.concat(texts_in_order(sdk_text), "\n")
    local version, line = _availability().availability_of(joined, class_name)
    return version, (_file_holding(sdk_text, class_name) or "?") .. ":" .. line
end

-- Python's _file_holding(sdk_text, class_name): the basename of the first file (in path order) whose text
-- holds "@interface <class_name>" as re.search(r'@interface\s+' + re.escape(name) + r'\b') finds it.
function _file_holding(sdk_text, class_name)
    for _, path in ipairs(V.sorted_keys(sdk_text)) do
        if _availability().interface_at(sdk_text[path], class_name) ~= nil then
            return S.basename(path)
        end
    end
    return nil
end

-- Python's _header_line(sdk_text, class_name, needle): "file:line" of the declaration `needle` belongs to,
-- for the row's `source`. Not called by build_rows, and ported as written: the window is the 200 bytes
-- before the FIRST occurrence of the line, and 40 after it, which is what text.find(line) gives.
function _header_line(sdk_text, class_name, needle)
    for _, path in ipairs(V.sorted_keys(sdk_text)) do
        local text = sdk_text[path]
        local lines = S.split_newlines(text)
        for index, line in ipairs(lines) do
            if S.contains(line, needle) then
                local found = string.find(text, line, 1, true) - 1
                local window = string.sub(text, math.max(0, found - 200) + 1, found + 40)
                if S.contains(window, class_name) then
                    return S.basename(path) .. ":" .. index
                end
            end
        end
    end
    return nil
end

-- The rows and the facts file --------------------------------------------------------------------------

-- Python's build_rows(gen_body, sdk_text, protocols, classes, order): every row, as {release file, row}
-- pairs, in order. The members come from members_of(), the one derivation, so a row cannot describe a
-- member the value file does not implement. gen_body is not used here (as in the Python).
function build_rows(gen_body, sdk_text, protocols, classes, order)
    local rows = {}
    for _, class_name in ipairs(order) do
        local introduced, header
        try {
            function()
                introduced, header = _introduction(sdk_text, class_name)
            end,
            catch {
                function(err)
                    V.fail("ValueError: " .. tostring(err))
                end
            }
        }
        local release = "ios" .. S.split_on(introduced, ".")[1] .. ".json"
        local source = "SDK 26.2, " .. (header or "the class's own header")
        for _, entry in ipairs(_members().members_of(class_name).entries) do
            local kind, api = entry[1], entry[2]
            local reason, effect
            if kind == "class" then
                reason = "the release has no VTFrameProcessor framework: iOS 6.1.3 carries "
                    .. "VideoToolbox.framework at /System/Library/Frameworks with the whole "
                    .. "compression and decompression session API, and none of the seventeen "
                    .. "frame-processor classes on the armv7 cache ladder"
                effect = "the class exists, the release has no such class, and every member below is "
                    .. "answered from the port's own store"
            elseif kind == "method" then
                reason = "the designated initialiser of a class the release does not have; each argument "
                    .. "is stored under the property the SDK declares for it, resolved per class"
                effect = "constructs the object and puts each argument in the store under that property's "
                    .. "own name, so the value comes back out of the property's own accessor"
            else
                reason = "a property of a class the release does not have"
                effect = "answers from the port's own store under this property's name"
            end
            local row = J.new_object({
                {"introduced", introduced},
                {"minimum", "6.0"},
                {"status", CLASS_ROW_STATUS()},
                {"facts", "facts/VideoToolbox/FrameProcessorClasses.md"},
                {"api", api},
                {"kind", kind},
                {"reason", reason},
                {"effect", effect},
                {"source", source},
            })
            rows[#rows + 1] = {release, row}
        end
    end
    return rows
end

-- Python's write(registry_dir, facts_dir, rows, order): the group files, and the facts file every row
-- points at. MERGES: it writes only the rows it owns (kind class, method or property), replacing each
-- one in place and carrying every other row through unchanged. Returns {file name, row count} pairs.
function write(registry_dir, facts_dir, rows, order)
    local OURS = {class = true, method = true, property = true}
    -- groups: release -> its rows, in row order; group_names: the releases, in first-seen order
    local groups = {}
    local group_names = {}
    for _, pair in ipairs(rows) do
        local release, row = pair[1], pair[2]
        if groups[release] == nil then
            groups[release] = {}
            group_names[#group_names + 1] = release
        end
        groups[release][#groups[release] + 1] = row
    end
    if not os.isdir(registry_dir) then
        os.mkdir(registry_dir)
    end
    local written = {}
    for _, release in ipairs(V.sort_bytes(group_names)) do
        local entries = groups[release]
        local path = registry_dir .. "/" .. release
        -- ORDER IS PRESERVED: the existing order is not this file's to rearrange.
        local existing = {}
        if os.exists(path) then
            local tree = J.parse_tree(V.read_text(path))
            existing = tree.entries
            if existing == nil then
                V.fail("KeyError: 'entries'")
            end
        end
        -- mine: (kind, api) -> row; a later row with the same key replaces an earlier one (a Python dict)
        local mine = {}
        local mine_key = {}
        for _, e in ipairs(entries) do
            local key = e.kind .. "\0" .. e.api
            mine[key] = e
            mine_key[key] = {e.kind, e.api}
        end
        local merged = {}
        for _, row in ipairs(existing) do
            local key = nil
            if row.kind ~= nil and row.api ~= nil then
                key = row.kind .. "\0" .. row.api
            end
            if key ~= nil and mine[key] ~= nil then
                merged[#merged + 1] = mine[key]
                mine[key] = nil
            else
                merged[#merged + 1] = row
            end
        end
        -- the rows still owed, sorted by (kind, api)
        local owed = {}
        for key, e in pairs(mine) do
            owed[#owed + 1] = {mine_key[key][1], mine_key[key][2], e}
        end
        table.sort(owed, function(a, b)
            if a[1] ~= b[1] then
                return V.byte_less(a[1], b[1])
            end
            return V.byte_less(a[2], b[2])
        end)
        for _, item in ipairs(owed) do
            merged[#merged + 1] = item[3]
        end
        local document = J.new_object({
            {"framework", "VideoToolbox"},
            {"entries", merged},
        })
        V.write_file(path, J.write_tree(document) .. "\n")
        written[#written + 1] = {S.basename(path), #entries}
    end
    if not os.isdir(facts_dir) then
        os.mkdir(facts_dir)
    end
    local facts = facts_dir .. "/FrameProcessorClasses.md"
    local text = "# The VideoToolbox frame processor: " .. #order .. " classes and the members they carry\n\n" ..
    "Ranks of `coordination/corpus/band-frameworks.tsv`: VideoToolbox, LOAD-FAIL. iOS 6.1.3 carries\n" ..
    "`VideoToolbox.framework` at `/System/Library/Frameworks` with the whole compression and\n" ..
    "decompression session API on the armv7 cache ladder since 3.1.3. It carries none of the\n" ..
    "seventeen frame-processor classes, which SDK 26.2 marks `API_AVAILABLE(ios(26.0))` and which\n" ..
    "the 6.1.3 cache ladder does not export at any release.\n\n" ..
    "## What the port does with a class the release does not have\n\n" ..
    "Each class is a value object: an initialiser puts its arguments in a keyed store under the\n" ..
    "property the SDK declares for each of them, and each accessor answers from that store. A\n" ..
    "class property's value is kept on the class, because a class property's value belongs to the\n" ..
    "type rather than to an instance. A `CVPixelBufferRef` is kept in an ivar and retained, because\n" ..
    "the SDK declares `@property(nonatomic, readonly) CVPixelBufferRef buffer;` with no ownership\n" ..
    "annotation. A `CMTime` or `CMVideoDimensions` is an `NSValue` box.\n\n" ..
    "## What is NOT carried, and why\n\n" ..
    "`processorSupported` is declared on three of the classes and the SDK marks it\n" ..
    "`API_UNAVAILABLE(ios)`, so it is not iOS surface and carrying it would collide with the host's\n" ..
    "own header on the armv7 build. It is absent, and the registry says so where a reader will look\n" ..
    "for it rather than leaving the gap to be rediscovered.\n\n" ..
    "## The nine VTFrameProcessor methods this series does not carry\n\n" ..
    "`startSessionWithConfiguration:error:`, the four `processWith…` variants, `endSession`,\n" ..
    "`+supportedScaleFactorsForFrameWidth:frameHeight:` and\n" ..
    "`downloadConfigurationModelWithCompletionHandler:` need a device with a Neural Engine, which no\n" ..
    "armv7 release has. They are recorded absent with the reason, and the one that cannot report\n" ..
    "failure at all - `processWithCommandBuffer:parameters:` - is in `coordination/crutches.md`,\n" ..
    "because it is undetectable by the header's own design.\n\n" ..
    "## The members per class\n\n"
    for _, class_name in ipairs(order) do
        text = text .. "### " .. class_name .. "\n\n"
    end
    V.write_file(facts, text)
    return written
end
