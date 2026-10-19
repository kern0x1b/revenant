import("core.base.json")

local NS_UNAVAILABLE_CLASSES = {
    "VTFrameProcessorFrame", "VTFrameProcessorOpticalFlow", "VTFrameRateConversionConfiguration",
    "VTFrameRateConversionParameters", "VTLowLatencyFrameInterpolationConfiguration",
    "VTLowLatencyFrameInterpolationParameters", "VTLowLatencySuperResolutionScalerConfiguration",
    "VTLowLatencySuperResolutionScalerParameters", "VTMotionBlurConfiguration", "VTMotionBlurParameters",
    "VTOpticalFlowConfiguration", "VTOpticalFlowParameters", "VTSuperResolutionScalerConfiguration",
    "VTSuperResolutionScalerParameters", "VTTemporalNoiseFilterConfiguration",
    "VTTemporalNoiseFilterParameters",
}

local PROCESSOR_METHODS = {
    "startSessionWithConfiguration:error:", "processWithParameters:error:",
    "processWithParameters:completionHandler:", "processWithParameters:frameOutputHandler:",
    "processWithCommandBuffer:parameters:", "endSession",
}

local OTHER_METHODS = {
    { "VTLowLatencySuperResolutionScalerConfiguration", { "supportedScaleFactorsForFrameWidth:frameHeight:" } },
    { "VTSuperResolutionScalerConfiguration", { "downloadConfigurationModelWithCompletionHandler:" } },
}

local CONFORMS = {
    VTFrameRateConversionConfiguration = "VTFrameProcessorConfiguration",
    VTLowLatencyFrameInterpolationConfiguration = "VTFrameProcessorConfiguration",
    VTLowLatencySuperResolutionScalerConfiguration = "VTFrameProcessorConfiguration",
    VTOpticalFlowConfiguration = "VTFrameProcessorConfiguration",
    VTSuperResolutionScalerConfiguration = "VTFrameProcessorConfiguration",
    VTTemporalNoiseFilterConfiguration = "VTFrameProcessorConfiguration",
    VTFrameRateConversionParameters = "VTFrameProcessorParameters",
    VTLowLatencyFrameInterpolationParameters = "VTFrameProcessorParameters",
    VTLowLatencySuperResolutionScalerParameters = "VTFrameProcessorParameters",
    VTOpticalFlowParameters = "VTFrameProcessorParameters",
    VTSuperResolutionScalerParameters = "VTFrameProcessorParameters",
    VTTemporalNoiseFilterParameters = "VTFrameProcessorParameters",
    VTMotionBlurConfiguration = "VTFrameProcessorConfiguration",
    VTMotionBlurParameters = "VTFrameProcessorParameters",
}

local OBJECT_OF = { VTMotionBlurConfiguration = "VideoToolboxValue26" }

local function unit_of(cls)
    return OBJECT_OF[cls] or cls
end

local PROTOCOL_METHODS = {
    VTFrameProcessorParameters = { "destinationFrame", "destinationFrames", "sourceFrame" },
    VTFrameProcessorConfiguration = { "destinationPixelBufferAttributes", "frameSupportedPixelFormats",
        "isSupported", "maximumDimensions", "minimumDimensions", "nextFrameCount", "previousFrameCount",
        "sourcePixelBufferAttributes" },
}

