#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

static BOOL ours;

static SEL named(NSString *selector)
{
    if (!ours)
        return NSSelectorFromString(selector);
    if ([selector hasPrefix:@"set"])
        return NSSelectorFromString([@"setRevenantHost" stringByAppendingString:[selector substringFromIndex:3]]);
    return NSSelectorFromString([@"revenantHost" stringByAppendingFormat:@"%@%@",
                                 [[selector substringToIndex:1] uppercaseString], [selector substringFromIndex:1]]);
}

static id send(id target, NSString *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(target, named(selector));
}

static void send_object(id target, NSString *selector, id argument)
{
    ((void (*)(id, SEL, id))objc_msgSend)(target, named(selector), argument);
}

@interface Recorder : NSObject <UIInteraction>
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) NSMutableString *seen;
@property (nonatomic, copy) NSString *label;
@end

@implementation Recorder

- (instancetype)initWithLabel:(NSString *)label
{
    if ((self = [super init])) {
        _label = [label copy];
        _seen = [NSMutableString string];
    }
    return self;
}

- (void)willMoveToView:(UIView *)view
{
    [self.seen appendFormat:@"will(%@) ", view ? @"view" : @"nil"];
}

- (void)didMoveToView:(UIView *)view
{
    [self.seen appendFormat:@"did(%@) ", view ? @"view" : @"nil"];
    self.view = view;
}

@end

static NSString *caught(void (^work)(void))
{
    @try {
        work();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing raised";
}

static NSString *names(NSArray *interactions)
{
    NSMutableArray<NSString *> *found = [NSMutableArray array];
    for (Recorder *interaction in interactions)
        [found addObject:interaction.label];
    return found.count ? [found componentsJoinedByString:@","] : @"-";
}

static void record(NSMutableArray *into, const char *step, NSString *value)
{
    [into addObject:@[@(step), value ?: @"nil"]];
}

static NSArray *interactions_of(UIView *view)
{
    return send(view, @"interactions");
}

static void interactions_script(NSMutableArray *into)
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero], *other = [[UIView alloc] initWithFrame:CGRectZero];
    record(into, "a fresh view holds no interactions", [NSString stringWithFormat:@"%@ class=%@",
           names(interactions_of(view)), interactions_of(view) ? @"array" : @"nil"]);

    Recorder *first = [[Recorder alloc] initWithLabel:@"first"], *second = [[Recorder alloc] initWithLabel:@"second"];
    send_object(view, @"addInteraction:", first);
    record(into, "adding one tells it where it went", [first.seen copy]);
    record(into, "and the view lists it", names(interactions_of(view)));
    record(into, "and the interaction knows its view", first.view == view ? @"the view" : @"somewhere else");

    send_object(view, @"addInteraction:", second);
    record(into, "a second one goes after the first", names(interactions_of(view)));

    record(into, "the list handed out is a copy", [interactions_of(view) isEqual:interactions_of(view)]
           && interactions_of(view) != interactions_of(view) ? @"a copy" : @"the same object");

    [first.seen setString:@""];
    send_object(other, @"addInteraction:", first);
    record(into, "adding to another view takes it off the first", [first.seen copy]);
    record(into, "the first view no longer lists it", names(interactions_of(view)));
    record(into, "the other view does", names(interactions_of(other)));

    [second.seen setString:@""];
    send_object(view, @"addInteraction:", second);
    record(into, "adding to the same view again", [second.seen copy]);
    record(into, "and it is listed once", names(interactions_of(view)));

    [second.seen setString:@""];
    send_object(view, @"removeInteraction:", second);
    record(into, "removing tells it that it left", [second.seen copy]);
    record(into, "and the view forgets it", names(interactions_of(view)));
    record(into, "and it has no view", second.view ? @"still a view" : @"none");

    [second.seen setString:@""];
    send_object(view, @"removeInteraction:", second);
    record(into, "removing what is not there says nothing", second.seen.length ? [second.seen copy] : @"silence");

    Recorder *third = [[Recorder alloc] initWithLabel:@"third"];
    send_object(view, @"removeInteraction:", third);
    record(into, "removing a stranger says nothing either", third.seen.length ? [third.seen copy] : @"silence");

    record(into, "adding nil", caught(^{ send_object(view, @"addInteraction:", nil); }));
    record(into, "removing nil", caught(^{ send_object(view, @"removeInteraction:", nil); }));
    record(into, "and the list after both", names(interactions_of(view)));

    Recorder *fourth = [[Recorder alloc] initWithLabel:@"fourth"], *fifth = [[Recorder alloc] initWithLabel:@"fifth"];
    send_object(view, @"setInteractions:", @[fourth, fifth]);
    record(into, "a whole list can be set", names(interactions_of(view)));
    record(into, "and each one was told", [NSString stringWithFormat:@"%@| %@", fourth.seen, fifth.seen]);

    [fourth.seen setString:@""];
    send_object(view, @"setInteractions:", @[fifth]);
    record(into, "setting a shorter list drops the rest", names(interactions_of(view)));
    record(into, "and the dropped one was told it left", [fourth.seen copy]);

    record(into, "setting the list to nil", caught(^{ send_object(view, @"setInteractions:", nil); }));
    record(into, "and the list after that", names(interactions_of(view)));

    send_object(view, @"setInteractions:", @[]);
    record(into, "setting an empty list empties it", names(interactions_of(view)));
}

