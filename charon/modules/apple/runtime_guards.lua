import("compat")

-- The guards of the Swift runtime's weak imports. A weak import that no library of the runtime and no library of the C++
-- runtime it links exports is NULL on a release in the runtime's range that lacks it, and every one of them is called only
-- behind a guard in the runtime's own source; this table names that guard for each, by library file name and then symbol
-- as the symbol table spells it. Two readers: swift-runtime's on_test, which fails an install whose weak imports and this
-- table differ in either direction, and the checks after a program's link (platform.import_options), which report a weak
-- import a carried copy of the runtime makes only if it is recorded here and refuse any other as the program's own.
-- source is the line of the guard at the commit the recipe builds (swift b8189d76), or the patch of this repository
-- that adds it. A row is prose the machine cannot check: the pinned commit is what keeps it from going stale, so a bump
-- of the pin, or a patch that adds or drops a guard, must re-read this table.
GUARDS = {
    ["libswiftCore.dylib"] = {
        ["__dyld_is_objc_constant"] = "stdlib/public/stubs/FoundationHelpers.mm:124 @ swiftlang/swift b8189d766d86ad7fc8106787d6ce9e402f38dd72",
        ["__objc_realizeClassFromSwift"] = "packages/s/swift-runtime/patches/realize-a-pure-objc-class-before-objc-realize-class-from-swift.patch (tests the symbol at its use in swift_updatePureObjCClassMetadata)",
        ["_objc_addLoadImageFunc"] = "stdlib/public/runtime/ImageInspectionMachO.cpp:242 (REGISTER_FUNC; #define at :78) @ swiftlang/swift b8189d766d86ad7fc8106787d6ce9e402f38dd72",
        ["_objc_readClassPair"] = "patch packages/s/swift-runtime/patches/realize-a-class-before-objc-read-class-pair.patch:15",
        ["_objc_setHook_getClass"] = "stdlib/public/runtime/MetadataLookup.cpp:3297 @ swiftlang/swift b8189d766d86ad7fc8106787d6ce9e402f38dd72",
        ["_objc_setHook_getImageName"] = "stdlib/public/runtime/ObjCRuntimeGetImageNameFromClass.mm:361 @ swiftlang/swift b8189d766d86ad7fc8106787d6ce9e402f38dd72",
        ["_objc_setHook_lazyClassNamer"] = "stdlib/public/runtime/Metadata.cpp:3844 @ swiftlang/swift b8189d766d86ad7fc8106787d6ce9e402f38dd72",
    },
    ["libswiftCoreGraphics.dylib"] = {
        ["_CGPathAddRoundedRect"] = "patch packages/s/swift-runtime/patches/overlays/the-overlay-of-core-graphics-calls-what-the-sdk-still-has.patch:64",
        ["_kCGColorSpaceSRGB"] = "stdlib/public/Darwin/CoreGraphics/CoreGraphics.swift:80 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
    },
    ["libswiftDispatch.dylib"] = {
        ["__dispatch_data_destructor_munmap"] = "packages/s/swift-runtime/patches/overlays/the-overlay-of-dispatch-unmaps-its-data-where-a-release-before-7-has-none.patch",
        ["__dispatch_source_type_data_replace"] = "packages/s/swift-runtime/patches/overlays/the-overlay-of-dispatch-keeps-the-data-of-a-release-before-11s-replace-source.patch",
        ["__dispatch_source_type_memorypressure"] = "packages/s/swift-runtime/patches/overlays/the-overlay-of-dispatch-makes-memory-pressure-a-release-before-8-reports.patch",
        ["__dispatch_source_type_vm"] = "packages/s/swift-runtime/patches/overlays/the-overlay-of-dispatch-makes-memory-pressure-a-release-before-8-reports.patch (the shim declares it weak and asks for it only where the newer type is NULL)",
        ["_dispatch_assert_queue_barrier"] = "stdlib/public/Darwin/Dispatch/Dispatch.swift:25 (call at :31) @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_dispatch_assert_queue_not$V2"] = "stdlib/public/Darwin/Dispatch/Dispatch.swift:25 (call at :33) @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_dispatch_queue_attr_make_initially_inactive"] = "stdlib/public/Darwin/Dispatch/Queue.swift:42 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_dispatch_queue_attr_make_with_autorelease_frequency"] = "stdlib/public/Darwin/Dispatch/Queue.swift:96 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_dispatch_queue_attr_make_with_qos_class"] = "stdlib/public/Darwin/Dispatch/Queue.swift:161 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_dispatch_queue_create_with_target$V2"] = "stdlib/public/Darwin/Dispatch/Queue.swift:165 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_dispatch_queue_get_qos_class"] = "stdlib/public/Darwin/Dispatch/Queue.swift:472 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
    },
    ["libswiftFoundation.dylib"] = {
        ["_NSCalendarIdentifierIslamicTabular"] = "stdlib/public/Darwin/Foundation/Calendar.swift:974 (and :1014) @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSCalendarIdentifierIslamicUmmAlQura"] = "stdlib/public/Darwin/Foundation/Calendar.swift:974 (and :1014) @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSDataDeallocatorFree"] = "patch packages/s/swift-runtime/patches/overlays/the-overlay-of-foundation-asks-for-ios-7-where-it-reaches-ios-7.patch:40",
        ["_NSDataDeallocatorUnmap"] = "patch packages/s/swift-runtime/patches/overlays/the-overlay-of-foundation-asks-for-ios-7-where-it-reaches-ios-7.patch:40",
        ["_NSDataDeallocatorVM"] = "patch packages/s/swift-runtime/patches/overlays/the-overlay-of-foundation-asks-for-ios-7-where-it-reaches-ios-7.patch:40",
        ["_NSURLAddedToDirectoryDateKey"] = "stdlib/public/Darwin/Foundation/URL.swift:267 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLCanonicalPathKey"] = "stdlib/public/Darwin/Foundation/URL.swift:248 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLDocumentIdentifierKey"] = "stdlib/public/Darwin/Foundation/URL.swift:263 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLErrorBackgroundTaskCancelledReasonKey"] = "stdlib/public/Darwin/Foundation/NSError.swift:2025 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLErrorNetworkUnavailableReasonKey"] = "stdlib/public/Darwin/Foundation/NSError.swift:2031 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLFileProtectionKey"] = "stdlib/public/Darwin/Foundation/URL.swift:491 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLGenerationIdentifierKey"] = "stdlib/public/Darwin/Foundation/URL.swift:257 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLIsApplicationKey"] = "stdlib/public/Darwin/Foundation/URL.swift:124 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLSessionDownloadTaskResumeData"] = "stdlib/public/Darwin/Foundation/NSError.swift:2037 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLUbiquitousItemContainerDisplayNameKey"] = "stdlib/public/Darwin/Foundation/URL.swift:464 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLUbiquitousItemDownloadRequestedKey"] = "stdlib/public/Darwin/Foundation/URL.swift:460 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLUbiquitousItemDownloadingErrorKey"] = "patch packages/s/swift-runtime/patches/overlays/the-overlay-of-foundation-asks-for-ios-7-where-it-reaches-ios-7.patch:275",
        ["_NSURLUbiquitousItemDownloadingStatusKey"] = "patch packages/s/swift-runtime/patches/overlays/the-overlay-of-foundation-asks-for-ios-7-where-it-reaches-ios-7.patch:271",
        ["_NSURLUbiquitousItemIsSharedKey"] = "stdlib/public/Darwin/Foundation/URL.swift:469 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLUbiquitousItemUploadingErrorKey"] = "patch packages/s/swift-runtime/patches/overlays/the-overlay-of-foundation-asks-for-ios-7-where-it-reaches-ios-7.patch:279",
        ["_NSURLUbiquitousSharedItemCurrentUserPermissionsKey"] = "stdlib/public/Darwin/Foundation/URL.swift:477 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLUbiquitousSharedItemCurrentUserRoleKey"] = "stdlib/public/Darwin/Foundation/URL.swift:473 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLUbiquitousSharedItemMostRecentEditorNameComponentsKey"] = "stdlib/public/Darwin/Foundation/URL.swift:485 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLUbiquitousSharedItemOwnerNameComponentsKey"] = "stdlib/public/Darwin/Foundation/URL.swift:481 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeAvailableCapacityForImportantUsageKey"] = "stdlib/public/Darwin/Foundation/URL.swift:307 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeAvailableCapacityForOpportunisticUsageKey"] = "stdlib/public/Darwin/Foundation/URL.swift:312 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeIsEncryptedKey"] = "stdlib/public/Darwin/Foundation/URL.swift:404 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeIsRootFileSystemKey"] = "stdlib/public/Darwin/Foundation/URL.swift:408 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeSupportsAccessPermissionsKey"] = "stdlib/public/Darwin/Foundation/URL.swift:432 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeSupportsCompressionKey"] = "stdlib/public/Darwin/Foundation/URL.swift:412 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeSupportsExclusiveRenamingKey"] = "stdlib/public/Darwin/Foundation/URL.swift:424 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeSupportsFileCloningKey"] = "stdlib/public/Darwin/Foundation/URL.swift:416 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeSupportsImmutableFilesKey"] = "stdlib/public/Darwin/Foundation/URL.swift:428 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_NSURLVolumeSupportsSwapRenamingKey"] = "stdlib/public/Darwin/Foundation/URL.swift:420 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSDateInterval"] = "stdlib/public/Darwin/Foundation/DateInterval.swift:17 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSDimension"] = "stdlib/public/Darwin/Foundation/Measurement.swift:23 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSISO8601DateFormatter"] = "stdlib/public/Darwin/Foundation/JSONEncoder.swift:801 (and :2401) @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSMeasurement"] = "stdlib/public/Darwin/Foundation/Measurement.swift:236 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSOrderedCollectionChange"] = "stdlib/public/Darwin/Foundation/NSOrderedCollectionDifference.swift:16 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSOrderedCollectionDifference"] = "stdlib/public/Darwin/Foundation/NSOrderedCollectionDifference.swift:69 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSPersonNameComponents"] = "stdlib/public/Darwin/Foundation/PersonNameComponents.swift:15 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSURLComponents"] = "patch packages/s/swift-runtime/patches/overlays/the-overlay-of-foundation-asks-for-ios-7-where-it-reaches-ios-7.patch:345",
        ["_OBJC_CLASS_$_NSURLQueryItem"] = "stdlib/public/Darwin/Foundation/URLComponents.swift:384 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSURLSessionWebSocketMessage"] = "stdlib/public/Darwin/Foundation/URLSession.swift:15 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["_OBJC_CLASS_$_NSUnitConverterLinear"] = "stdlib/public/Darwin/Foundation/Measurement.swift:302 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["__CFURLComponentsGetURLFragmentAllowedCharacterSet"] = "stdlib/public/Darwin/Foundation/CharacterSet.swift:568 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["__CFURLComponentsGetURLHostAllowedCharacterSet"] = "stdlib/public/Darwin/Foundation/CharacterSet.swift:541 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["__CFURLComponentsGetURLPasswordAllowedCharacterSet"] = "stdlib/public/Darwin/Foundation/CharacterSet.swift:532 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["__CFURLComponentsGetURLPathAllowedCharacterSet"] = "stdlib/public/Darwin/Foundation/CharacterSet.swift:550 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["__CFURLComponentsGetURLQueryAllowedCharacterSet"] = "stdlib/public/Darwin/Foundation/CharacterSet.swift:559 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
        ["__CFURLComponentsGetURLUserAllowedCharacterSet"] = "stdlib/public/Darwin/Foundation/CharacterSet.swift:523 @ swiftlang/swift 282fe25d1757ff9974ade028d92111acdae6876a (swift-5.4.3-RELEASE)",
    },
    ["libswiftUIKit.dylib"] = {
        ["_NSURLThumbnailDictionaryKey"] = "stdlib/public/Darwin/UIKit/UIKit_FoundationExtensions.swift.gyb:82 @ swiftlang/swift 71d85a7c28eed8f46241649a723ddf23989139c6 (swift-5.2.5-RELEASE)",
        ["_OBJC_CLASS_$_UIFocusSystem"] = "stdlib/public/Darwin/UIKit/UIKit.swift:398 @ swiftlang/swift 71d85a7c28eed8f46241649a723ddf23989139c6 (swift-5.2.5-RELEASE)",
        ["_OBJC_CLASS_$_UIFontMetrics"] = "stdlib/public/Darwin/UIKit/UIKit.swift:357 @ swiftlang/swift 71d85a7c28eed8f46241649a723ddf23989139c6 (swift-5.2.5-RELEASE)",
        ["_UIContentSizeCategoryCompareToCategory"] = "stdlib/public/Darwin/UIKit/UIKit.swift:371 @ swiftlang/swift 71d85a7c28eed8f46241649a723ddf23989139c6 (swift-5.2.5-RELEASE)",
        ["_UIContentSizeCategoryIsAccessibilityCategory"] = "stdlib/public/Darwin/UIKit/UIKit.swift:366 @ swiftlang/swift 71d85a7c28eed8f46241649a723ddf23989139c6 (swift-5.2.5-RELEASE)",
    },
}