local function lines_of(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        out[#out + 1] = line
    end
    return out
end

local function split_tabs(line)
    local out = {}
    for field in (line .. "\t"):gmatch("(.-)\t") do
        out[#out + 1] = field
    end
    return out
end

local function strip(text)
    return (text:match("^%s*(.-)%s*$"))
end

local function sorted_keys(set)
    local keys = {}
    for key in pairs(set) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function join(list, separator)
    return table.concat(list, separator or ", ")
end

local function contains_plain(text, needle)
    return text:find(needle, 1, true) ~= nil
end

local function own_methods(obj)
    local out = os.iorunv("otool", { "-oV", obj })
    local instance, klass = {}, {}
    local current = nil
    for _, line in ipairs(lines_of(out)) do
        if contains_plain(line, "baseMethods") then
            current = contains_plain(line, "INSTANCE_METHODS") and instance or klass
        elseif current ~= nil then
            local name = line:match("^%s+name%s+0x%x+%s+(%S+)$")
            if name then
                current[name] = true
            end
        end
    end
    return { instance = instance, class = klass }
end

local function literal_strings(obj)
    local out = os.iorunv("otool", { "-v", "-s", "__TEXT", "__cstring", obj })
    local found = {}
    for _, line in ipairs(lines_of(out)) do
        local hex, rest = line:match("^(%x+)  (%S.*)$")
        if hex and #hex >= 6 then
            found[strip(rest)] = true
        end
    end
    return found
end

local function numbers_in_header(path)
    local file = assert(io.open(path, "r"), "cannot read " .. path)
    local text = file:read("a")
    file:close()
    local found = {}
    for name, value in text:gmatch("%f[%w_](VTFrameProcessor%a+) = (%-?%d+),") do
        found[name] = tonumber(value)
    end
    return found
end

local function read_registry(backports)
    local folder = path.join(backports, "registry", "VideoToolbox")
    local files = os.files(path.join(folder, "*.json"))
    table.sort(files)
    local rows = {}
    for _, file in ipairs(files) do
        for _, entry in ipairs(json.loadfile(file).entries) do
            rows[entry.api .. "|" .. entry.kind] = entry
        end
    end
    return rows
end

local function row_of(registry, api, kind)
    return registry[api .. "|" .. kind]
end

local function fail(failures, message)
    failures[#failures + 1] = message
end

function main(...)
    local args = { ... }
    if #args ~= 3 then
        print("check_port.lua: pass <host-answers output> <apple-backports dir> <build dir>")
        os.exit(2)
    end
    local host_path, backports, build = args[1], args[2], args[3]

    local domain, codes, supported, unavailable, raised = nil, {}, {}, {}, {}
    local controls = 0
    for _, line in ipairs(lines_of(io.readfile(host_path) or "")) do
        local parts = split_tabs(line)
        if parts[1] == "CONTROL" and #parts == 3 then
            controls = controls + 1
        elseif parts[1] == "DOMAIN" and #parts == 3 then
            domain = parts[2]
        elseif parts[1] == "ERRORCODE" and #parts == 3 then
            codes[parts[2]] = tonumber(parts[3])
        elseif parts[1] == "SUPPORTED" and #parts == 3 then
            supported[parts[2]] = parts[3]
        elseif parts[1] == "UNAVAILABLE" and #parts == 6 then
            unavailable[parts[2]] = { parts[3], parts[4], parts[5], parts[6] }
        elseif parts[1] == "RAISES" and #parts == 3 then
            raised[#raised + 1] = { parts[2], parts[3] }
        end
    end

    local failures = {}
    if controls ~= 1 then
        fail(failures, string.format("the host reader printed %d control lines, and this check trusts none of its "
            .. "output without exactly one", controls))
    end
    if not domain then
        fail(failures, "the host reader printed no DOMAIN line")
    end
    local code_count = 0
    for _ in pairs(codes) do
        code_count = code_count + 1
    end
    if code_count ~= 14 then
        fail(failures, string.format("the host printed %d error codes, and SDK 26.2 enumerates 14", code_count))
    end

    local header = path.join(backports, "VideoToolbox", "RevenantVideoToolbox.h")
    local port_codes = numbers_in_header(header)
    for _, name in ipairs(sorted_keys(codes)) do
        local value = codes[name]
        if port_codes[name] ~= value then
            fail(failures, string.format("%s is %s on the host and %s in RevenantVideoToolbox.h",
                name, tostring(value), tostring(port_codes[name])))
        end
    end
    local missing_codes = {}
    for name in pairs(codes) do
        if port_codes[name] == nil then
            missing_codes[#missing_codes + 1] = name
        end
    end
    if #missing_codes > 0 then
        table.sort(missing_codes)
        fail(failures, "RevenantVideoToolbox.h enumerates none of " .. join(missing_codes))
    end

    local domain_object = path.join(build, "VTFrameProcessorErrors26_0.o")
    local strings = literal_strings(domain_object)
    if domain and not strings[domain] then
        local listed = sorted_keys(strings)
        fail(failures, string.format("the port's compiled error-domain object carries no literal %q; it carries %s",
            domain, #listed > 0 and "[" .. join(listed) .. "]" or "no string at all"))
    end

    local registry = read_registry(backports)

    local processor = own_methods(path.join(build, "VTFrameProcessor.o")).instance
    for _, method in ipairs(PROCESSOR_METHODS) do
        if not processor[method] then
            fail(failures, string.format("VTFrameProcessor.o carries no -%s, and the registry row claims it", method))
        end
    end

    if processor["init"] then
        fail(failures, "VTFrameProcessor.o defines -init; the host's class implements none of its own, so "
            .. "the port's class must not differ from Apple's in which class owns the method")
    end
    local processor_init_row = row_of(registry, "-[VTFrameProcessor init]", "method")
    if processor_init_row == nil or processor_init_row.status ~= "implemented" then
        fail(failures, "-[VTFrameProcessor init] is not an implemented registry row; the host's class answers "
            .. "NSObject's -init, which the port inherits too")
    end

    for _, cls in ipairs(NS_UNAVAILABLE_CLASSES) do
        for _, pair in ipairs({ { "-[%s init]", "implemented" }, { "+[%s new]", "implemented" } }) do
            local api = string.format(pair[1], cls)
            local row = row_of(registry, api, "method")
            if row == nil then
                fail(failures, "no registry row at all for " .. api)
            elseif row.status ~= pair[2] then
                fail(failures, string.format("%s is %s, and the SDK marks -init NS_UNAVAILABLE", api, row.status))
            end
        end
        local obj = path.join(build, unit_of(cls) .. ".o")
        if not os.isfile(obj) then
            fail(failures, string.format("no compiled object for %s (expected %s.o)", cls, unit_of(cls)))
        else
            local found = own_methods(obj)
            if found.instance["init"] then
                fail(failures, cls .. ".o defines -init, and the SDK marks it NS_UNAVAILABLE")
            end
            if found.class["new"] then
                fail(failures, cls .. ".o defines +new, and the SDK marks -init NS_UNAVAILABLE")
            end
        end
    end

    local configuration_classes = { "VTFrameRateConversionConfiguration",
        "VTLowLatencyFrameInterpolationConfiguration", "VTLowLatencySuperResolutionScalerConfiguration",
        "VTOpticalFlowConfiguration", "VTSuperResolutionScalerConfiguration",
        "VTTemporalNoiseFilterConfiguration" }
    for _, cls in ipairs(configuration_classes) do
        local obj = path.join(build, unit_of(cls) .. ".o")
        if not os.isfile(obj) then
            fail(failures, string.format("no compiled object for %s (expected %s.o)", cls, unit_of(cls)))
        else
            local found = own_methods(obj)
            if not found.class["isSupported"] then
                fail(failures, cls .. ".o defines no +isSupported, which is what the SDK's getter= names")
            end
            if found.class["supported"] then
                fail(failures, cls .. ".o carries +supported as well; the SDK declares one accessor, "
                    .. "getter=isSupported, and a second spelling is not that accessor")
            end
        end
    end

    for _, pair in ipairs(raised) do
        fail(failures, string.format("the host RAISES on %s: %s. The absent rows for this family claim it does "
            .. "not, and that claim is now false", pair[1], pair[2]))
    end
    for _, cls in ipairs(NS_UNAVAILABLE_CLASSES) do
        local answer = unavailable[cls]
        if answer == nil then
            fail(failures, "the host reader printed no UNAVAILABLE line for " .. cls)
        else
            local own_init, new_answers, init_answers = answer[1], answer[2], answer[3]
            if own_init ~= "own-init=0" then
                fail(failures, string.format("the host's %s implements -init of its own (own-init=1), so the absent "
                    .. "row's reason - that it inherits NSObject's - is no longer what it says", cls))
            end
            if new_answers ~= "+new-answers=1" or init_answers ~= "-init-answers=1" then
                fail(failures, string.format("the host's %s does not answer both +new and -init (%s, %s), so the "
                    .. "absent row's measured effect is no longer what it says", cls, new_answers, init_answers))
            end
        end
    end

    for _, cls in ipairs({ "VTFrameRateConversionConfiguration", "VTMotionBlurConfiguration",
        "VTOpticalFlowConfiguration" }) do
        if row_of(registry, cls .. ".processorSupported", "property") ~= nil then
            fail(failures, cls .. ".processorSupported has a registry row, but the SDK marks it API_UNAVAILABLE(ios)")
        end
        local found = own_methods(path.join(build, unit_of(cls) .. ".o"))
        for _, accessor in ipairs({ "processorSupported", "isProcessorSupported" }) do
            if found.class[accessor] or found.instance[accessor] then
                fail(failures, string.format("%s.o carries %s, and the SDK marks the property API_UNAVAILABLE(ios)",
                    cls, accessor))
            end
        end
    end

    for _, pair in ipairs(OTHER_METHODS) do
        local cls, methods = pair[1], pair[2]
        local obj = path.join(build, cls .. ".o")
        if not os.isfile(obj) then
            fail(failures, "no compiled object for " .. cls)
        else
            local found = own_methods(obj)
            for _, method in ipairs(methods) do
                local is_class = method:sub(1, 9) == "supported"
                local side = is_class and found.class or found.instance
                if not side[method] then
                    fail(failures, string.format("%s.o defines no %s%s", cls, is_class and "+" or "-", method))
                end
                local api = string.format(is_class and "+[%s %s]" or "-[%s %s]", cls, method)
                local row = row_of(registry, api, "method")
                if row == nil or row.status ~= "implemented" then
                    fail(failures, "no implemented registry row for " .. api)
                end
            end
        end
    end

    for _, cls in ipairs({ "VTFrameProcessorParameters", "VTFrameProcessorConfiguration" }) do
        for _, method in ipairs(PROTOCOL_METHODS[cls]) do
            local api = string.format("%s.%s", cls, method ~= "isSupported" and method or "supported")
            local entry = row_of(registry, api, "property")
            if entry == nil then
                fail(failures, string.format("no registry row for %s, which the protocol declares", api))
            elseif entry.status ~= "implemented" then
                fail(failures, api .. " is " .. entry.status)
            end
        end
    end
    for _, cls in ipairs(sorted_keys(CONFORMS)) do
        local protocol = CONFORMS[cls]
        local obj = path.join(build, unit_of(cls) .. ".o")
        if not os.isfile(obj) then
            fail(failures, string.format("no compiled object for %s (expected %s.o)", cls, unit_of(cls)))
        else
            local found = own_methods(obj)
            for _, method in ipairs(PROTOCOL_METHODS[protocol]) do
                if not found.instance[method] and not found.class[method] then
                    fail(failures, string.format("%s.o defines no %s, which %s - the protocol it declares conformance to -"
                        .. " carries in the built library", cls, method, protocol))
                end
            end
        end
    end

    local hdr = path.join(build, "VTHDRPerFrameMetadataGenerationSession18_0.o")
    if not os.isfile(hdr) then
        fail(failures, "no compiled object for the HDR per-frame metadata session")
    else
        local defined = {}
        for token in os.iorunv("nm", { "-gU", hdr }):gmatch("%S+") do
            defined[token] = true
        end
        for _, symbol in ipairs({ "_VTHDRPerFrameMetadataGenerationSessionGetTypeID",
            "_VTHDRPerFrameMetadataGenerationSessionCreate",
            "_VTHDRPerFrameMetadataGenerationSessionAttachMetadata",
            "_kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision" }) do
            if not defined[symbol] then
                fail(failures, string.format("%s does not export %s", path.filename(hdr), symbol))
            end
        end
        if not literal_strings(hdr)["DolbyVision"] then
            fail(failures, string.format("%s carries no literal \"DolbyVision\", which is what the host's own "
                .. "kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision holds", path.filename(hdr)))
        end
        for _, api in ipairs({ "VTHDRPerFrameMetadataGenerationSessionGetTypeID()",
            "VTHDRPerFrameMetadataGenerationSessionCreate()",
            "VTHDRPerFrameMetadataGenerationSessionAttachMetadata()",
            "kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision" }) do
            local kind = api:sub(1, 3) == "kVT" and "constant" or "function"
            local row = row_of(registry, api, kind)
            if row == nil or row.status ~= "implemented" then
                fail(failures, "no implemented registry row for " .. api)
            end
        end
    end

    print("supported (host=1 on this M4 Pro; the port answers NO because no armv7 release has the "
        .. "hardware, and that difference is the documented answer):")
    for _, cls in ipairs(sorted_keys(supported)) do
        print(string.format("  %-46s host=%s  port=NO", cls, supported[cls]))
    end
    print("the host's own +new/-init on the NS_UNAVAILABLE classes: none of them implements -init, both "
        .. "answer, nothing raises, and the object that comes back is empty - which is why the rows are "
        .. "`absent` and the port's objects must not grow an -init of their own:")
    for _, cls in ipairs(sorted_keys(unavailable)) do
        local answer = unavailable[cls]
        local listed = false
        for _, known in ipairs(NS_UNAVAILABLE_CLASSES) do
            listed = listed or known == cls
        end
        if listed then
            print(string.format("  %-46s %s %s %s empty=%s", cls, answer[1], answer[2], answer[3], answer[4]))
        end
    end

    if #failures > 0 then
        for _, message in ipairs(failures) do
            print("FAIL " .. message)
        end
        print(string.format("videotoolbox-frameprocessor: %d failure(s)", #failures))
        os.exit(1)
    end
    print(string.format("videotoolbox-frameprocessor: OK - the domain string, %d codes, %d processor methods (and no"
        .. " -init, which Apple's class does not implement either), the protocol accessors on %d conforming"
        .. " classes, the HDR session's 3 functions and its measured constant, and %d NS_UNAVAILABLE classes agree"
        .. " with the host and with the registry",
        code_count, #PROCESSOR_METHODS, #sorted_keys(CONFORMS), #NS_UNAVAILABLE_CLASSES))
    os.exit(0)
end
