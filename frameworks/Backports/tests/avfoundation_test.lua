local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local implemented = import("implemented", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local AREAS = {
    {
        name = "rectangles of interest of the metadata output and its preview layer",
        sources = {"AVCaptureMetadataOutput+RectOfInterest7.m", "AVCaptureVideoPreviewLayer+MetadataRect7.m"},
        members = {
            "-[AVCaptureMetadataOutput rectOfInterest]", "-[AVCaptureMetadataOutput setRectOfInterest:]",
            "-[AVCaptureVideoPreviewLayer metadataOutputRectOfInterestForRect:]",
        },
    },
    {
        name = "machine-readable code objects delivered by the metadata output",
        sources = {"AVMetadataMachineReadableCodeObject7.m", "AVCaptureMetadataOutput+MachineReadableCode7.m"},
        members = {
            "-[AVMetadataMachineReadableCodeObject type]", "-[AVMetadataMachineReadableCodeObject stringValue]",
            "-[AVMetadataMachineReadableCodeObject corners]", "-[AVMetadataMachineReadableCodeObject bounds]",
            "-[AVMetadataMachineReadableCodeObject time]",
        },
    },
    {
        name = "initialization of a speech voice by its identifier, as expo-speech does",
        sources = {"AVSpeechSynthesisVoice7.m"},
        members = {
            "-[AVSpeechSynthesisVoice initWithIdentifier:]",
        },
    },
    {
        name = "resource loading, asset variants and buffering of expo-video",
        sources = {"AVAssetResourceLoadingDataRequest7.m", "AVAssetResourceLoadingRequest+Data7.m", "RevenantRangeHeader.c", "AVAssetVariant15.m", "AVPlayerItem+PreferredForwardBufferDuration10.m", "AVPlayerItem+CurrentMediaSelection5.m",
                   "AVPlayerItem+ConfiguredTimeOffset13.m", "AVMediaSelectionOption+DisplayName7.m", "AVMediaSelectionGroup+DefaultOption8.m", "AVPlayer+MediaSelectionCriteria7.m"},
        members = {
            "-[AVAssetResourceLoadingRequest dataRequest]", "-[AVAssetResourceLoadingRequest contentInformationRequest]",
            "-[AVAssetResourceLoadingRequest response]", "-[AVAssetResourceLoadingRequest setResponse:]",
            "-[AVAssetResourceLoadingRequest finishLoading]",
            "-[AVPlayerItem currentMediaSelection]",
            "-[AVPlayerItem configuredTimeOffsetFromLive]", "-[AVPlayerItem setConfiguredTimeOffsetFromLive:]",
            "-[AVMediaSelectionOption displayName]", "-[AVMediaSelectionGroup defaultOption]",
            "-[AVPlayer setMediaSelectionCriteria:forMediaCharacteristic:]",
            "-[AVAssetResourceLoadingDataRequest requestedOffset]", "-[AVAssetResourceLoadingDataRequest currentOffset]",
            "-[AVAssetResourceLoadingDataRequest requestedLength]", "-[AVAssetResourceLoadingDataRequest requestsAllDataToEndOfResource]",
            "-[AVAssetResourceLoadingDataRequest respondWithData:]",
            "-[AVAssetVariant peakBitRate]", "-[AVAssetVariant averageBitRate]", "-[AVAssetVariant videoAttributes]",
            "-[AVAssetVariantVideoAttributes presentationSize]", "-[AVAssetVariantVideoAttributes codecTypes]",
            "-[AVAssetVariantVideoAttributes nominalFrameRate]", "-[AVAssetVariantVideoAttributes videoRange]",
            "-[AVPlayerItem preferredForwardBufferDuration]", "-[AVPlayerItem setPreferredForwardBufferDuration:]",
        },
    },
    {
        name = "looping of a template item through a queue player",
        sources = {"AVPlayerLooper10.m"},
        members = {
            "+[RevenantAVPlayerLooper playerLooperWithPlayer:templateItem:]",
            "+[RevenantAVPlayerLooper playerLooperWithPlayer:templateItem:timeRange:]",
            "-[RevenantAVPlayerLooper status]", "-[RevenantAVPlayerLooper error]", "-[RevenantAVPlayerLooper loopCount]",
            "-[RevenantAVPlayerLooper loopingPlayerItems]", "-[RevenantAVPlayerLooper disableLooping]",
        },
    },
}

local function key_of(member)
    local sign, owner, selector = member:match("^([%+%-])%[(%S+) ([^%]]+)%]$")
    assert(sign, "not a member: " .. member)
    return (sign == "+" and "class method" or "instance method") .. "|" .. owner .. "|" .. selector
end

function main()
    local sdk = os.getenv("REVENANT_GEN_SDK")
    if not sdk or sdk == "" then
        sdk = sdkfiles.sdk_folder()
    end
    local sources = path.absolute(path.join(os.scriptdir(), "..", "src", "AVFoundation"))
    local root = path.join(workspace.scratch(), "avfoundation-test")
    os.tryrm(root)
    local objects, total = 0, 0
    for _, area in ipairs(AREAS) do
        for _, name in ipairs(area.sources) do
            local object = path.join(root, "AVFoundation", "src", "AVFoundation", name .. ".o")
            os.mkdir(path.directory(object))
            os.vrunv("clang", {"-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-fobjc-arc", "-Os", "-w", "-c", "-o", object,
                path.join(sources, name)})
            objects = objects + 1
        end
    end
    local keys = implemented.from_objects(root).AVFoundation or {}
    local missing = {}
    for _, area in ipairs(AREAS) do
        for _, member in ipairs(area.members) do
            total = total + 1
            if not keys[key_of(member)] then
                table.insert(missing, area.name .. ": " .. member)
            end
        end
    end
    assert(#missing == 0, "members not implemented by the compiled AVFoundation objects:\n" .. table.concat(missing, "\n"))
    os.tryrm(root)
    print("avfoundation tests passed: " .. total .. " members implemented by " .. objects .. " objects in " .. #AREAS .. " areas")
end