-- The same form for a package's own carried libraries, keyed by the package's name (the name a program's charon.libraries
-- gives it) and then by library file name. A package that ships a library with weak imports it guards itself declares them
-- here, with the line of each guard. Both readers see these rows: the check after a program's link reads them for a copy
-- of the package's library the program carries (platform.import_options), and the package's own on_test reads them with
-- compare(..., {exact = true}), so a row the build does not import is a difference too, not only a weak import no row names.
PACKAGES = {
    ["swift-system"] = {
        ["libswiftSystem.dylib"] = {
            ["_mach_port_destruct"] = "patch packages/s/swift-system/patches/route-the-libc-calls-through-csystem.patch:53 (csystem_mach_port_destruct tests the address at :53 before the call at :56)",
            ["_mach_port_guard"] = "patch packages/s/swift-system/patches/route-the-libc-calls-through-csystem.patch:37 (csystem_mach_port_guard tests the address at :37 before the call at :40)",
            ["_mach_port_unguard"] = "patch packages/s/swift-system/patches/route-the-libc-calls-through-csystem.patch:45 (csystem_mach_port_unguard tests the address at :45 before the call at :48)",
        },
    },
}

-- found: what dyld.unexported_weak_imports answers for the installed libraries. opt: what this build is, so that a row
-- is compared against the configuration that produced the libraries rather than against one fixed list - opt.imports is
-- what dyld.image_imports answers for the same libraries (every import, marked weak or strong) and opt.exported what
-- every image the process carries exports, opt.minimum and opt.backports name the configuration in what is reported.
-- Returns what differs, one line each. A weak import the toolchain's own code guards (apple.compat's GUARDED) is
-- answered there, for every image, and not here.
--
-- What each way a row can disagree means, because the table states the runtime's weak imports as it is built and a
-- build answers to the release it is made for:
--
--   * the library imports the symbol weakly and nothing the runtime exports does: the row has to be there, and a row
--     the toolchain's own code already answers for is a row that should not be (unchanged);
--   * the library imports the symbol *strongly*: that is what the port's headers' lowering makes of a declaration the
--     SDK marked for a later release, so the row is a claim to satisfy rather than a difference - the process must be
--     able to resolve it, and nothing the process carries exporting it is a load failure on the release this build is for;
--   * the library imports it not at all: the code behind the row's guard is compiled out at this minimum, so there is
--     nothing to guard here and nothing to fail. A configuration that does import it is held to the first rule.
--
-- opt.exact is for a package's own table (PACKAGES), whose one build is the configuration: a library the caller names in
-- found is then held to its rows both ways, so a row whose symbol the build does not import weakly is a difference as
-- well, and the rule above does not apply to it.
function compare(found, opt)
    opt = opt or {}
    local problems = {}
    local tested = compat.guarded()
    local known = merged()
    local imports = opt.imports or {}
    local exported = opt.exported or {}
    local where = string.format("at %s%s", tostring(opt.minimum or "an unstated release"),
                                opt.backports and " with the backports" or "")
    for _, library in ipairs(table.orderkeys(found)) do
        local recorded = known[library] or {}
        for _, symbol in ipairs(found[library]) do
            if tested[symbol:sub(2)] then
                if recorded[symbol] then
                    table.insert(problems, string.format("apple.runtime_guards records %s for %s, which apple.compat's GUARDED already answers for every image", symbol, library))
                end
            elseif not recorded[symbol] then
                table.insert(problems, string.format("%s weakly imports %s, which no library of the runtime exports, and apple.runtime_guards records no guard for it", library, symbol))
            end
        end
    end
    for _, library in ipairs(table.orderkeys(known)) do
        if found[library] then
            local strong = imports[library] or {}
            local weak = {}
            for _, symbol in ipairs(found[library]) do
                weak[symbol] = true
            end
            for _, symbol in ipairs(table.orderkeys(known[library])) do
                if opt.exact and not weak[symbol] then
                    table.insert(problems, string.format("apple.runtime_guards records %s for %s, which the build does not import as a weak import nothing it carries exports", symbol, library))
                elseif strong[symbol] == false then
                    -- the build imports it strongly: the row is satisfied by something the process carries, and a
                    -- process that carries nothing for it cannot load the library
                    if not exported[symbol] then
                        table.insert(problems, string.format("apple.runtime_guards records %s for %s, which imports it strongly " ..
                                                            "%s, and no library the process carries exports it: the image cannot be loaded", symbol, library, where))
                    end
                elseif strong[symbol] == nil and not imports[library] then
                    table.insert(problems, string.format("apple.runtime_guards records %s for %s and the build's own imports were " ..
                                                        "not given, so nothing says whether it holds", symbol, library))
                end
            end
        end
    end
    return problems
