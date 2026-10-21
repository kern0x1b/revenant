local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local implemented = import("implemented", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local workspace = import("workspace", {rootdir = path.absolute(path.join(os.scriptdir(), "..", "..", "..", "toolchain", "modules")), anonymous = true})

local SOURCES = {"NSTextTab.m", "NSLayoutConstraint+Identifier7.m", "UIScreen+Snapshot7.m"}

local MEMBERS = {
    "instance method|NSTextTab|initWithTextAlignment:location:options:",
    "instance method|NSTextTab|alignment",
    "instance method|NSTextTab|location",
    "instance method|NSTextTab|options",
    "instance method|NSLayoutConstraint|identifier",
    "instance method|UIScreen|snapshotViewAfterScreenUpdates:",
}

function main()
    local sdk = os.getenv("REVENANT_GEN_SDK")
    if not sdk or sdk == "" then
        sdk = sdkfiles.sdk_folder()
    end
    local sources = path.absolute(path.join(os.scriptdir(), "..", "src", "UIKit"))
    local root = path.join(workspace.home(), "cache", "uikit-test")
    os.tryrm(root)
    for _, name in ipairs(SOURCES) do
        local object = path.join(root, "UIKit", "src", "UIKit", name .. ".o")
        os.mkdir(path.directory(object))
        os.vrunv("clang", {"-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-fobjc-arc", "-Os", "-w", "-c", "-o", object,
            path.join(sources, name)})
    end
    local keys = implemented.from_objects(root).UIKit or {}
    local missing = {}
    for _, key in ipairs(MEMBERS) do
        if not keys[key] then
            table.insert(missing, key)
        end
    end
    assert(#missing == 0, "members not implemented by the compiled UIKit objects: " .. table.concat(missing, ", "))
    os.tryrm(root)
    print("uikit tests passed: " .. #MEMBERS .. " members implemented by " .. #SOURCES .. " objects")
end
