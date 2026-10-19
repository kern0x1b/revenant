#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "check.h"

static NSString *image_of_method(Class class, SEL selector)
{
    Method method = class_getInstanceMethod(class, selector);
    Dl_info info;
    if (!method || !dladdr((void *)method_getImplementation(method), &info) || !info.dli_fname)
        return @"<missing>";
    return @(info.dli_fname).lastPathComponent;
}

static void thermal_state(void)
{
    NSProcessInfo *info = NSProcessInfo.processInfo;
    CHECK_EQUAL(image_of_method([NSProcessInfo class], @selector(thermalState)), @"libFoundationBackports.dylib", "-[NSProcessInfo thermalState] comes from the backports");
    CHECK(info.thermalState == NSProcessInfoThermalStateNominal, "the thermal state is nominal");
    CHECK(info.thermalState == info.thermalState, "the thermal state is the same when read again");
    CHECK_EQUAL(NSProcessInfoThermalStateDidChangeNotification, @"NSProcessInfoThermalStateDidChangeNotification", "the notification is the release's string");
    __block int heard = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoThermalStateDidChangeNotification object:nil queue:nil
                                                                usingBlock:^(NSNotification *note) { heard++; }];
    (void)info.thermalState;
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    CHECK(heard == 0, "the notification is not posted, since the state never changes");
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

static void picker_presets(void)
{
    Class picker = NSClassFromString(@"UIImagePickerController");
    CHECK(picker != Nil, "UIImagePickerController is there");
    CHECK_EQUAL(image_of_method(picker, @selector(imageExportPreset)), @"libUIKitBackports.dylib", "-imageExportPreset comes from the backports");
    CHECK_EQUAL(image_of_method(picker, @selector(setVideoExportPreset:)), @"libUIKitBackports.dylib", "-setVideoExportPreset: comes from the backports");
    UIImagePickerController *controller = [[UIImagePickerController alloc] init];
    CHECK(controller != nil, "a picker can be made");
    CHECK(controller.imageExportPreset == UIImagePickerControllerImageURLExportPresetCompatible, "a fresh picker exports the compatible format");
    CHECK(controller.videoExportPreset == nil, "a fresh picker has no video preset");
    controller.imageExportPreset = UIImagePickerControllerImageURLExportPresetCurrent;
    CHECK(controller.imageExportPreset == UIImagePickerControllerImageURLExportPresetCurrent, "the image preset is handed back as it was set");
    NSMutableString *preset = [NSMutableString stringWithString:@"AVAssetExportPresetPassthrough"];
    controller.videoExportPreset = preset;
    [preset appendString:@"X"];
    CHECK_EQUAL(controller.videoExportPreset, @"AVAssetExportPresetPassthrough", "the video preset is copied");
    controller.videoExportPreset = nil;
    CHECK(controller.videoExportPreset == nil, "the video preset can be taken away");
    UIImagePickerController *other = [[UIImagePickerController alloc] init];
    CHECK(other.imageExportPreset == UIImagePickerControllerImageURLExportPresetCompatible, "the preset belongs to the picker it was set on");
    CHECK_EQUAL(UIImagePickerControllerPHAsset, @"UIImagePickerControllerPHAsset", "UIImagePickerControllerPHAsset carries its own name");
}

static void absences(void)
{
    CHECK_EQUAL(image_of_method([UIScrollView class], @selector(horizontalScrollIndicatorInsets)), @"libUIKitBackports.dylib", "horizontalScrollIndicatorInsets comes from the backports, held by uikit12");
    CHECK_EQUAL(image_of_method([UIScrollView class], @selector(verticalScrollIndicatorInsets)), @"libUIKitBackports.dylib", "verticalScrollIndicatorInsets comes from the backports, held by uikit12");
    CHECK([UIScrollView instancesRespondToSelector:@selector(scrollIndicatorInsets)], "the release's own scrollIndicatorInsets stays");
    CHECK(NSClassFromString(@"UIPencilInteraction") == Nil, "UIPencilInteraction is absent");
    CHECK(dlsym(RTLD_DEFAULT, "UIGuidedAccessConfigureAccessibilityFeatures") == NULL, "UIGuidedAccessConfigureAccessibilityFeatures is absent");
    CHECK(dlsym(RTLD_DEFAULT, "UIDocumentBrowserErrorDomain") == NULL, "UIDocumentBrowserErrorDomain is absent");
}

