local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local src = path.absolute(path.join(os.scriptdir(), "..", "src"))

local PROTOCOLS = {
    {name = "UNUserNotificationCenterDelegate", framework = "UserNotifications", header = "UNUserNotificationCenter.h", source = "UIKit/UNUserNotificationCenterDelegate10.m"},
    {name = "PKPushRegistryDelegate", framework = "PushKit", header = "PKPushRegistry.h", source = "PushKit/PKPushRegistryDelegate8.m"},
    {name = "CXProviderDelegate", framework = "CallKit", header = "CXProvider.h", source = "CallKit/CXProviderDelegate10.m"},
    {name = "AVCapturePhotoCaptureDelegate", framework = "AVFoundation", header = "AVCapturePhotoOutput.h", source = "AVFoundation/AVCapturePhotoCaptureDelegate10.m"},
    {name = "PHPhotoLibraryChangeObserver", framework = "Photos", header = "PHPhotoLibrary.h", source = "Photos/PHPhotoLibraryChangeObserver8.m"},
    {name = "AVPictureInPictureControllerDelegate", framework = "AVKit", header = "AVPictureInPictureController.h", source = "AVKit/AVPictureInPictureControllerDelegate9.m"},
    {name = "CAAnimationDelegate", framework = "QuartzCore", header = "CAAnimation.h", source = "UIKit/QuartzCoreProtocols10.m"},
    {name = "CALayerDelegate", framework = "QuartzCore", header = "CALayer.h", source = "UIKit/QuartzCoreProtocols10.m"},
    {name = "JSExport", framework = "JavaScriptCore", header = "JSExport.h", source = "JavaScriptCore/JSExport7.m", marker = true},
    {name = "CNKeyDescriptor", framework = "Contacts", header = "CNContact.h", source = "Contacts/CNKeyDescriptor9.m", marker = true},
    {name = "PDFDocumentDelegate", framework = "PDFKit", header = "PDFDocument.h", source = "PDFKit/PDFDocumentDelegate11.m", macos_only = {"classForAnnotationClass:"}},
}

local function strip_parens(text)
    local out, depth = {}, 0
    for char in text:gmatch(".") do
        if char == "(" then
            depth = depth + 1
        elseif char == ")" then
            depth = depth - 1
        elseif depth == 0 then
            table.insert(out, char)
        end
    end
    return table.concat(out)
end

local function selector_of(declaration)
    local text = strip_parens(declaration)
    local parts = {}
    for word in text:gmatch("([%w_]+):") do
        table.insert(parts, word .. ":")
    end
    if #parts == 0 then
        return text:match("^[%-%+]%s*([%a_][%w_]*)") or ""
    end
    return table.concat(parts)
end

local function block(text, name)
    local start = text:find("@protocol%s+" .. name .. "[%s<]")
    assert(start, "no @protocol " .. name .. " <")
    local finish = text:find("\n@end", start, false)
    assert(finish, "no @end after @protocol " .. name)
    return text:sub(start, finish)
end

local function selectors(block_text)
    local found = {}
    local joined = block_text:gsub("\n%s*\n", "\n")
    local declarations = {}
    local current = nil
    for line in joined:gmatch("[^\n]*") do
        if line:match("^[%-%+] %(") then
            current = line
        elseif current then
            current = current .. " " .. line:gsub("^%s+", "")
        end
        if current and current:find(";%s*$") then
            table.insert(declarations, current)
            current = nil
        end
    end
    for _, declaration in ipairs(declarations) do
        local sel = selector_of(declaration)
        if sel ~= "" then
            found[sel] = true
        end
    end
    return found
end

local function keys_of(set)
    local list = {}
    for key in pairs(set) do
        table.insert(list, key)
    end
    table.sort(list)
    return list
end

function main()
    local sdk = sdkfiles.sdk_folder()
    for _, protocol in ipairs(PROTOCOLS) do
        local header = io.readfile(path.join(sdk, "System", "Library", "Frameworks", protocol.framework .. ".framework", "Headers", protocol.header))
        local expected = selectors(block(header, protocol.name))
        for _, sel in ipairs(protocol.macos_only or {}) do
            expected[sel] = nil
        end
        local declared = selectors(block(io.readfile(path.join(src, protocol.source)), protocol.name))
        local missing, extra = {}, {}
        for sel in pairs(expected) do
            if not declared[sel] then
                table.insert(missing, sel)
            end
        end
        for sel in pairs(declared) do
            if not expected[sel] then
                table.insert(extra, sel)
            end
        end
        assert(#missing == 0, protocol.name .. " lacks selectors of the SDK: " .. table.concat(missing, " "))
        assert(#extra == 0, protocol.name .. " declares selectors the SDK does not have: " .. table.concat(extra, " "))
        assert(protocol.marker or #keys_of(expected) > 0, protocol.name .. ": the SDK block has no methods")
    end
end
