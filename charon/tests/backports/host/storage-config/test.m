#import <UIKit/UIKit.h>
#include <stdio.h>

// Properties the port had declared with @dynamic and never built, checked on the same values in two processes: the host's classes in
// one, and the port's classes (renamed by run.sh with -D, so this file's names mean the port's classes in that build). Each line is
// "check<TAB>value"; the two outputs must be the same line for line.

typedef id (*InitFn)(id, SEL);

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *number(long long value)
{
    return [NSString stringWithFormat:@"%lld", value];
}

// A class without a designated initialiser in the header: the runtime's init, so both sides are made the same way.
static id plain_new(Class cls)
{
    SEL initSelector = @selector(init);
    return ((InitFn)[[cls alloc] methodForSelector:initSelector])([cls alloc], initSelector);
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        // The external URL options' event attribution is copied on set and cleared by nil; the open-URL options' is nil (read-only).
        UISceneOpenURLOptions *open = plain_new([UISceneOpenURLOptions class]);
        report("open-url-attribution-default", [open eventAttribution] ? @"set" : @"nil");
        UISceneOpenExternalURLOptions *external = plain_new([UISceneOpenExternalURLOptions class]);
        report("external-attribution-default", [external eventAttribution] ? @"set" : @"nil");
        NSMutableString *attribution = [NSMutableString stringWithString:@"attr"];
        [external setEventAttribution:(UIEventAttribution *)attribution];
        report("external-attribution-copied", [(NSString *)[external eventAttribution] description]);
        report("external-attribution-same-object", yes_no([external eventAttribution] == (UIEventAttribution *)attribution));
        [external setEventAttribution:nil];
        report("external-attribution-cleared", [external eventAttribution] ? @"set" : @"nil");

        // The activation request's join behaviour is kept as the integer given.
        UISceneActivationRequestOptions *request = plain_new([UISceneActivationRequestOptions class]);
        report("request-join-default", number(request.collectionJoinBehavior));
        request.collectionJoinBehavior = 1;
        report("request-join-set", number(request.collectionJoinBehavior));

        // Background configuration: no image and mode 0 by default; the mode is kept and a copy keeps the mode it had.
        UIBackgroundConfiguration *background = [UIBackgroundConfiguration clearConfiguration];
        report("background-image-default", background.image ? @"set" : @"nil");
        report("background-mode-default", number(background.imageContentMode));
        background.imageContentMode = UIViewContentModeCenter;
        report("background-mode-set", number(background.imageContentMode));
        UIBackgroundConfiguration *copied = [background copy];
        background.imageContentMode = UIViewContentModeScaleAspectFit;
        report("background-copy-keeps-mode", number(copied.imageContentMode));
        report("background-mode-after-change", number(background.imageContentMode));
        background.image = (UIImage *)[NSObject new];
        report("background-image-set", background.image ? @"set" : @"nil");
        background.image = nil;
        report("background-image-cleared", background.image ? @"set" : @"nil");

        // Context menu configuration: no identifiers, a large badge count (NSIntegerMax) and element order 0 by default. The identifiers are
        // copied on set; the badge count and the order are kept.
        UIContextMenuConfiguration *menu = [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:nil];
        report("menu-secondary-default", menu.secondaryItemIdentifiers ? @"set" : @"nil");
        report("menu-badge-default", number(menu.badgeCount));
        report("menu-order-default", number(menu.preferredMenuElementOrder));
        NSMutableSet *identifiers = [NSMutableSet setWithObject:@"a"];
        menu.secondaryItemIdentifiers = identifiers;
        [identifiers addObject:@"b"];
        report("menu-secondary-count", number(menu.secondaryItemIdentifiers.count));
        report("menu-secondary-same-object", yes_no(menu.secondaryItemIdentifiers == identifiers));
        menu.secondaryItemIdentifiers = nil;
        report("menu-secondary-cleared", menu.secondaryItemIdentifiers ? @"set" : @"nil");
        menu.badgeCount = 3;
        report("menu-badge-set", number(menu.badgeCount));
        menu.preferredMenuElementOrder = UIContextMenuConfigurationElementOrderPriority;
        report("menu-order-set", number(menu.preferredMenuElementOrder));
        UIContextMenuConfiguration *named = [UIContextMenuConfiguration configurationWithIdentifier:@"x" previewProvider:nil actionProvider:nil];
        report("menu-identifier-kept", [named identifier] ? [(NSString *)[named identifier] description] : @"nil");

        // The renderer format's preferred range: automatic by default, kept as set, and a copy does not follow later changes.
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        report("renderer-range-default", number(format.preferredRange));
        UIGraphicsImageRendererFormat *formatCopy = [format copy];
        format.preferredRange = UIGraphicsImageRendererFormatRangeExtended;
        report("renderer-range-set", number(format.preferredRange));
        report("renderer-copy-keeps-range", number(formatCopy.preferredRange));
        // The deprecated flag and the range are read through each other: the host may link them, so both directions are measured.
        UIGraphicsImageRendererFormat *flagged = [UIGraphicsImageRendererFormat defaultFormat];
        flagged.prefersExtendedRange = YES;
        report("renderer-flag-then-range", number(flagged.preferredRange));
        flagged.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
        report("renderer-range-then-flag", yes_no(flagged.prefersExtendedRange));
        UIGraphicsImageRendererFormat *unflagged = [UIGraphicsImageRendererFormat defaultFormat];
        unflagged.prefersExtendedRange = NO;
        report("renderer-flag-off-range", number(unflagged.preferredRange));
        unflagged.preferredRange = UIGraphicsImageRendererFormatRangeExtended;
        report("renderer-extended-then-flag", yes_no(unflagged.prefersExtendedRange));
        unflagged.preferredRange = UIGraphicsImageRendererFormatRangeAutomatic;
        report("renderer-automatic-then-flag", yes_no(unflagged.prefersExtendedRange));
        unflagged.preferredRange = UIGraphicsImageRendererFormatRangeUnspecified;
        report("renderer-unspecified-kept", number(unflagged.preferredRange));
        report("renderer-unspecified-then-flag", yes_no(unflagged.prefersExtendedRange));
        UIGraphicsImageRendererFormat *cleared = [UIGraphicsImageRendererFormat defaultFormat];
        cleared.preferredRange = UIGraphicsImageRendererFormatRangeExtended;
        cleared.prefersExtendedRange = NO;
        report("renderer-extended-off-range", number(cleared.preferredRange));
        cleared.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
        cleared.prefersExtendedRange = NO;
        report("renderer-standard-off-range", number(cleared.preferredRange));

        // The text properties' expansion text: off by default, kept as set, and a copy keeps it.
        UIListContentTextProperties *text = [UIListContentTextProperties new];
        report("text-expansion-default", yes_no(text.showsExpansionTextWhenTruncated));
        text.showsExpansionTextWhenTruncated = YES;
        report("text-expansion-set", yes_no(text.showsExpansionTextWhenTruncated));
        UIListContentTextProperties *textCopy = [text copy];
        report("text-expansion-copy-keeps", yes_no(textCopy.showsExpansionTextWhenTruncated));

        // The view configuration state: not pinned by default, and kept as set.
        UIViewConfigurationState *state = plain_new([UIViewConfigurationState class]);
        report("state-pinned-default", yes_no(state.pinned));
        state.pinned = YES;
        report("state-pinned-set", yes_no(state.pinned));
    }
    return 0;
}
