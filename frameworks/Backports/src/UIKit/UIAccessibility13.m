#include "../revenant_impl.h"
#import "RevenantMenus.h"
#import <objc/runtime.h>

NSString *const BACKPORT_IMPL(UIAccessibilityOnOffSwitchLabelsDidChangeNotification) = @"UIAccessibilityOnOffSwitchLabelsDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification) = @"UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityVideoAutoplayStatusDidChangeNotification) = @"UIAccessibilityVideoAutoplayStatusDidChangeNotification";
NSAttributedStringKey const BACKPORT_IMPL(UIAccessibilitySpeechAttributeSpellOut) = @"UIAccessibilitySpeechAttributeSpellOut";
NSAttributedStringKey const BACKPORT_IMPL(UIAccessibilityTextAttributeContext) = @"UIAccessibilityTextAttributeContext";
NSString *const BACKPORT_IMPL(UIAccessibilityTextualContextConsole) = @"UIAccessibilityTextualContextConsole";
NSString *const BACKPORT_IMPL(UIAccessibilityTextualContextFileSystem) = @"UIAccessibilityTextualContextFileSystem";
NSString *const BACKPORT_IMPL(UIAccessibilityTextualContextMessaging) = @"UIAccessibilityTextualContextMessaging";
NSString *const BACKPORT_IMPL(UIAccessibilityTextualContextNarrative) = @"UIAccessibilityTextualContextNarrative";
NSString *const BACKPORT_IMPL(UIAccessibilityTextualContextSourceCode) = @"UIAccessibilityTextualContextSourceCode";
NSString *const BACKPORT_IMPL(UIAccessibilityTextualContextSpreadsheet) = @"UIAccessibilityTextualContextSpreadsheet";
NSString *const BACKPORT_IMPL(UIAccessibilityTextualContextWordProcessing) = @"UIAccessibilityTextualContextWordProcessing";

BOOL BACKPORT_IMPL(UIAccessibilityShouldDifferentiateWithoutColor)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsOnOffSwitchLabelsEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsVideoAutoplayEnabled)(void)
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
