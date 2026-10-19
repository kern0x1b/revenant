-- test_gen_body.lua - checks gen_body on the declarations whose spelling broke it, before anything is generated
-- from it. A port of test-gen-body.py: the same assertions, the same printed lines, the same exit status.
--
-- The star was absorbed by the pattern's own `\*?`, so a property the SDK writes `NSIndexSet*` was read as a
-- scalar and generated as a by-value return of an interface type. The SDK writes both spellings, so both are
-- here.
--
--     xmake l test_gen_body.lua        (VT_SDK set: also the SDK checks, run through the heavy queue)

local G = import("gen_body", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})

local HERE = os.scriptdir()

-- Python's repr() for the values the messages print: None, True/False, str, and a list of str.
local function py_repr(v)
    if v == nil then return "None" end
    if v == true then return "True" end
    if v == false then return "False" end
    if type(v) == "table" then
        local parts = {}
        for i, item in ipairs(v) do parts[i] = py_repr(item) end
        return "[" .. table.concat(parts, ", ") .. "]"
    end
    local s = tostring(v)
    local quote = "'"
    if s:find("'", 1, true) and not s:find('"', 1, true) then quote = '"' end
    local out = {quote}
    for i = 1, #s do
        local c = s:sub(i, i)
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

-- Python's %s of a value that may be None, True or False.
local function py_str(v)
    if v == nil then return "None" end
    if v == true then return "True" end
    if v == false then return "False" end
    return tostring(v)
end

-- Python str.strip() on ASCII.
local function strip_ws(s)
    return (s:gsub("^[ \t\n\r\f\v]+", ""):gsub("[ \t\n\r\f\v]+$", ""))
end

-- Python str.splitlines()[0] for text whose line breaks are \n (the only break the generated bodies contain).
local function first_line(s)
    local p = s:find("[\n\r\v\f\28\29\30]")
    if p then return s:sub(1, p - 1) end
    return s
end

