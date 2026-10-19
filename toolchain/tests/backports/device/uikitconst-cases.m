#import <UIKit/UIKit.h>
#import "uikitconst-cases.h"

void uikitconst_run(UIKitConstantsRecorder record)
{
    record(@"NSTextListMarkerBox", @"{box}");
    record(@"NSTextListMarkerCheck", @"{check}");
    record(@"NSTextListMarkerCircle", @"{circle}");
    record(@"NSTextListMarkerDecimal", @"{decimal}");
    record(@"NSTextListMarkerDiamond", @"{diamond}");
    record(@"NSTextListMarkerDisc", @"{disc}");
    record(@"NSTextListMarkerHyphen", @"{hyphen}");
    record(@"NSTextListMarkerLowercaseAlpha", @"{lower-alpha}");
    record(@"NSTextListMarkerLowercaseHexadecimal", @"{lower-hexadecimal}");
    record(@"NSTextListMarkerLowercaseLatin", @"{lower-latin}");
    record(@"NSTextListMarkerLowercaseRoman", @"{lower-roman}");
    record(@"NSTextListMarkerOctal", @"{octal}");
    record(@"NSTextListMarkerSquare", @"{square}");
    record(@"NSTextListMarkerUppercaseAlpha", @"{upper-alpha}");
    record(@"NSTextListMarkerUppercaseHexadecimal", @"{upper-hexadecimal}");
    record(@"NSTextListMarkerUppercaseLatin", @"{upper-latin}");
    record(@"NSTextListMarkerUppercaseRoman", @"{upper-roman}");
    record(@"NSTextStorageDidProcessEditingNotification", @"NSTextStorageDidProcessEditingNotification");
    record(@"NSTextStorageWillProcessEditingNotification", @"NSTextStorageWillProcessEditingNotification");
    record(@"NSUserActivityDocumentURLKey", @"NSUserActivityDocumentURL");
    record(@"UIAccessibilityAssistiveTouchStatusDidChangeNotification", @"UIAccessibilityAssistiveTouchStatusDidChangeNotification");
    record(@"UIAccessibilityHearingDevicePairedEarDidChangeNotification", @"UIAccessibilityHearingDevicePairedEarDidChangeNotification");
    record(@"UIActivityTypeAirDrop", @"com.apple.UIKit.activity.AirDrop");
    record(@"UIApplicationKeyboardExtensionPointIdentifier", @"com.apple.keyboard-service");
    record(@"UIApplicationLaunchOptionsBluetoothCentralsKey", @"UIApplicationLaunchOptionsBluetoothCentralsKey");
    record(@"UIApplicationLaunchOptionsBluetoothPeripheralsKey", @"UIApplicationLaunchOptionsBluetoothPeripheralsKey");
    record(@"UIApplicationLaunchOptionsCloudKitShareMetadataKey", @"UIApplicationLaunchOptionsCloudKitShareMetadataKey");
    record(@"UIApplicationLaunchOptionsUserActivityDictionaryKey", @"UIApplicationLaunchOptionsUserActivityDictionaryKey");
    record(@"UIApplicationLaunchOptionsUserActivityTypeKey", @"UIApplicationLaunchOptionsUserActivityTypeKey");
    record(@"UIApplicationStateRestorationSystemVersionKey", @"UIApplicationStateRestorationSystemVersion");
    record(@"UIApplicationStateRestorationTimestampKey", @"UIApplicationStateRestorationTimestamp");
    record(@"UIContentSizeCategoryDidChangeNotification", @"UIContentSizeCategoryDidChangeNotification");
    record(@"UIContentSizeCategoryNewValueKey", @"UIContentSizeCategoryNewValueKey");
    record(@"UIDocumentBrowserErrorDomain", @"com.apple.DocumentManager");
    record(@"UIFocusDidUpdateNotification", @"UIFocusDidUpdateNotification");
    record(@"UIFocusMovementDidFailNotification", @"UIFocusMovementDidFailNotification");
    record(@"UIFocusUpdateAnimationCoordinatorKey", @"UIFocusUpdateAnimationCoordinatorKey");
    record(@"UIFocusUpdateContextKey", @"UIFocusUpdateContextKey");
    record(@"UIImagePickerControllerLivePhoto", @"UIImagePickerControllerLivePhoto");
    record(@"UIPasteboardTypeAutomatic", @"com.apple.uikit.type-automatic");
    record(@"UITextFieldDidEndEditingReasonKey", @"UITextFieldEndEditingReasonKey");
    record(@"UIUserNotificationActionResponseTypedTextKey", @"UIUserNotificationActionResponseTypedTextKey");
    record(@"UIUserNotificationTextInputActionButtonTitleKey", @"UIUserNotificationTextInputActionButtonTitleKey");
    record(@"UIViewControllerShowDetailTargetDidChangeNotification", @"UIViewControllerShowDetailTargetDidChangeNotification");
    record(@"UISplitViewControllerAutomaticDimension", NSStringFromCGPoint(CGPointMake(UISplitViewControllerAutomaticDimension, 0)));
    record(@"NSTextListMarkerBox.class", NSStringFromClass([NSTextListMarkerBox class]));
    record(@"UIContentSizeCategoryDidChangeNotification.class", NSStringFromClass([UIContentSizeCategoryDidChangeNotification class]));
    record(@"UIActivityTypeAirDrop.isKindOfString", [UIActivityTypeAirDrop isKindOfClass:[NSString class]] ? @"yes" : @"no");
}