static void volume_keys(void)
{
    CHECK_EQUAL(NSURLVolumeAvailableCapacityForImportantUsageKey, NSURLVolumeAvailableCapacityKey, "the important usage key is the string of the available capacity key");
    CHECK_EQUAL(NSURLVolumeAvailableCapacityForOpportunisticUsageKey, @"NSURLVolumeAvailableCapacityForOpportunisticUsageKey", "the opportunistic key carries its own name");
    CHECK_EQUAL(NSURLVolumeSupportsImmutableFilesKey, @"NSURLVolumeSupportsImmutableFilesKey", "the immutable files key carries its own name");
    CHECK_EQUAL(NSURLVolumeSupportsAccessPermissionsKey, @"NSURLVolumeSupportsAccessPermissionsKey", "the access permissions key carries its own name");
    NSURL *root = [NSURL fileURLWithPath:@"/"];
    NSNumber *available = nil, *important = nil, *opportunistic = nil, *immutable = nil;
    NSError *error = nil;
    BOOL got = [root getResourceValue:&available forKey:NSURLVolumeAvailableCapacityKey error:&error];
    CHECK(got && available != nil, "the release answers the available capacity");
    got = [root getResourceValue:&important forKey:NSURLVolumeAvailableCapacityForImportantUsageKey error:&error];
    CHECK(got && important != nil, "the important usage key is answered");
    CHECK(important != nil && available != nil && llabs(important.longLongValue - available.longLongValue) < (1 << 20), "the important usage capacity is the available capacity");
    got = [root getResourceValue:&opportunistic forKey:NSURLVolumeAvailableCapacityForOpportunisticUsageKey error:&error];
    CHECK(got && opportunistic == nil && error == nil, "the release answers success and no value for the opportunistic key");
    got = [root getResourceValue:&immutable forKey:NSURLVolumeSupportsImmutableFilesKey error:&error];
    CHECK(got && immutable == nil, "the release answers success and no value for the immutable files key");
    NSDictionary *values = [root resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey, NSURLVolumeAvailableCapacityForOpportunisticUsageKey] error:&error];
    CHECK(values.count == 1 && values[NSURLVolumeAvailableCapacityForImportantUsageKey] != nil, "the dictionary holds the important usage capacity and leaves the other out");
}