-- Python's s.split("\n"), as a list of lines.
local function lines_of(s)
    local out, start = {}, 1
    while true do
        local p = s:find("\n", start, true)
        if not p then
            out[#out + 1] = s:sub(start)
            break
        end
        out[#out + 1] = s:sub(start, p - 1)
        start = p + 1
    end
    return out
end

-- The test's own copy of  (\w+):\s*\(([^)]*)\)\s*(\w+)  (findall), as the Python writes it inline.
-- Returns {word, type, arg} triples.
local function piece_triples(text)
    local out = {}
    local function is_word(c)
        if c == "" then return false end
        local b = string.byte(c)
        return (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or b == 95
    end
    local function is_space(c)
        return c == " " or c == "\t" or c == "\n" or c == "\r" or c == "\f" or c == "\v"
    end
    local function skip(i)
        while is_space(text:sub(i, i)) do i = i + 1 end
        return i
    end
    local i = 1
    while i <= #text do
        local matched = false
        if is_word(text:sub(i, i)) then
            local t = i
            while is_word(text:sub(t, t)) do t = t + 1 end
            if text:sub(t, t) == ":" then
                local k = skip(t + 1)
                if text:sub(k, k) == "(" then
                    local close = text:find(")", k + 1, true)
                    if close then
                        local r = skip(close + 1)
                        if is_word(text:sub(r, r)) then
                            local u = r
                            while is_word(text:sub(u, u)) do u = u + 1 end
                            out[#out + 1] = {text:sub(i, t - 1), text:sub(k + 1, close - 1), text:sub(r, u - 1)}
                            i = u
                            matched = true
                        end
                    end
                end
            end
        end
        if not matched then i = i + 1 end
    end
    return out
end

-- Python's open(f) iteration: each line keeps its "\n" (text mode, so CR and CRLF become "\n").
local function lines_keeping_newline(path)
    local text = V.read_text(path)
    local out, start = {}, 1
    while start <= #text do
        local p = text:find("\n", start, true)
        if not p then
            out[#out + 1] = text:sub(start)
            break
        end
        out[#out + 1] = text:sub(start, p)
        start = p + 1
    end
    return out
end

local function split_tab(s)
    local out, start = {}, 1
    while true do
        local p = s:find("\t", start, true)
        if not p then
            out[#out + 1] = s:sub(start)
            break
        end
        out[#out + 1] = s:sub(start, p - 1)
        start = p + 1
    end
    return out
end

-- Python's glob.glob(join(headers, "*.h")) sorted: the absolute paths in byte order.
local function sorted_headers(dir)
    return V.sort_bytes(os.files(dir .. "/*.h"))
end

-- One test case: the declaration, the expected name, type, obj, class, getter.
local CASES = {
    {'@property (nonatomic, readonly) NSIndexSet* supportedRevisions;',
     "supportedRevisions", "NSIndexSet", true, false, nil},
    {'@property (nonatomic, readonly) NSIndexSet * supportedRevisions;',
     "supportedRevisions", "NSIndexSet", true, false, nil},
    {'@property (nonatomic, readonly) NSArray<NSNumber *> * frameSupportedPixelFormats '
     .. 'NS_REFINED_FOR_SWIFT;',
     "frameSupportedPixelFormats", "NSArray<NSNumber *>", true, false, nil},
    {'@property (nonatomic, readonly) NSDictionary<NSString *, id> * sourcePixelBufferAttributes;',
     "sourcePixelBufferAttributes", "NSDictionary<NSString *, id>", true, false, nil},
    {'@property (class, nonatomic, readonly, getter=isSupported) BOOL supported;',
     "supported", "BOOL", false, true, "isSupported"},
    {'@property (nonatomic, readonly) NSInteger frameWidth;',
     "frameWidth", "NSInteger", false, false, nil},
    {'@property (nonatomic, readonly) float configurationModelPercentageAvailable;',
     "configurationModelPercentageAvailable", "float", false, false, nil},
    {'@property (nonatomic, readonly) CMVideoDimensions maximumDimensions;',
     "maximumDimensions", "CMVideoDimensions", false, false, nil},
    {'@property (nonatomic, readonly) CMTime presentationTimeStamp;',
     "presentationTimeStamp", "CMTime", false, false, nil},
    -- A CFTypeRef is NOT an object property and NOT a scalar either: it is a reference the accessor
    -- retains out of the store, which is the branch that wanted CVPixelBufferRetain.
    {'@property (nonatomic, readonly) CVPixelBufferRef buffer;',
     "buffer", "CVPixelBufferRef", false, false, nil},
    -- the SDK's own spelling of an absent-on-iOS property: the strip has to leave the name behind.
    -- The nested parens here are the point: API_DEPRECATED_WITH_REPLACEMENT("isSupported", macos(15.4,
    -- 26.0)) used to leave a trailing ')' and the property vanished from the parse altogether.
    {'@property (class, nonatomic, readonly) Boolean processorSupported '
     .. 'API_DEPRECATED_WITH_REPLACEMENT("isSupported", macos(15.4, 26.0)) API_UNAVAILABLE(ios);',
     "processorSupported", "Boolean", false, true, nil},
}

-- The one-line form of an odict used in the expected-value tables below.
local function props(text)
    return G.props_of(text)
end

-- The SDK declaration of the selector whose pieces differ from its argument names (VTFrameProcessor_
-- FrameRateConversion.h:166-171), as the Python test holds it.
local SDK_DECLARATION = table.concat({
    "- (nullable instancetype) initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame",
    "                                                                 nextFrame:(VTFrameProcessorFrame *)nextFrame",
    "                                                                 opticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)opticalFlow",
    "                                                          interpolationPhase:(NSArray<NSNumber *> *) interpolationPhase",
    "                                                            submissionMode:(VTFrameRateConversionParametersSubmissionMode)submissionMode",
    "                                                         destinationFrames:(NSArray<VTFrameProcessorFrame *> *)destinationFrame NS_REFINED_FOR_SWIFT;",
}, "\n")

-- The branch each argument type must take, per the SDK's own types. A type the SDK adds has no entry, and the
-- test is red until someone says which branch it takes.
local EXPECTED_BRANCH = {
    CVPixelBufferRef = "CF",
    CMTime = "struct",
    OSType = "scalar",
    NSInteger = "scalar",
    BOOL = "scalar",
    float = "scalar",
    Boolean = "scalar",
    ["NSArray<NSNumber *> *"] = "object",
    ["NSArray<VTFrameProcessorFrame *> *"] = "object",
    ["VTFrameProcessorFrame *"] = "object",
    ["VTFrameProcessorFrame * _Nullable"] = "object",
    ["VTFrameProcessorOpticalFlow *"] = "object",
    ["VTFrameProcessorOpticalFlow * _Nullable"] = "object",
    VTMotionBlurConfigurationQualityPrioritization = "scalar",
    VTMotionBlurConfigurationRevision = "scalar",
    VTFrameRateConversionParametersSubmissionMode = "scalar",
    VTFrameRateConversionConfigurationQualityPrioritization = "scalar",
    VTFrameRateConversionConfigurationRevision = "scalar",
    VTOpticalFlowConfigurationQualityPrioritization = "scalar",
    VTOpticalFlowConfigurationRevision = "scalar",
    VTOpticalFlowParametersSubmissionMode = "scalar",
    VTSuperResolutionScalerConfigurationQualityPrioritization = "scalar",
    VTSuperResolutionScalerConfigurationRevision = "scalar",
    VTSuperResolutionScalerConfigurationInputType = "scalar",
    VTSuperResolutionScalerParametersSubmissionMode = "scalar",
    VTTemporalNoiseFilterConfigurationQualityPrioritization = "scalar",
    VTTemporalNoiseFilterConfigurationRevision = "scalar",
    VTLowLatencyFrameInterpolationConfigurationQualityPrioritization = "scalar",
    VTLowLatencyFrameInterpolationConfigurationRevision = "scalar",
    VTLowLatencyFrameInterpolationParametersSubmissionMode = "scalar",
    VTLowLatencySuperResolutionScalerConfigurationQualityPrioritization = "scalar",
    VTLowLatencySuperResolutionScalerConfigurationRevision = "scalar",
    VTLowLatencySuperResolutionScalerParametersSubmissionMode = "scalar",
    VTMotionBlurParametersSubmissionMode = "scalar",
    id = "object",
}

-- The Python's set of property names passed as `properties` to init_body: a Lua odict with those names.
local function name_set(names)
    local od = G.odict_new()
    for _, n in ipairs(names) do G.odict_set(od, n, true) end
    return od
end

local function run_checks()
    local bad = {}

    for _, case in ipairs(CASES) do
        local declaration, name, type_, obj, is_class, getter =
            case[1], case[2], case[3], case[4], case[5], case[6]
        local got = props(declaration)
        if not G.odict_has(got, name) then
            bad[#bad + 1] = declaration .. " -> no property parsed at all"
        else
            local p = G.odict_get(got, name)
            local fields = {{"type", p.type, type_}, {"obj", p.obj, obj}, {"class", p.class, is_class},
                            {"getter", p.getter, getter}}
            for _, f in ipairs(fields) do
                if f[2] ~= f[3] then
                    bad[#bad + 1] = string.format("%s -> %s is %s, wanted %s",
                        declaration, f[1], py_repr(f[2]), py_repr(f[3]))
                end
            end
            print(string.format("  %-34s %-30s obj=%-5s class=%-5s getter=%s",
                name, p.type, py_str(p.obj), py_str(p.class), py_str(p.getter)))
        end
    end

    -- and the accessor it generates for the two spellings of the same property must be the SAME, or the
    -- port would have one accessor for the spaced spelling and another for the unspaced one
    local spaced = G.body("supportedRevisions", G.odict_get(
        props('@property (nonatomic, readonly) NSIndexSet * supportedRevisions;'), "supportedRevisions"))
    local unspaced = G.body("supportedRevisions", G.odict_get(
        props('@property (nonatomic, readonly) NSIndexSet* supportedRevisions;'), "supportedRevisions"))
    if spaced ~= unspaced then
        bad[#bad + 1] = "the two spellings generate different accessors:\n" .. spaced .. "\n" .. unspaced
    else
        print("  both spellings generate one accessor: " .. strip_ws(first_line(spaced)))
    end

    -- The generated accessor is checked as TEXT, not only for agreeing with itself: a doubled star in the cast
    -- is `(NSArray<NSNumber *> * *)`, which ARC rejects, and only the exact text shows it.
    local EXPECTED = {
        ["object"] = "CHARON_VALUE_PROPERTY(NSIndexSet *, supportedRevisions)\n",
        ["class-object"] = "+ (NSIndexSet *)supportedRevisions\n{\n"
            .. "    return (NSIndexSet *)CharonValueStoreOfClass([self class])"
            .. "[@\"supportedRevisions\"];\n}\n",
        ["scalar"] = "CHARON_SCALAR_PROPERTY(NSInteger, frameWidth)\n",
    }
    local shapes = {
        {"object", G.odict_get(props('@property (nonatomic, readonly) NSIndexSet* supportedRevisions;'),
                               "supportedRevisions")},
        {"class-object", G.odict_get(props('@property (class, nonatomic, readonly) NSIndexSet* supportedRevisions;'),
                                     "supportedRevisions")},
        {"scalar", G.odict_get(props('@property (nonatomic, readonly) NSInteger frameWidth;'), "frameWidth")},
    }
    for _, shape in ipairs(shapes) do
        local name, prop = shape[1], shape[2]
        local got
        if name ~= "scalar" then
            got = G.body(prop.getter or "supportedRevisions", prop)
        else
            got = G.body("frameWidth", prop)
        end
        if got ~= EXPECTED[name] then
            bad[#bad + 1] = string.format("the %s accessor is not what it should be:\n  got      %s\n  expected %s",
                name, py_repr(got), py_repr(EXPECTED[name]))
        else
            print(string.format("  %-13s accessor exact: %s", name, strip_ws(first_line(got))))
        end
    end

    -- And the exclusion is a RULE, not a side effect of a regex: parse() must leave every property the SDK
    -- marks API_UNAVAILABLE(ios) out of the class, and name it.
    local sdk = os.getenv("VT_SDK") or ""
    if sdk == "" then
        print("  VT_SDK unset: the API_UNAVAILABLE(ios) rule is NOT checked here")
    else
        local headers = sdk .. "/System/Library/Frameworks/VideoToolbox.framework/Headers"
        local pieces = {}
        for _, f in ipairs(sorted_headers(headers)) do pieces[#pieces + 1] = V.read_text(f) end
        local text = table.concat(pieces, "\n")
        local _, allclasses = G.parse(text)
        local excluding = {}
        for _, c in ipairs(V.sorted_keys(allclasses)) do
            if #allclasses[c].unavailable_ios > 0 then excluding[#excluding + 1] = c end
        end
        local wanted = {"VTFrameRateConversionConfiguration", "VTMotionBlurConfiguration",
                        "VTOpticalFlowConfiguration"}
        local same = #excluding == #wanted
        for i = 1, #wanted do
            if excluding[i] ~= wanted[i] then same = false end
        end
        if not same then
            bad[#bad + 1] = "API_UNAVAILABLE(ios) excluded by " .. py_repr(excluding)
                .. ", wanted the three classes the SDK declares it on"
        end
        for _, cls in ipairs(excluding) do
            local entry = allclasses[cls]
            if not (#entry.unavailable_ios == 1 and entry.unavailable_ios[1] == "processorSupported") then
                bad[#bad + 1] = cls .. " recorded " .. py_repr(entry.unavailable_ios)
            end
            if G.odict_has(entry.own, "processorSupported") then
                bad[#bad + 1] = cls .. " carried processorSupported"
            end
            print(string.format("  %-46s excludes %s (API_UNAVAILABLE(ios))", cls,
                table.concat(entry.unavailable_ios, ",")))
        end
    end

    -- THE SELECTOR PIECE AND THE ARGUMENT NAME ARE NOT ALWAYS THE SAME WORD (VTFrameProcessor_FrameRateConversion.h).
    local pieces = piece_triples(G.strip(SDK_DECLARATION))
    local expected_pieces = {"initWithSourceFrame", "nextFrame", "opticalFlow", "interpolationPhase",
                             "submissionMode", "destinationFrames"}
    local expected_names = {"sourceFrame", "nextFrame", "opticalFlow", "interpolationPhase", "submissionMode",
                            "destinationFrame"}
    local got_pieces, got_names = {}, {}
    for i, pt in ipairs(pieces) do
        got_pieces[i] = pt[1]
        got_names[i] = pt[3]
    end
    if py_repr(got_pieces) ~= py_repr(expected_pieces) then
        bad[#bad + 1] = "the selector pieces are " .. py_repr(got_pieces) .. ", wanted " .. py_repr(expected_pieces)
    end
    if py_repr(got_names) ~= py_repr(expected_names) then
        bad[#bad + 1] = "the argument names are " .. py_repr(got_names) .. ", wanted " .. py_repr(expected_names)
    end
    local last = pieces[#pieces]
    print(string.format("  the declaration yields %d pieces, the last two differing: %s / %s",
        #pieces, py_repr(last[1]), py_repr(last[3])))

    -- and the declaration built from them must spell the SDK's selector, ending in destinationFrames:
    local selector_parts = {}
    for i, pt in ipairs(pieces) do selector_parts[i] = pt[1] .. ":" end
    local selector = table.concat(selector_parts)
    local ending = "destinationFrames:"
    if selector:sub(-#ending) ~= ending then
        bad[#bad + 1] = "the built selector ends " .. py_repr(selector:sub(-24))
            .. ", wanted it to end with destinationFrames:"
    end
    local arguments = {}
    for i, pt in ipairs(pieces) do arguments[i] = {pt[3], pt[2], pt[1]} end
    local signature = G.init_signature(selector, arguments, "instancetype")
    if not signature:find("destinationFrames:(NSArray<VTFrameProcessorFrame *> *)destinationFrame", 1, true) then
        bad[#bad + 1] = "the declaration does not spell the SDK's last piece:\n" .. signature
    end
    local last_piece_line
    for _, line in ipairs(lines_of(signature)) do
        if line:find("destinationFrames", 1, true) then
            last_piece_line = strip_ws(line)
            break
        end
    end
    print("  the declaration's last piece: " .. last_piece_line)

    -- ONE TEST PER BRANCH of the initialiser's store line, because the branch is chosen by the argument's TYPE.
    local SCALAR_ARGS = {{"frameWidth", "NSInteger", "frameWidth"},
                         {"frameHeight", "NSInteger", "frameHeight"},
                         {"usePrecomputedFlow", "BOOL", "usePrecomputedFlow"}}
    local CF_ARG = {{"buffer", "CVPixelBufferRef", "buffer"}}
    local STRUCT_ARG = {{"presentationTimeStamp", "CMTime", "presentationTimeStamp"}}
    local branch_cases = {
        {"a scalar goes in the keyed store", SCALAR_ARGS,
         '    CharonValueSet(self, @(frameWidth), @"frameWidth");'},
        {"a CFTypeRef goes in an ivar, retained", CF_ARG,
         '    if (self->_buffer)\n        CFRetain(self->_buffer);'},
        {"a struct is boxed, which is what getValue: reads", STRUCT_ARG,
         'CharonValueSet(self, [NSValue valueWithBytes:&boxed objCType:@encode(CMTime)], @"presentationTimeStamp");'},
    }
    for _, bc in ipairs(branch_cases) do
        local label, arg, wanted = bc[1], bc[2], bc[3]
        local body_text = G.init_body("initWithBuffer:presentationTimeStamp:", arg,
            name_set({"buffer", "presentationTimeStamp", "frameWidth", "frameHeight", "usePrecomputedFlow"}), nil)
        if not body_text:find(wanted, 1, true) then
            bad[#bad + 1] = label .. ": the body has no " .. py_repr(wanted) .. "\n" .. body_text
        else
            print(string.format("  %-46s %s", label, strip_ws(wanted):sub(1, 44)))
        end
    end

    -- and the CF branch is chosen by the TYPE: the same property name with a different type is a different branch
    if G.init_body("initWithX:", {{"buffer", "NSInteger", "buffer"}}, name_set({"buffer"}), nil):find("self->_buffer", 1, true) then
        bad[#bad + 1] = "a NSInteger named buffer took the CF branch - the branch is following the NAME"
    end

    -- and the accessor for a CF property reads the ivar, not the store
    local cf_accessor = G.body("buffer", G.odict_get(props("@property(nonatomic,readonly) CVPixelBufferRef buffer;"),
                                                     "buffer"))
    if not cf_accessor:find("self->_buffer", 1, true) or cf_accessor:find("CharonValueStore", 1, true) then
        bad[#bad + 1] = "the CF accessor does not read the ivar:\n" .. cf_accessor
    else
        print("  the CF accessor reads the ivar: " .. strip_ws(first_line(cf_accessor)))
    end

    -- THE MANDATORY WALK. Every argument type of all seventeen initialisers, the branch each one takes, and a
    -- FAILURE for any type with no expected branch.
    if sdk == "" then
        print("  VT_SDK unset: the branch walk is NOT checked here")
    else
        local frameworks = sdk .. "/System/Library/Frameworks"
        local headers = sdk .. "/System/Library/Frameworks/VideoToolbox.framework/Headers"
        local pieces_text = {}
        for _, f in ipairs(sorted_headers(headers)) do pieces_text[#pieces_text + 1] = V.read_text(f) end
        local text = table.concat(pieces_text, "\n")
        local seen = {}
        local seen_set = {}
        for _, cls in ipairs(G.ORDER()) do
            for _, init in ipairs(G.initialisers(text, cls)) do
                for _, arg in ipairs(init[2]) do
                    if not seen_set[arg[2]] then
                        seen_set[arg[2]] = true
                        seen[#seen + 1] = arg[2]
                    end
                end
            end
        end
        -- The probe's rows as the TEST reads them: a line keeps its newline, so the objc flag of a line that
        -- ends in "\n" compares false here. Kept as the Python reads it, not "fixed".
        local signals = {}
        for _, line in ipairs(lines_keeping_newline(HERE .. "/../../../../.agent-work/runs/vt/type-branches.tsv")) do
            local r = split_tab(line)
            if #r == 3 then
                local digits = strip_ws(r[2])
                if not digits:match("^[+-]?%d+$") then
                    V.fail("invalid literal for int() with base 10: " .. py_repr(r[2]))
                end
                signals[r[1]] = {tonumber(digits), r[3] == "objc"}
            end
        end
        local canonical = G.probe_types(sdk, seen, HERE .. "/../../../../.agent-work/runs/vt")
        print(string.format("  %d distinct argument types across the seventeen initialisers", #seen))
        for _, type_name in ipairs(seen) do
            local got = nil
            if signals[type_name] then
                got = G.branch_of(signals[type_name][1], signals[type_name][2])
            end
            local wanted = EXPECTED_BRANCH[type_name]
            local canon = py_str(canonical[type_name])
            if wanted == nil then
                bad[#bad + 1] = type_name .. ": no expected branch - the SDK declares it and nobody classified it "
                    .. "(the compiler says " .. py_repr(canonical[type_name]) .. ")"
                print(string.format("     %-58s %-38s NO EXPECTED BRANCH", type_name, canon))
            elseif got ~= wanted then
                bad[#bad + 1] = string.format("%s: the branch is %s and it should be %s (the compiler says %s)",
                    type_name, py_str(got), wanted, py_repr(canonical[type_name]))
                print(string.format("     %-58s %-38s wanted %s", type_name, canon, wanted))
            else
                print(string.format("     %-58s %-38s %s", type_name, canon, got))
            end
        end
        -- the two cases named on their own, with the compiler's answer beside them
        local named = {{"CVPixelBufferRef", "CF"}, {"OSType", "scalar"},
                       {"NSArray<NSNumber *> *", "object"}, {"CMTime", "struct"}}
        for _, nc in ipairs(named) do
            local type_name, wanted = nc[1], nc[2]
            local got = nil
            if signals[type_name] then
                got = G.branch_of(signals[type_name][1], signals[type_name][2])
            end
            if got ~= wanted then
                bad[#bad + 1] = string.format("%s: the compiler says %s and the branch is %s, wanted %s",
                    type_name, py_repr(canonical[type_name]), py_str(got), wanted)
            end
        end
    end

    return bad, #CASES
end

function main(...)
    local bad, ncases = nil, nil
    try {
        function()
            bad, ncases = run_checks()
        end,
        catch {
            function(err)
                -- Python's uncaught exception: the traceback is not reproduced; the exit status is the same, 1.
                V.fail(tostring(err))
            end
        }
    }
    for _, line in ipairs(bad) do
        print("FAIL " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print(string.format("gen_body: %d declarations, both spellings, one accessor each", ncases))
end