static void accessibility_script(NSMutableArray *into)
{
    NSAttributedString *(^rich)(NSString *) = ^(NSString *text) {
        return [[NSAttributedString alloc] initWithString:text
                                              attributes:@{UIAccessibilitySpeechAttributeIPANotation: @"prompt"}];
    };

    UIView *fresh = [[UIView alloc] initWithFrame:CGRectZero];
    record(into, "a fresh view has no attributed label", send(fresh, @"accessibilityAttributedLabel") ?: @"nil");

    UIView *attributed = [[UIView alloc] initWithFrame:CGRectZero];
    send_object(attributed, @"setAccessibilityAttributedLabel:", rich(@"Hello"));
    record(into, "the attributed label answers its own text", [send(attributed, @"accessibilityAttributedLabel") string]);
    record(into, "and the plain label follows it", attributed.accessibilityLabel);
    record(into, "and the attribute survives the round trip",
           [[send(attributed, @"accessibilityAttributedLabel") attributesAtIndex:0 effectiveRange:NULL]
            objectForKey:UIAccessibilitySpeechAttributeIPANotation]);

    UIView *plain = [[UIView alloc] initWithFrame:CGRectZero];
    plain.accessibilityLabel = @"Plain";
    record(into, "a plain label comes back attributed", [send(plain, @"accessibilityAttributedLabel") string]);
    record(into, "with nothing in its attributes",
           [NSString stringWithFormat:@"%lu", (unsigned long)[[send(plain, @"accessibilityAttributedLabel")
                                                               attributesAtIndex:0 effectiveRange:NULL] count]]);

    UIView *both = [[UIView alloc] initWithFrame:CGRectZero];
    both.accessibilityLabel = @"First";
    send_object(both, @"setAccessibilityAttributedLabel:", rich(@"Second"));
    record(into, "the attributed one set last wins", [NSString stringWithFormat:@"%@ / %@",
           [send(both, @"accessibilityAttributedLabel") string], both.accessibilityLabel]);
    both.accessibilityLabel = @"Third";
    record(into, "the plain one set last wins too", [NSString stringWithFormat:@"%@ / %@",
           [send(both, @"accessibilityAttributedLabel") string], both.accessibilityLabel]);

    UIView *cleared = [[UIView alloc] initWithFrame:CGRectZero];
    send_object(cleared, @"setAccessibilityAttributedLabel:", rich(@"Gone"));
    send_object(cleared, @"setAccessibilityAttributedLabel:", nil);
    record(into, "setting nil clears both", [NSString stringWithFormat:@"%@ / %@",
           send(cleared, @"accessibilityAttributedLabel") ?: @"nil", cleared.accessibilityLabel ?: @"nil"]);

    UIView *hinted = [[UIView alloc] initWithFrame:CGRectZero];
    send_object(hinted, @"setAccessibilityAttributedHint:", rich(@"A hint"));
    send_object(hinted, @"setAccessibilityAttributedValue:", rich(@"A value"));
    record(into, "the hint and the value work the same way", [NSString stringWithFormat:@"%@ / %@ / %@ / %@",
           [send(hinted, @"accessibilityAttributedHint") string], hinted.accessibilityHint,
           [send(hinted, @"accessibilityAttributedValue") string], hinted.accessibilityValue]);

    UIView *copied = [[UIView alloc] initWithFrame:CGRectZero];
    NSMutableAttributedString *mutable = [[NSMutableAttributedString alloc] initWithString:@"Before"];
    send_object(copied, @"setAccessibilityAttributedLabel:", mutable);
    [mutable replaceCharactersInRange:NSMakeRange(0, mutable.length) withString:@"After"];
    record(into, "the stored string is a copy, not the caller's", [send(copied, @"accessibilityAttributedLabel") string]);

    UILabel *text = [[UILabel alloc] initWithFrame:CGRectZero];
    text.text = @"Written";
    record(into, "a label's own text is not an attributed label", [send(text, @"accessibilityAttributedLabel") string] ?: @"nil");

}