end

-- The rows of the runtime's table and of every package's own, by library file name: the one view both readers take, since
-- a carried copy is looked up by its file name whichever of the two tables declares it. Two tables that name one library
-- are a contradiction in the record, so that is refused here rather than one of them winning.
function merged()
    local all = {}
    for _, library in ipairs(table.orderkeys(GUARDS)) do
        all[library] = GUARDS[library]
    end
    for _, package in ipairs(table.orderkeys(PACKAGES)) do
        for _, library in ipairs(table.orderkeys(PACKAGES[package])) do
            if all[library] then
                raise("apple.runtime_guards declares the rows of %s twice, once for %s", library, package)
            end
            all[library] = PACKAGES[package][library]
        end
    end
    return all
end

-- The table, out the way that reaches. It is a plain global in xmake's module sandbox and an importer cannot read it
-- from there: measured on this xmake, `import("apple.runtime_guards", {anonymous = true})` answers with the module's
-- functions and with GUARDS nil, and `pairs(nil)` iterates nothing instead of raising - so a check written over
-- `guards.GUARDS` silently ran zero times, which is how tests/addon/dyld_test.lua's two guard-table cases came to say
-- nothing while the suite's own verdict was OK. Functions reach, data does not, so the data goes out as two.
function guards()
    return merged()
end

-- The rows of one library, or an empty table for a library the table says nothing about.
function rows(library)
    return merged()[library] or {}
end

-- Whether a package declares rows of its own: a copy of one of its libraries that a program carries is then read against
-- them (platform.lua's carries_guarded).
function declares(package)
    return PACKAGES[package] ~= nil
end
