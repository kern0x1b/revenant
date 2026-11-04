local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

local FLAGS = "// swift-module-flags: -target arm64e-apple-ios13.0 -enable-library-evolution -library-level api -module-name Foundation"

local OTHER = "@available(iOS 15.0, macOS 12.0, *)\nextension Foundation.PresentationIntent {\n}"

local SDK_EXTENSION = table.concat({
    "@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)",
    "extension Foundation.URLSessionWebSocketTask {",
    "  public enum Message {",
    "  }",
    "}",
}, "\n")

function failures(arguments)
    local found = {}
    local function expect(condition, message)
        if not condition then
            table.insert(found, message)
        end
    end

    local text = table.concat({FLAGS, OTHER, SDK_EXTENSION, ""}, "\n")
    local output = lowered.foundation_armv7_interface(text, "armv7-apple-ios6.0")
    expect(output:find("@available(iOS 6.0, *)\nextension Foundation.URLSessionWebSocketTask {", 1, true),
           "the availability of the URLSessionWebSocketTask extension is not lowered to the target minimum: " .. output)
    expect(not output:find("macOS 10.15", 1, true) and not output:find("iOS 13.0", 1, true),
           "the SDK's availability of the URLSessionWebSocketTask extension survived: " .. output)
    expect(output:find("@available(iOS 15.0, macOS 12.0, *)\nextension Foundation.PresentationIntent {", 1, true),
           "an availability line of another extension was changed: " .. output)
    expect(output:find("// swift-module-flags: -target armv7-apple-ios6.0 -module-name Foundation", 1, true),
           "the module flags are not retargeted to armv7 iOS 6 without library evolution: " .. output)

    local seven = lowered.foundation_armv7_interface(text, "armv7-apple-ios7.0")
    expect(seven:find("@available(iOS 7.0, *)\nextension Foundation.URLSessionWebSocketTask {", 1, true),
           "the minimum is not taken from the target: " .. seven)

    local raised = false
    try {
        function ()
            lowered.foundation_armv7_interface(table.concat({SDK_EXTENSION, SDK_EXTENSION, ""}, "\n"), "armv7-apple-ios6.0")
        end,
        catch {
            function ()
                raised = true
            end
        }
    }
    expect(raised, "two extensions of URLSessionWebSocketTask must raise instead of lowering one of them")

    return found
end
