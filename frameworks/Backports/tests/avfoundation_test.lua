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
