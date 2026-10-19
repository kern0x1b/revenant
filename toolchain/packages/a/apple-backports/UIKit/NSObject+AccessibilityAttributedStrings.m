#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NSAttributedStringKey const UIAccessibilitySpeechAttributeQueueAnnouncement = @"UIAccessibilitySpeechAttributeQueueAnnouncement";
NSAttributedStringKey const UIAccessibilitySpeechAttributeIPANotation = @"UIAccessibilitySpeechAttributeIPANotation";
NSAttributedStringKey const UIAccessibilityTextAttributeHeadingLevel = @"UIAccessibilityTextAttributeHeadingLevel";
NSAttributedStringKey const UIAccessibilityTextAttributeCustom = @"UIAccessibilityTextAttributeCustom";

static const char RevenantAttributedLabelKey, RevenantAttributedHintKey, RevenantAttributedValueKey;

static NSAttributedString *revenant_attributed(id object, const void *key, NSString *plain)
{
    NSAttributedString *held = objc_getAssociatedObject(object, key);
    if (held && plain && [held.string isEqualToString:plain])
        return held;
    if (!plain)
        return nil;
    return [[NSAttributedString alloc] initWithString:plain];
}

static void revenant_set_attributed(id object, const void *key, NSAttributedString *attributed)
{
    objc_setAssociatedObject(object, key, attributed, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@implementation NSObject (RevenantAccessibilityAttributedStrings)

- (NSAttributedString *)accessibilityAttributedLabel
{
    return revenant_attributed(self, &RevenantAttributedLabelKey, self.accessibilityLabel);
}

- (void)setAccessibilityAttributedLabel:(NSAttributedString *)accessibilityAttributedLabel
{
    revenant_set_attributed(self, &RevenantAttributedLabelKey, accessibilityAttributedLabel);
    self.accessibilityLabel = accessibilityAttributedLabel.string;
}

- (NSAttributedString *)accessibilityAttributedHint
{
    return revenant_attributed(self, &RevenantAttributedHintKey, self.accessibilityHint);
}

- (void)setAccessibilityAttributedHint:(NSAttributedString *)accessibilityAttributedHint
{
    revenant_set_attributed(self, &RevenantAttributedHintKey, accessibilityAttributedHint);
    self.accessibilityHint = accessibilityAttributedHint.string;
}

- (NSAttributedString *)accessibilityAttributedValue
{
    return revenant_attributed(self, &RevenantAttributedValueKey, self.accessibilityValue);
}

- (void)setAccessibilityAttributedValue:(NSAttributedString *)accessibilityAttributedValue
{
    revenant_set_attributed(self, &RevenantAttributedValueKey, accessibilityAttributedValue);
    self.accessibilityValue = accessibilityAttributedValue.string;
}

@end