extern NSAttributedStringKey const RevenantHostUIAccessibilitySpeechAttributeQueueAnnouncement;
extern NSAttributedStringKey const RevenantHostUIAccessibilitySpeechAttributeIPANotation;
extern NSAttributedStringKey const RevenantHostUIAccessibilityTextAttributeHeadingLevel;
extern NSAttributedStringKey const RevenantHostUIAccessibilityTextAttributeCustom;
extern UIImagePickerControllerInfoKey const RevenantHostUIImagePickerControllerImageURL;
extern UIActivityType const RevenantHostUIActivityTypeMarkupAsPDF;
extern NSNotificationName const RevenantHostUIAccessibilityVoiceOverStatusDidChangeNotification;

static void keys_of_the_port(void)
{
    CHECK([RevenantHostUIAccessibilitySpeechAttributeQueueAnnouncement isEqual:UIAccessibilitySpeechAttributeQueueAnnouncement],
          "the queue announcement key is the string UIKit has");
    CHECK([RevenantHostUIAccessibilitySpeechAttributeIPANotation isEqual:UIAccessibilitySpeechAttributeIPANotation],
          "the IPA notation key is the string UIKit has");
    CHECK([RevenantHostUIAccessibilityTextAttributeHeadingLevel isEqual:UIAccessibilityTextAttributeHeadingLevel],
          "the heading level key is the string UIKit has");
    CHECK([RevenantHostUIAccessibilityTextAttributeCustom isEqual:UIAccessibilityTextAttributeCustom],
          "the custom text key is the string UIKit has");
    CHECK([RevenantHostUIImagePickerControllerImageURL isEqual:UIImagePickerControllerImageURL],
          "the image picker's URL key is the string UIKit has");
    CHECK([RevenantHostUIActivityTypeMarkupAsPDF isEqual:UIActivityTypeMarkupAsPDF],
          "the markup as PDF activity is the identifier UIKit has");
    CHECK([RevenantHostUIAccessibilityVoiceOverStatusDidChangeNotification isEqual:UIAccessibilityVoiceOverStatusDidChangeNotification],
          "the VoiceOver notification is the name UIKit has");
    CHECK([RevenantHostUIAccessibilityVoiceOverStatusDidChangeNotification isEqual:UIAccessibilityVoiceOverStatusChanged],
          "and it is the same name as the one it replaced, which is why it works on a release that only has the old one");
}

int main(void)
{
    @autoreleasepool {
        NSMutableArray *system = [NSMutableArray array], *port = [NSMutableArray array];
        ours = NO;
        interactions_script(system);
        accessibility_script(system);
        ours = YES;
        BOOL carried = [UIView instancesRespondToSelector:named(@"addInteraction:")]
            && [NSObject instancesRespondToSelector:named(@"accessibilityAttributedLabel")];
        CHECK(carried, "the port carries the interactions and the attributed strings");
        if (carried) {
            interactions_script(port);
            accessibility_script(port);
            keys_of_the_port();
        }
        for (NSUInteger index = 0; index < system.count; index++) {
            NSArray *mine = index < port.count ? port[index] : nil;
            NSString *expected = system[index][1], *actual = mine ? mine[1] : @"nothing";
            printf("  %s: %s\n", [system[index][0] UTF8String], expected.UTF8String);
            revenant_check([expected isEqual:actual], [system[index][0] UTF8String],
                         [NSString stringWithFormat:@"%@ != %@", actual, expected]);
        }
    }
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures;
}