static void failure_key(void)
{
    CHECK_EQUAL(NSLocalizedFailureErrorKey, @"NSLocalizedFailure", "the failure key carries the string of iOS 11");
    Dl_info info;
    void *address = dlsym(RTLD_DEFAULT, "NSLocalizedFailureErrorKey");
    CHECK(address && dladdr(address, &info) && [@(info.dli_fname).lastPathComponent isEqualToString:@"libFoundationBackports.dylib"], "the failure key comes from the backports");
    NSError *error = [NSError errorWithDomain:@"charon" code:1 userInfo:@{NSLocalizedFailureErrorKey: @"The file could not be saved.", NSLocalizedFailureReasonErrorKey: @"The disk is full."}];
    CHECK_EQUAL(error.userInfo[NSLocalizedFailureErrorKey], @"The file could not be saved.", "an error keeps the failure in its user info");
    // The expected descriptions are what the host's Foundation answers, facts/Foundation/NSError.md.
    CHECK_EQUAL(error.localizedDescription, @"The file could not be saved. The disk is full.", "the description is the failure and the reason");
    CHECK_EQUAL([NSError errorWithDomain:@"charon" code:1 userInfo:@{NSLocalizedFailureErrorKey: @"Only the failure."}].localizedDescription, @"Only the failure.", "the failure alone is the description when there is no reason");
    NSError *missing = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:@{NSLocalizedFailureErrorKey: @"Only the failure."}];
    NSString *generated = missing.localizedFailureReason;
    CHECK_EQUAL(missing.localizedDescription, generated.length ? [@"Only the failure. " stringByAppendingString:generated] : @"Only the failure.", "the failure takes the reason the release generates for the domain and code, when it generates one");
    printf("note NSCocoaErrorDomain 4: the release's reason is %s; with a failure the description reads: %s; without one: %s\n", generated ? generated.UTF8String : "nil",
           missing.localizedDescription.UTF8String, [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil].localizedDescription.UTF8String);
    NSError *described = [NSError errorWithDomain:@"charon" code:1 userInfo:@{NSLocalizedDescriptionKey: @"The description.", NSLocalizedFailureErrorKey: @"Only the failure.", NSLocalizedFailureReasonErrorKey: @"The disk is full."}];
    CHECK_EQUAL(described.localizedDescription, @"The description.", "the description key comes before the failure");
    CFStringRef keys[] = {(__bridge CFStringRef)NSLocalizedFailureErrorKey, (__bridge CFStringRef)NSLocalizedFailureReasonErrorKey};
    CFTypeRef values[] = {CFSTR("The file could not be saved."), CFSTR("The disk is full.")};
    CFDictionaryRef bridgedInfo = CFDictionaryCreate(NULL, (const void **)keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFErrorRef bridged = CFErrorCreate(NULL, CFSTR("charon"), 1, bridgedInfo);
    CFRelease(bridgedInfo);
    CHECK_EQUAL(((__bridge NSError *)bridged).localizedDescription, @"The file could not be saved. The disk is full.", "an error made by CFErrorCreate describes itself the same way");
    printf("note CFErrorCreate made a %s\n", object_getClassName((__bridge id)bridged));
    CFStringRef copied = CFErrorCopyDescription(bridged);
    printf("note CFErrorCopyDescription reads: %s\n", [(__bridge NSString *)copied UTF8String]);
    CFRelease(copied);
    CFRelease(bridged);
    [NSError setUserInfoValueProviderForDomain:@"charon.provided" provider:^id(NSError *provided, NSErrorUserInfoKey key) {
        if ([key isEqualToString:NSLocalizedDescriptionKey] && provided.code == 1)
            return @"Provided description.";
        if ([key isEqualToString:NSLocalizedFailureErrorKey])
            return @"Provided failure.";
        if ([key isEqualToString:NSLocalizedFailureReasonErrorKey] && provided.code != 3)
            return @"Provided reason.";
        return nil;
    }];
    CHECK_EQUAL([NSError errorWithDomain:@"charon.provided" code:1 userInfo:@{NSLocalizedFailureErrorKey: @"Own failure."}].localizedDescription, @"Own failure. Provided reason.", "the failure of the user info comes before the provider's description");
    CHECK_EQUAL([NSError errorWithDomain:@"charon.provided" code:1 userInfo:nil].localizedDescription, @"Provided description.", "the provider's description comes before its failure");
    CHECK_EQUAL([NSError errorWithDomain:@"charon.provided" code:2 userInfo:nil].localizedDescription, @"Provided failure. Provided reason.", "the provider's failure takes the provider's reason");
    CHECK_EQUAL([NSError errorWithDomain:@"charon.provided" code:3 userInfo:nil].localizedDescription, @"Provided failure.", "the provider's failure alone when nothing gives a reason");
    CHECK_EQUAL([NSError errorWithDomain:@"charon.provided" code:2 userInfo:@{NSLocalizedFailureReasonErrorKey: @"Own reason."}].localizedDescription, @"Provided failure. Own reason.", "the provider's failure takes the reason of the user info");
    [NSError setUserInfoValueProviderForDomain:@"charon.provided" provider:nil];
}

