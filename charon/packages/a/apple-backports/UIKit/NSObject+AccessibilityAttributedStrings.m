#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NSAttributedStringKey const UIAccessibilitySpeechAttributeQueueAnnouncement = @"UIAccessibilitySpeechAttributeQueueAnnouncement";
NSAttributedStringKey const UIAccessibilitySpeechAttributeIPANotation = @"UIAccessibilitySpeechAttributeIPANotation";
NSAttributedStringKey const UIAccessibilityTextAttributeHeadingLevel = @"UIAccessibilityTextAttributeHeadingLevel";
NSAttributedStringKey const UIAccessibilityTextAttributeCustom = @"UIAccessibilityTextAttributeCustom";

static const char CharonAttributedLabelKey, CharonAttributedHintKey, CharonAttributedValueKey;

static NSAttributedString *charon_attributed(id object, const void *key, NSString *plain)
{
    NSAttributedString *held = objc_getAssociatedObject(object, key);
    if (held && plain && [held.string isEqualToString:plain])
        return held;
    if (!plain)
        return nil;
    return [[NSAttributedString alloc] initWithString:plain];
}

static void charon_set_attributed(id object, const void *key, NSAttributedString *attributed)
{
    objc_setAssociatedObject(object, key, attributed, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@implementation NSObject (CharonAccessibilityAttributedStrings)

- (NSAttributedString *)accessibilityAttributedLabel
{
    return charon_attributed(self, &CharonAttributedLabelKey, self.accessibilityLabel);
}

- (void)setAccessibilityAttributedLabel:(NSAttributedString *)accessibilityAttributedLabel
{
    charon_set_attributed(self, &CharonAttributedLabelKey, accessibilityAttributedLabel);
    self.accessibilityLabel = accessibilityAttributedLabel.string;
}

- (NSAttributedString *)accessibilityAttributedHint
{
    return charon_attributed(self, &CharonAttributedHintKey, self.accessibilityHint);
}

- (void)setAccessibilityAttributedHint:(NSAttributedString *)accessibilityAttributedHint
{
    charon_set_attributed(self, &CharonAttributedHintKey, accessibilityAttributedHint);
    self.accessibilityHint = accessibilityAttributedHint.string;
}

- (NSAttributedString *)accessibilityAttributedValue
{
    return charon_attributed(self, &CharonAttributedValueKey, self.accessibilityValue);
}

- (void)setAccessibilityAttributedValue:(NSAttributedString *)accessibilityAttributedValue
{
    charon_set_attributed(self, &CharonAttributedValueKey, accessibilityAttributedValue);
    self.accessibilityValue = accessibilityAttributedValue.string;
}

@end
