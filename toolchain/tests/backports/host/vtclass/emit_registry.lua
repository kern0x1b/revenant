local S = import("pystr", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})
local J = import("registry_json", {rootdir = os.scriptdir()})

function PROPERTY()
    return "@property"
end

function CLASS_ROW_STATUS()
    return "implemented"
end

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

local function texts_in_order(sdk_text)
    local out = {}
    for _, path in ipairs(V.sorted_keys(sdk_text)) do
        out[#out + 1] = sdk_text[path]
    end
    return out
end

function _availability()
    return import("availability", {rootdir = os.scriptdir()})
end

function _members()
    return import("members", {rootdir = os.scriptdir()})
end

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

function _introduction(sdk_text, class_name)
    local joined = table.concat(texts_in_order(sdk_text), "\n")
    local version, line = _availability().availability_of(joined, class_name)
    return version, (_file_holding(sdk_text, class_name) or "?") .. ":" .. line
end

function _file_holding(sdk_text, class_name)
    for _, path in ipairs(V.sorted_keys(sdk_text)) do
        if _availability().interface_at(sdk_text[path], class_name) ~= nil then
            return S.basename(path)
        end
    end
    return nil
end

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

function write(registry_dir, facts_dir, rows, order)
    local OURS = {class = true, method = true, property = true}
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
        local existing = {}
        if os.exists(path) then
            local tree = J.parse_tree(V.read_text(path))
            existing = tree.entries
            if existing == nil then
                V.fail("KeyError: 'entries'")
            end
        end
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