static void swipe_actions(void)
{
    NSString *library = @"libUIKitBackports.dylib";
    CHECK_EQUAL(image_of_method([UIContextualAction class], @selector(title)), library, "-[UIContextualAction title] comes from the backports");
    CHECK_EQUAL(image_of_method([UISwipeActionsConfiguration class], @selector(actions)), library, "-[UISwipeActionsConfiguration actions] comes from the backports");
    UIContextualActionHandler handler = ^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) { completion(YES); };
    UIContextualAction *normal = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Read" handler:handler];
    UIContextualAction *destructive = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:nil handler:handler];
    CGFloat red, green, blue, alpha;
    CHECK(normal.style == UIContextualActionStyleNormal && [normal.title isEqualToString:@"Read"] && normal.handler == handler && normal.image == nil, "an action holds what it was made with");
    CHECK([normal.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha] && red > 0.77 && red < 0.79 && blue > 0.79 && blue < 0.81, "a normal action is grey");
    CHECK([destructive.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha] && red > 0.9 && green < 0.3, "a destructive action is red");
    NSMutableString *title = [NSMutableString stringWithString:@"x"];
    normal.title = title;
    [title appendString:@"y"];
    CHECK_EQUAL(normal.title, @"x", "the title is copied");
    UIImage *image = [[UIImage alloc] init];
    normal.image = image;
    CHECK(normal.image == image, "the image is kept as it is");
    normal.backgroundColor = [UIColor blueColor];
    normal.backgroundColor = nil;
    CHECK([normal.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha] && red > 0.77 && red < 0.79, "a nil background puts the style's colour back");
    UIContextualAction *bare = [[UIContextualAction alloc] init];
    CHECK(bare.backgroundColor == nil && bare.title == nil && bare.handler == nil, "an action made by init holds nothing");
    NSMutableArray *held = [NSMutableArray arrayWithObject:normal];
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:held];
    [held addObject:destructive];
    CHECK(configuration.actions == held && configuration.actions.count == 2, "a configuration keeps the array it was given");
    CHECK(configuration.performsFirstActionWithFullSwipe, "a full swipe performs the first action");
    configuration.performsFirstActionWithFullSwipe = NO;
    CHECK(!configuration.performsFirstActionWithFullSwipe, "a full swipe can be turned off");
    CHECK([UISwipeActionsConfiguration configurationWithActions:nil].actions == nil, "a configuration given no actions has none");
    CHECK(![normal respondsToSelector:@selector(copyWithZone:)], "an action is not copied");
}

static void regular_expressions(void)
{
    NSError *error = nil;
    NSRegularExpression *named = [NSRegularExpression regularExpressionWithPattern:@"(?<word>a+)" options:0 error:&error];
    CHECK(named == nil && error != nil, "a pattern that names a group does not compile on this release");
    NSTextCheckingResult *match = [[NSRegularExpression regularExpressionWithPattern:@"(a+)" options:0 error:NULL] firstMatchInString:@"baa" options:0 range:NSMakeRange(0, 3)];
    CHECK([match respondsToSelector:NSSelectorFromString(@"rangeWithName:")], "rangeWithName: is there");
    NSRange unnamed = [match rangeWithName:@"word"];
    CHECK(unnamed.location == NSNotFound && unnamed.length == 0, "a name the pattern does not carry has no range, as on iOS 11");
    CHECK([match rangeAtIndex:1].location == 1 && [match rangeAtIndex:1].length == 2, "and the numbered group is still where it was");
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-trash-check.txt"];
    [@"x" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    SEL trash = NSSelectorFromString(@"trashItemAtURL:resultingItemURL:error:");
    CHECK([NSFileManager instancesRespondToSelector:trash], "the release has trashItemAtURL:resultingItemURL:error: itself");
    NSURL *moved = nil;
    NSError *trashError = nil;
    BOOL trashed = ((BOOL (*)(id, SEL, NSURL *, NSURL **, NSError **))objc_msgSend)([NSFileManager defaultManager], trash, [NSURL fileURLWithPath:path], &moved, &trashError);
    CHECK(!trashed && moved == nil && trashError.code == 3328 && [trashError.domain isEqualToString:NSCocoaErrorDomain], "trashing answers the feature unsupported error");
    CHECK([[NSFileManager defaultManager] fileExistsAtPath:path], "the item is still where it was");
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    CHECK(NSClassFromString(@"NSFileProviderService") == Nil, "NSFileProviderService is absent");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        thermal_state();
        picker_presets();
        absences();
        volume_keys();
        failure_key();
        swipe_actions();
        regular_expressions();
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
