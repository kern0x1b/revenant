local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local sdk = workspace.sdk()
    local out = path.join(os.projectdir(), "build", "tests", "lowered-vfs")
    os.rm(out)
    local vfs = io.readfile(lowered.overlay(sdk, out))
    local system = path.join(sdk, "usr", "include")
    assert(vfs:find('"name": "' .. system .. '"', 1, true) == nil, "the overlay maps a usr/include directory, so clang reaches the SDK's availability headers through two paths and builds _AvailabilityInternal twice")
    assert(vfs:find('"name": "' .. path.join(system, "os", "lock.h") .. '", "type": "file"', 1, true), "the overlay does not map os/lock.h, so import os reads the SDK's lock.h, which carries the iOS 10 availability")
    assert(vfs:find('"name": "' .. path.join(sdk, "System", "Library", "Frameworks", "Foundation.framework", "Headers"), 1, true), "the overlay lost the framework headers it lowers")
    local lock = path.join(lowered.include_directory(out), "os", "lock.h")
    assert(os.isfile(lock), "os/lock.h is not in the include directory the lowering passes ahead of the SDK")
    local header = io.readfile(lock)
    assert(header:find("#define OS_UNFAIR_LOCK_AVAILABILITY", 1, true), "os/lock.h lost the OS_UNFAIR_LOCK_AVAILABILITY define")
    assert(header:find("__API_AVAILABLE(macos(10.12), ios(10.0)", 1, true) == nil, "os/lock.h still carries the iOS 10 availability")
    local compression = path.join(lowered.include_directory(out), "compression.h")
    assert(os.isfile(compression), "compression.h is not in the include directory the lowering passes ahead of the SDK")
    assert(io.readfile(compression):find("__API_AVAILABLE(macos(10.11), ios(9.0));", 1, true) == nil, "compression.h keeps the iOS 9 gate of its LZFSE functions")
    local frameworks = path.join(out, "System", "Library", "Frameworks")
    local interface = io.readfile(path.join(frameworks, "Foundation.framework", "Headers", "NSURL.h"))
    assert(interface:find("@interface NSURLComponents", 1, true) and not interface:find("ios(7.0), watchos(2.0), tvos(9.0))\n@interface NSURLComponents", 1, true), "NSURLComponents keeps its iOS 7 gate: its alias exports the class, so the reference is strong and the gate is lowered")
    local property = io.readfile(path.join(frameworks, "UIKit.framework", "Headers", "UIInterface.h")):match("[^\n]*UIColor %*systemBackgroundColor[^\n]*")
    assert(property and not property:find("ios(13.0)", 1, true) and property:find("API_UNAVAILABLE(tvos, watchos)", 1, true), "the class property systemBackgroundColor keeps its iOS 13 introduction or loses the other platforms' attributes")
    local notes = io.readfile(path.join(frameworks, "UIKit.framework", "Headers", "UIKit.apinotes"))
    assert(not notes:find("- Name: UITraitUserInterfaceStyle\n  SwiftPrivate: true", 1, true), "UIKit.apinotes hides UITraitUserInterfaceStyle from Swift, so on armv7, which has no Swift interface for UIKit, the class is imported as __UITraitUserInterfaceStyle")
    assert(not notes:find("  - Name: 'traitOverrides'\n    SwiftPrivate: true", 1, true), "UIKit.apinotes hides traitOverrides from Swift, so UIView has no member traitOverrides")
    assert(not notes:find("  - Selector: \"registerForTraitChanges:withHandler:\"\n    MethodKind: Instance\n    SwiftPrivate: true", 1, true), "UIKit.apinotes hides registerForTraitChanges(withHandler:) from Swift")
    assert(notes:find("- Name: UIContentView\n  SwiftPrivate: true", 1, true), "UIKit.apinotes lost the private flag of UIContentView, which Backports do not implement")
    for _, owner in ipairs({"UIView", "UIViewController", "UIWindowScene", "UIPresentationController"}) do
        local interface = io.readfile(path.join(frameworks, "UIKit.framework", "Headers", owner .. ".h"))
        assert(interface:find("withHandler:(UITraitChangeHandler)handler NS_SWIFT_NAME(registerForTraitChanges(_:handler:));", 1, true), owner .. ".h does not declare registerForTraitChanges(_:handler:), so Swift on armv7, which has no Swift interface for UIKit, does not see it as a member of " .. owner)
    end
    local protocol = io.readfile(path.join(frameworks, "UIKit.framework", "Headers", "UITraitCollection.h"))
    assert(protocol:find("withHandler:(UITraitChangeHandler)handler NS_SWIFT_NAME(registerForTraitChanges(_:handler:));", 1, true), "UITraitCollection.h does not name the handler method of UITraitChangeObservable registerForTraitChanges(_:handler:), so Swift imports it as register(forTraitChanges:withHandler:)")
    assert(protocol:find("unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration NS_SWIFT_NAME(unregisterForTraitChanges(_:));", 1, true), "UITraitCollection.h does not name unregisterForTraitChanges(_:)")
    local constant = io.readfile(path.join(frameworks, "UIKit.framework", "Headers", "NSAttributedString.h")):match("[^\n]*const NSAttachmentAttributeName[^\n]*")
    assert(constant and not constant:find("ios(7.0)", 1, true), "the extern constant NSAttachmentAttributeName keeps its iOS 7 introduction")
    local weight = io.readfile(path.join(frameworks, "UIKit.framework", "Headers", "UIFontDescriptor.h")):match("[^\n]*const UIFontWeight UIFontWeightRegular[^\n]*")
    assert(weight and not weight:find("ios(8.2)", 1, true), "the extern constant UIFontWeightRegular keeps its iOS 8.2 introduction")
    local set = lowered.read_all_members()
    local declared = lowered.lower_swift_text("@available(macOS 10.9, iOS 7.0, *)\npublic struct URLComponents {\n}\n", lowered.swift_names(set), {}, {})
    assert(declared:find("public struct URLComponents", 1, true) and not declared:find("iOS 7.0", 1, true), "the Swift declaration of URLComponents keeps its iOS 7 guard although the class is no longer weak")
    local exif = io.readfile(path.join(frameworks, "ImageIO.framework", "Headers", "CGImageMetadata.h")):match("[^\n]*kCGImageMetadataNamespaceExifEX[^\n]*")
    assert(exif and not exif:find("IMAGEIO_AVAILABLE_STARTING", 1, true), "the ImageIO extern kCGImageMetadataNamespaceExifEX keeps its IMAGEIO_AVAILABLE_STARTING introduction")
    local linearized = io.readfile(path.join(frameworks, "CoreGraphics.framework", "Headers", "CGPDFContext.h")):match("CG_EXTERN const CFStringRef kCGPDFContextCreateLinearizedPDF[^;]*;")
    assert(linearized and not linearized:find("CG_AVAILABLE", 1, true), "the CoreGraphics extern kCGPDFContextCreateLinearizedPDF keeps the CG_AVAILABLE_STARTING it declares on the next line")
    local cloudkit = io.readfile(path.join(frameworks, "CloudKit.framework", "Headers", "CKError.h"))
    local _, begins = cloudkit:gsub("API_AVAILABLE_BEGIN", "")
    local _, ends = cloudkit:gsub("API_AVAILABLE_END", "")
    assert(begins == ends, "CKError.h has " .. begins .. " API_AVAILABLE_BEGIN and " .. ends .. " API_AVAILABLE_END: a region's start and end must be removed together")
    assert(cloudkit:match("API_AVAILABLE_END%s+CK_EXTERN NSString %* const CKErrorDomain;"), "CKErrorDomain is lowered, so its declaration must sit outside the iOS 8 region: the region closes before it")
    local utcore = io.readfile(path.join(out, "System", "Library", "Frameworks", "UniformTypeIdentifiers.framework", "Headers", "UTCoreTypes.h"))
    local declared = utcore:find("UT_EXPORT UTType *const UTTypeImage NS_REFINED_FOR_SWIFT;", 1, true)
    assert(declared, "the lowered UTCoreTypes.h lost the declaration of UTTypeImage")
    assert(utcore:sub(1, declared):match(".*(UT_AVAILABLE_%u+)") == "UT_AVAILABLE_END", "UTTypeImage is lowered, so the region of UTCoreTypes.h must close before its declaration")
    assert(utcore:find("UT_AVAILABLE_BEGIN", declared, true), "the region of UTCoreTypes.h must reopen after the lowered UTTypeImage, for the constants Backports do not define")
    local partial = lowered.lower_header(table.concat({
        "UT_AVAILABLE_BEGIN",
        "UT_EXPORT UTType *const DefinedThing NS_REFINED_FOR_SWIFT;",
        "UT_EXPORT UTType *const UndefinedThing NS_REFINED_FOR_SWIFT;",
        "UT_AVAILABLE_END",
        ""
    }, "\n"), {globals = {DefinedThing = true}, functions = {}, classes = {}, protocols = {}, protocol_members = {}, types = {},
        markers = {begin = {UT_AVAILABLE_BEGIN = "API_AVAILABLE_BEGIN(macos(11.0), ios(14.0))"}, ends = {UT_AVAILABLE_END = true}}})
    local undefined = partial:find("UndefinedThing", 1, true)
    assert(partial:sub(1, undefined):match(".*(UT_AVAILABLE_%u+)") == "UT_AVAILABLE_BEGIN", "UndefinedThing, which Backports do not define, must still sit in the iOS 14 region")
    local defined = partial:find("DefinedThing", 1, true)
    assert(partial:sub(1, defined):match(".*(UT_AVAILABLE_%u+)") == "UT_AVAILABLE_END", "DefinedThing is lowered, so the region must close before its declaration")
    local enum = lowered.lower_header(table.concat({
        "API_AVAILABLE_BEGIN(macos(10.11), ios(8), tvos(10))",
        "typedef NS_ENUM(NSInteger, PHFakeMode) {",
        "    PHFakeModeFit = 0,",
        "    PHFakeModeFill = 1,",
        "    PHFakeModeLater API_AVAILABLE(macos(10.12), ios(9), tvos(10)) = 2,",
        "    PHFakeModeNever = 3",
        "} NS_SWIFT_NAME(PHFake.Mode);",
        "API_AVAILABLE_END",
        ""
    }, "\n"), {globals = {PHFakeModeFit = true, PHFakeModeFill = true}, functions = {}, classes = {}, protocols = {}, protocol_members = {}, types = {}})
    local declaration = enum:match("typedef NS_ENUM%(NSInteger, PHFakeMode%) %b{}")
    assert(declaration, "the enum shaped like PhotosTypes.h did not lower to a declaration")
    assert(not declaration:find("API_AVAILABLE_BEGIN", 1, true) and not declaration:find("API_AVAILABLE_END", 1, true), "an availability region opens or closes inside the enum body")
    assert(enum:find("PHFakeModeFit = 0,", 1, true) and enum:find("PHFakeModeFill = 1,", 1, true), "the backported constants of the enum lost their values or gained a gate")
    assert(enum:find("PHFakeModeNever API_AVAILABLE(macos(10.11), ios(8), tvos(10)) = 3", 1, true), "the enum's constant that Backports do not define lost the region's availability")
    assert(enum:find("PHFakeModeLater API_AVAILABLE(macos(10.12), ios(9), tvos(10)) = 2", 1, true), "the enum's constant with its own availability lost it")
    assert(enum:sub(1, enum:find("typedef", 1, true) - 1):match(".*(API_AVAILABLE_%u+)") == "API_AVAILABLE_END", "the enum must sit outside the region, so the region closes before it")
    assert(enum:match("NS_SWIFT_NAME%(PHFake%.Mode%);(.*)$"):find("API_AVAILABLE_BEGIN", 1, true), "the region must reopen after the enum")
    local nested = {}
    for _, file in ipairs(os.files(path.join(out, "System", "Library", "Frameworks", "**.h"))) do
        local depth = 0
        for line in io.readfile(file):gmatch("[^\n]+") do
            local code = line:gsub("//.*$", "")
            if depth > 0 and (code:find("API_AVAILABLE_BEGIN", 1, true) or code:find("API_AVAILABLE_END", 1, true)) then
                table.insert(nested, path.filename(file))
                break
            end
            for brace in code:gmatch("[{}]") do
                depth = depth + (brace == "{" and 1 or -1)
            end
        end
    end
    assert(#nested == 0, "availability regions open or close inside a brace body in: " .. table.concat(nested, ", "))
end
