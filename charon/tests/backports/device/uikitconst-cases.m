#import <UIKit/UIKit.h>
#import "uikitconst-cases.h"

// The value of every exported string constant and the one dimension this backport carries, and what
// a rotor answers for its name, its search block and the element it stops on. The host records these
// and the device is held to them; a value that is not in this file is not carried at all.
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
    // What a string constant is, not only what it says: a constant an application compares with
    // isEqualToString: must be an NSString and not a tagged pointer or some other object.
    record(@"NSTextListMarkerBox.class", NSStringFromClass([NSTextListMarkerBox class]));
    record(@"UIContentSizeCategoryDidChangeNotification.class", NSStringFromClass([UIContentSizeCategoryDidChangeNotification class]));
    record(@"UIActivityTypeAirDrop.isKindOfString", [UIActivityTypeAirDrop isKindOfClass:[NSString class]] ? @"yes" : @"no");
}

static UIAccessibilityCustomRotorItemResult *CharonRotorResult(id element)
{
    return [[UIAccessibilityCustomRotorItemResult alloc] initWithTargetElement:element targetRange:nil];
}

// A rotor holds a name, a search block and the type it was made for, and an item result holds the
// element it stops on and the range inside it, weakly. The system rotor type defaults to None and
// an item made by hand holds what it was given.
void uikitrotor_run(UIKitConstantsRecorder record)
{
    UIAccessibilityCustomRotorSearchPredicate *predicate = [[UIAccessibilityCustomRotorSearchPredicate alloc] init];
    record(@"predicate.currentItemAtStart", predicate.currentItem ? @"set" : @"nil");
    // Previous is the first case of the enum, so a fresh predicate is searching backwards, not
    // forwards: recorded by name in both directions so the case is unambiguous.
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

    // The block the rotor holds is the one it was given, and it is called with the predicate.
    rotor.itemSearchBlock ? rotor.itemSearchBlock(predicate) : (void)0;
    record(@"rotor.searchBlockCalls", [NSString stringWithFormat:@"%lu", (unsigned long)calls]);
    record(@"rotor.searchBlockSawThePredicate", seen == predicate ? @"same" : @"other");
    record(@"rotor.itemSearchBlock.isSet", rotor.itemSearchBlock ? @"yes" : @"no");

    // The name and the attributed name are two faces of one thing, as the header says of them.
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
    UIAccessibilityCustomRotorItemResult *result = CharonRotorResult(target);
    record(@"result.targetElementIsSame", result.targetElement == target ? @"same" : @"other");
    record(@"result.targetRange", result.targetRange ? @"set" : @"nil");
    result.targetElement = nil;
    record(@"result.targetElementAfterClear", result.targetElement ? @"set" : @"nil");

    predicate.currentItem = result;
    record(@"predicate.currentItemAfterSet", predicate.currentItem == result ? @"same" : @"other");
    predicate.searchDirection = UIAccessibilityCustomRotorDirectionPrevious;
    record(@"predicate.directionAfterSet", predicate.searchDirection == UIAccessibilityCustomRotorDirectionPrevious ? @"previous" : @"other");

    // Every object can expose rotors, not only accessibility elements.
    NSObject *exposer = [[NSObject alloc] init];
    record(@"rotors.unset", exposer.accessibilityCustomRotors ? @"set" : @"nil");
    exposer.accessibilityCustomRotors = @[rotor, typed];
    record(@"rotors.count", [NSString stringWithFormat:@"%lu", (unsigned long)exposer.accessibilityCustomRotors.count]);
    record(@"rotors.firstIsRotor", exposer.accessibilityCustomRotors.firstObject == rotor ? @"same" : @"other");
    exposer.accessibilityCustomRotors = nil;
    record(@"rotors.afterClear", exposer.accessibilityCustomRotors ? @"set" : @"nil");

    // A custom action's attributed name, which is the rotor's arrangement again on the other of the
    // two objects an assistive technology is handed: a custom action is made with a name and this
    // release's own carries one, so what the host answers for it is what the port answers for it.
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
    // the port's getter answers nil for an action with no name, so the host is asked what it answers
    // there too; nothing in the port is a guess when the host has an answer
    // named the way the recorder can tell nil from an empty string: record() stores a nil as "",
    // so each is asked whether it is there first
    UIAccessibilityCustomAction *nameless = [[UIAccessibilityCustomAction alloc] initWithName:nil target:nil selector:NULL];
    record(@"action.attributedNameWhenUnset", nameless.attributedName ? @"set" : @"nil");

    record(@"action.attributedInitKeepsAttributes",
           [attributed.attributedName attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] != nil ? @"keeps" : @"drops");
    record(@"action.attributedInitTargetIsSame", attributed.target == actionTarget ? @"same" : @"other");
    attributed.name = @"Renamed";
    record(@"action.attributedInitNameAfterSet", attributed.name ?: @"(nil)");
    record(@"action.attributedInitStringAfterNameSet", attributed.attributedName ? attributed.attributedName.string : @"(nil)");

    // The two iOS 14 initialisers that take an ATTRIBUTED name AND an image: the ones the header
    // declares beside the 11.0 attributed form and the 14.0 plain forms. What they add over the 11.0
    // form is the image, and what they answer for the target and the handler is what the plain forms
    // answer, so both are read against those here in the same run.
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
    // the two names are one name in two spellings here too, so setting the plain one moves the string
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
    // the host carries no target and no selector on a handler form, and this records that the plain
    // handler form does not either, so the port's two handler forms agree with each other
    record(@"action.attributedImageHandler.targetIsNil", attributedImageHandler.target ? @"set" : @"nil");
    record(@"action.attributedImageHandler.selectorIsNull", attributedImageHandler.selector ? @"set" : @"null");
    UIAccessibilityCustomAction *plainImageHandler =
        [[UIAccessibilityCustomAction alloc] initWithName:@"Links" image:badge actionHandler:handler];
    record(@"action.plainImageHandler.targetIsNil", plainImageHandler.target ? @"set" : @"nil");
    record(@"action.plainImageHandler.selectorIsNull", plainImageHandler.selector ? @"set" : @"null");
    // and the 11.0 form `attributed` above answers no image, which is what these two add and nothing else
    record(@"action.attributedOnly.imageIsNil", attributed.image ? @"set" : @"nil");
    record(@"action.attributedOnly.actionHandlerIsNil", attributed.actionHandler ? @"set" : @"nil");
}
