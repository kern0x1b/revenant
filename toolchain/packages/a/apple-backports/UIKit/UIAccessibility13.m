#import "RevenantMenus.h"
#import <objc/runtime.h>

NSString *const UIAccessibilityOnOffSwitchLabelsDidChangeNotification = @"UIAccessibilityOnOffSwitchLabelsDidChangeNotification";
NSString *const UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification = @"UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification";
NSString *const UIAccessibilityVideoAutoplayStatusDidChangeNotification = @"UIAccessibilityVideoAutoplayStatusDidChangeNotification";
NSAttributedStringKey const UIAccessibilitySpeechAttributeSpellOut = @"UIAccessibilitySpeechAttributeSpellOut";
NSAttributedStringKey const UIAccessibilityTextAttributeContext = @"UIAccessibilityTextAttributeContext";
NSString *const UIAccessibilityTextualContextConsole = @"UIAccessibilityTextualContextConsole";
NSString *const UIAccessibilityTextualContextFileSystem = @"UIAccessibilityTextualContextFileSystem";
NSString *const UIAccessibilityTextualContextMessaging = @"UIAccessibilityTextualContextMessaging";
NSString *const UIAccessibilityTextualContextNarrative = @"UIAccessibilityTextualContextNarrative";
NSString *const UIAccessibilityTextualContextSourceCode = @"UIAccessibilityTextualContextSourceCode";
NSString *const UIAccessibilityTextualContextSpreadsheet = @"UIAccessibilityTextualContextSpreadsheet";
NSString *const UIAccessibilityTextualContextWordProcessing = @"UIAccessibilityTextualContextWordProcessing";

BOOL UIAccessibilityShouldDifferentiateWithoutColor(void)
{
    return NO;
}

BOOL UIAccessibilityIsOnOffSwitchLabelsEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityIsVideoAutoplayEnabled(void)
{
    return YES;
}

static void revenant_say_voice_control(void)
{
    revenant_menus_say_once(@"voice-control", @"Accessibility user input labels, textual context and interaction hints: iOS 6 has no Voice Control or dictation context to read them, so they are kept and read back and VoiceOver reads what it always read");
}

static const char revenant_plain_labels_key, revenant_attributed_labels_key, revenant_context_key, revenant_responds_key;

@implementation NSObject (RevenantAccessibility13)

- (NSArray<NSString *> *)accessibilityUserInputLabels
{
    NSArray *plain = objc_getAssociatedObject(self, &revenant_plain_labels_key);
    if (plain)
        return plain;
    NSArray *attributed = objc_getAssociatedObject(self, &revenant_attributed_labels_key);
    if (!attributed)
        return @[];
    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:attributed.count];
    for (NSAttributedString *label in attributed)
        [strings addObject:label.string];
    return strings;
}

- (void)setAccessibilityUserInputLabels:(NSArray<NSString *> *)accessibilityUserInputLabels
{
    revenant_say_voice_control();
    objc_setAssociatedObject(self, &revenant_attributed_labels_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &revenant_plain_labels_key, [accessibilityUserInputLabels copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSAttributedString *> *)accessibilityAttributedUserInputLabels
{
    NSArray *attributed = objc_getAssociatedObject(self, &revenant_attributed_labels_key);
    if (attributed)
        return attributed;
    NSArray *plain = objc_getAssociatedObject(self, &revenant_plain_labels_key);
    if (!plain)
        return nil;
    NSMutableArray *labels = [NSMutableArray arrayWithCapacity:plain.count];
    for (NSString *label in plain)
        [labels addObject:[[NSAttributedString alloc] initWithString:label]];
    return labels;
}

- (void)setAccessibilityAttributedUserInputLabels:(NSArray<NSAttributedString *> *)accessibilityAttributedUserInputLabels
{
    revenant_say_voice_control();
    objc_setAssociatedObject(self, &revenant_plain_labels_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &revenant_attributed_labels_key, [accessibilityAttributedUserInputLabels copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)accessibilityTextualContext
{
    return objc_getAssociatedObject(self, &revenant_context_key);
}

- (void)setAccessibilityTextualContext:(NSString *)accessibilityTextualContext
{
    revenant_say_voice_control();
    objc_setAssociatedObject(self, &revenant_context_key, [accessibilityTextualContext copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)accessibilityRespondsToUserInteraction
{
    return [objc_getAssociatedObject(self, &revenant_responds_key) boolValue];
}

- (void)setAccessibilityRespondsToUserInteraction:(BOOL)accessibilityRespondsToUserInteraction
{
    revenant_say_voice_control();
    objc_setAssociatedObject(self, &revenant_responds_key, @(accessibilityRespondsToUserInteraction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
