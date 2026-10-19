#import <UIKit/UIKit.h>

// The two iOS 14 initialisers of a custom action that take an ATTRIBUTED name AND an image. The
// header of SDK 16.4 declares exactly these two at ios(14.0), beside the 11.0 attributed form and
// the 14.0 plain forms, and the port carries each of those in a file of its own release. Its own
// file for the same reason those have theirs: one object, one release, which is what
// tools/release-split.lua reads. It may call the 11.0 and the 14.0 objects above and not the class's
// own 7.0 initialiser -- this object is placed in the bands of 14.0 and later, where both are in
// the same band, while a call down into UIAccessibilityCustomAction.m would be an undefined symbol
// on every band where that file is left out.

// Both are one composition each, not a second source of truth: the name and the target or the
// handler come from -initWithAttributedName:target:selector:, and the image from the port's own
// `image` property, which is what the 14.0 plain forms above do.
//
// What the host's own UIKit answers under Mac Catalyst (macOS 27.0), recorded by the recorder in
// tests/backports/host/uikitconst over the cases in .agent-work/runs/host14/slice14-cases.m, which
// include that repository's own cases so the run certifies the same reader (104 records in one
// run, 83 of them the repository's):
//   initWithAttributedName:image:target:selector:
//     name "Links", attributedName's string "Links", the attributes kept whole, image the one
//     passed (the same object), target the one passed, selector "description", actionHandler nil;
//     setting name afterwards moves the string across and the attributes go with it ("drops");
//   initWithAttributedName:image:actionHandler:
//     name "Links", attributedName's string "Links", the attributes kept whole, image the one
//     passed, actionHandler set, and target nil and selector NULL -- the same shape the host
//     answers for -initWithName:image:actionHandler:, so the handler form carries no target;
//   and for reading them against, the 11.0 form answers image nil and actionHandler nil, so an
//     image is what these two add and nothing else.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
// the selector is not nullable in the header, and a handler form carries no selector: the same
// silence UIAccessibilityCustomAction+Handler13.m takes for the same NULL
#pragma clang diagnostic ignored "-Wnonnull"

@implementation UIAccessibilityCustomAction (CharonAttributedNameImage14)

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName image:(UIImage *)image target:(id)target selector:(SEL)selector
{
    if ((self = [self initWithAttributedName:attributedName target:target selector:selector]))
        [self setImage:image];  // a send, not a dot-syntax write: see UIAccessibilityCustomAction+Image14.m
    return self;
}

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName image:(UIImage *)image actionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    // nil and NULL, because the host answers no target and no selector for the handler form: the
    // handler is the action's own, and UIAccessibilityCustomAction+Handler13.m makes the plain
    // handler form that way too, so the two do not disagree about what a handler carries.
    if ((self = [self initWithAttributedName:attributedName target:nil selector:NULL])) {
        [self setActionHandler:actionHandler];  // a send, not a dot-syntax write: see UIAccessibilityCustomAction+Handler13.m
        [self setImage:image];
    }
    return self;
}

@end