static UIAccessibilityCustomRotorItemResult *RevenantRotorResult(id element)
{
    return [[UIAccessibilityCustomRotorItemResult alloc] initWithTargetElement:element targetRange:nil];
}

void uikitrotor_run(UIKitConstantsRecorder record)
{
    UIAccessibilityCustomRotorSearchPredicate *predicate = [[UIAccessibilityCustomRotorSearchPredicate alloc] init];
    record(@"predicate.currentItemAtStart", predicate.currentItem ? @"set" : @"nil");
    record(@"predicate.directionAtStart", predicate.searchDirection == UIAccessibilityCustomRotorDirectionPrevious ? @"previous"
                                  : predicate.searchDirection == UIAccessibilityCustomRotorDirectionNext ? @"next" : @"other");

    __block NSUInteger calls = 0;
    __block UIAccessibilityCustomRotorSearchPredicate *seen = nil;
    UIAccessibilityCustomRotorSearch search = ^UIAccessibilityCustomRotorItemResult *(UIAccessibilityCustomRotorSearchPredicate *given) {
        calls++;
        seen = given;
        return nil;
    };

    UIAccessibilityCustomRotor *rotor = [[UIAccessibilityCustomRotor alloc] initWithName:@"Links" itemSearchBlock:search];
    record(@"rotor.name", rotor.name);
    record(@"rotor.itemSearchBlock.isSet", rotor.itemSearchBlock ? @"yes" : @"no");
    record(@"rotor.systemRotorType", rotor.systemRotorType == UIAccessibilityCustomSystemRotorTypeNone ? @"none" : @"other");

    rotor.itemSearchBlock ? rotor.itemSearchBlock(predicate) : (void)0;
    record(@"rotor.searchBlockCalls", [NSString stringWithFormat:@"%lu", (unsigned long)calls]);
    record(@"rotor.searchBlockSawThePredicate", seen == predicate ? @"same" : @"other");
    record(@"rotor.itemSearchBlock.isSet", rotor.itemSearchBlock ? @"yes" : @"no");

    rotor.name = @"Headings";
    record(@"rotor.nameAfterSet", rotor.name);
    record(@"rotor.attributedNameAfterNameSet", rotor.attributedName ? rotor.attributedName.string : @"(nil)");
    rotor.attributedName = [[NSAttributedString alloc] initWithString:@"Misspelled"];
    record(@"rotor.nameAfterAttributedSet", rotor.name);
    record(@"rotor.attributedNameString", rotor.attributedName.string);

    UIAccessibilityCustomRotor *typed = [[UIAccessibilityCustomRotor alloc] initWithSystemType:UIAccessibilityCustomSystemRotorTypeLink
                                                                                   itemSearchBlock:search];
    record(@"rotor.systemRotorTypeAfterInit", typed.systemRotorType == UIAccessibilityCustomSystemRotorTypeLink ? @"link" : @"other");

    UIAccessibilityCustomRotor *plain = [[UIAccessibilityCustomRotor alloc] init];
    record(@"rotor.plainName", plain.name ?: @"(nil)");
    record(@"rotor.plainSystemRotorType", plain.systemRotorType == UIAccessibilityCustomSystemRotorTypeNone ? @"none" : @"other");

    NSObject *target = [[NSObject alloc] init];
    UIAccessibilityCustomRotorItemResult *result = RevenantRotorResult(target);
    record(@"result.targetElementIsSame", result.targetElement == target ? @"same" : @"other");
    record(@"result.targetRange", result.targetRange ? @"set" : @"nil");
    result.targetElement = nil;
    record(@"result.targetElementAfterClear", result.targetElement ? @"set" : @"nil");

    predicate.currentItem = result;
    record(@"predicate.currentItemAfterSet", predicate.currentItem == result ? @"same" : @"other");
    predicate.searchDirection = UIAccessibilityCustomRotorDirectionPrevious;
    record(@"predicate.directionAfterSet", predicate.searchDirection == UIAccessibilityCustomRotorDirectionPrevious ? @"previous" : @"other");

    NSObject *exposer = [[NSObject alloc] init];
    record(@"rotors.unset", exposer.accessibilityCustomRotors ? @"set" : @"nil");
    exposer.accessibilityCustomRotors = @[rotor, typed];
    record(@"rotors.count", [NSString stringWithFormat:@"%lu", (unsigned long)exposer.accessibilityCustomRotors.count]);
    record(@"rotors.firstIsRotor", exposer.accessibilityCustomRotors.firstObject == rotor ? @"same" : @"other");
    exposer.accessibilityCustomRotors = nil;
    record(@"rotors.afterClear", exposer.accessibilityCustomRotors ? @"set" : @"nil");

    NSObject *actionTarget = [[NSObject alloc] init];
    UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:@"Links"
                                                                                       target:actionTarget
                                                                                     selector:@selector(description)];
    record(@"action.name", action.name ?: @"(nil)");
    record(@"action.attributedNameString", action.attributedName ? action.attributedName.string : @"(nil)");
    action.attributedName = [[NSAttributedString alloc] initWithString:@"Misspelled"];
    record(@"action.nameAfterAttributedNameSet", action.name ?: @"(nil)");
    record(@"action.attributedNameAfterSet", action.attributedName ? action.attributedName.string : @"(nil)");

    NSAttributedString *styled = [[NSAttributedString alloc] initWithString:@"Links"
                                                                  attributes:@{NSForegroundColorAttributeName: [UIColor redColor]}];
    UIAccessibilityCustomAction *attributed = [[UIAccessibilityCustomAction alloc] initWithAttributedName:styled
                                                                                                    target:actionTarget
                                                                                                  selector:@selector(description)];
    record(@"action.attributedInitName", attributed.name ?: @"(nil)");
    record(@"action.attributedInitString", attributed.attributedName ? attributed.attributedName.string : @"(nil)");
    UIAccessibilityCustomAction *nameless = [[UIAccessibilityCustomAction alloc] initWithName:nil target:nil selector:NULL];
    record(@"action.attributedNameWhenUnset", nameless.attributedName ? @"set" : @"nil");

    record(@"action.attributedInitKeepsAttributes",
           [attributed.attributedName attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] != nil ? @"keeps" : @"drops");
    record(@"action.attributedInitTargetIsSame", attributed.target == actionTarget ? @"same" : @"other");
    attributed.name = @"Renamed";
    record(@"action.attributedInitNameAfterSet", attributed.name ?: @"(nil)");
    record(@"action.attributedInitStringAfterNameSet", attributed.attributedName ? attributed.attributedName.string : @"(nil)");

    UIImage *badge = [UIImage new];
    UIAccessibilityCustomActionHandler handler = ^BOOL(UIAccessibilityCustomAction *a) { return NO; };

    UIAccessibilityCustomAction *attributedImage =
        [[UIAccessibilityCustomAction alloc] initWithAttributedName:styled
                                                              image:badge
                                                             target:actionTarget
                                                           selector:@selector(description)];
    record(@"action.attributedImage.name", attributedImage.name ?: @"(nil)");
    record(@"action.attributedImage.attributedString", attributedImage.attributedName ? attributedImage.attributedName.string : @"(nil)");
    record(@"action.attributedImage.keepsAttributes",
           [attributedImage.attributedName attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] != nil ? @"keeps" : @"drops");
    record(@"action.attributedImage.imageIsSame", attributedImage.image == badge ? @"same" : @"other");
    record(@"action.attributedImage.targetIsSame", attributedImage.target == actionTarget ? @"same" : @"other");
    record(@"action.attributedImage.selector", NSStringFromSelector(attributedImage.selector));
    record(@"action.attributedImage.actionHandlerIsNil", attributedImage.actionHandler ? @"set" : @"nil");
    attributedImage.name = @"Renamed";
    record(@"action.attributedImage.attributedStringAfterNameSet", attributedImage.attributedName ? attributedImage.attributedName.string : @"(nil)");
    record(@"action.attributedImage.keepsAttributesAfterNameSet",
           [attributedImage.attributedName attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] != nil ? @"keeps" : @"drops");

    UIAccessibilityCustomAction *attributedImageHandler =
        [[UIAccessibilityCustomAction alloc] initWithAttributedName:styled
                                                              image:badge
                                                     actionHandler:handler];
    record(@"action.attributedImageHandler.name", attributedImageHandler.name ?: @"(nil)");
    record(@"action.attributedImageHandler.attributedString", attributedImageHandler.attributedName ? attributedImageHandler.attributedName.string : @"(nil)");
    record(@"action.attributedImageHandler.keepsAttributes",
           [attributedImageHandler.attributedName attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] != nil ? @"keeps" : @"drops");
    record(@"action.attributedImageHandler.imageIsSame", attributedImageHandler.image == badge ? @"same" : @"other");
    record(@"action.attributedImageHandler.actionHandlerIsSet", attributedImageHandler.actionHandler ? @"set" : @"nil");
    record(@"action.attributedImageHandler.targetIsNil", attributedImageHandler.target ? @"set" : @"nil");
    record(@"action.attributedImageHandler.selectorIsNull", attributedImageHandler.selector ? @"set" : @"null");
    UIAccessibilityCustomAction *plainImageHandler =
        [[UIAccessibilityCustomAction alloc] initWithName:@"Links" image:badge actionHandler:handler];
    record(@"action.plainImageHandler.targetIsNil", plainImageHandler.target ? @"set" : @"nil");
    record(@"action.plainImageHandler.selectorIsNull", plainImageHandler.selector ? @"set" : @"null");
    record(@"action.attributedOnly.imageIsNil", attributed.image ? @"set" : @"nil");
    record(@"action.attributedOnly.actionHandlerIsNil", attributed.actionHandler ? @"set" : @"nil");
}
