#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

static NSString *color(UIColor *c)
{
    CGFloat r, g, b, a;
    if (!c)
        return @"nil";
    return [c getRed:&r green:&g blue:&b alpha:&a] ? [NSString stringWithFormat:@"%.3f %.3f %.3f %.3f", r, g, b, a] : @"?";
}

static UIContextualAction *make(BOOL ours, NSInteger style, NSString *title, UIContextualActionHandler handler)
{
    Class class = ours ? NSClassFromString(@"CharonHostUIContextualAction") : [UIContextualAction class];
    return ((UIContextualAction * (*)(id, SEL, NSInteger, NSString *, UIContextualActionHandler))objc_msgSend)(class, @selector(contextualActionWithStyle:title:handler:), style, title, handler);
}

static UISwipeActionsConfiguration *configure(BOOL ours, NSArray *actions)
{
    Class class = ours ? NSClassFromString(@"CharonHostUISwipeActionsConfiguration") : [UISwipeActionsConfiguration class];
    return (UISwipeActionsConfiguration *)[class configurationWithActions:actions];
}

static UIContextualAction *fresh_action(BOOL ours)
{
    return [[NSClassFromString(ours ? @"CharonHostUIContextualAction" : @"UIContextualAction") alloc] init];
}

static UISwipeActionsConfiguration *fresh_configuration(BOOL ours)
{
    return [[NSClassFromString(ours ? @"CharonHostUISwipeActionsConfiguration" : @"UISwipeActionsConfiguration") alloc] init];
}

static void same(NSString *what, NSString *(^measure)(BOOL ours))
{
    NSString *ours = measure(YES), *theirs = measure(NO);
    charon_check([ours isEqualToString:theirs], what.UTF8String, [NSString stringWithFormat:@"ours %@, UIKit %@", ours, theirs]);
}

int main(void)
{
    @autoreleasepool {
        UIContextualActionHandler handler = ^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) { completion(YES); };
        for (NSNumber *style in @[@0, @1, @7]) {
            NSString *tag = [NSString stringWithFormat:@"style %@", style];
            same([tag stringByAppendingString:@": what a fresh action holds"], ^NSString *(BOOL ours) {
                UIContextualAction *action = make(ours, style.integerValue, @"Title", handler);
                return [NSString stringWithFormat:@"%ld|%@|%@|%d|%d", (long)[action style], [action title], color([action backgroundColor]), [action image] != nil, [action handler] != nil];
            });
            same([tag stringByAppendingString:@": nil title and nil handler"], ^NSString *(BOOL ours) {
                UIContextualAction *action = make(ours, style.integerValue, nil, nil);
                return [NSString stringWithFormat:@"%@|%d", [action title] ?: @"nil", [action handler] != nil];
            });
            same([tag stringByAppendingString:@": the background put back by nil"], ^NSString *(BOOL ours) {
                UIContextualAction *action = make(ours, style.integerValue, @"a", handler);
                [action setBackgroundColor:UIColor.blueColor];
                NSString *set = color([action backgroundColor]);
                [action setBackgroundColor:nil];
                return [set stringByAppendingFormat:@"|%@", color([action backgroundColor])];
            });
        }
        same(@"the handler is the block it was made with", ^NSString *(BOOL ours) { return [make(ours, 0, @"a", handler) handler] == handler ? @"same" : @"other"; });
        same(@"the handler runs and completes", ^NSString *(BOOL ours) {
            __block BOOL done = NO;
            [make(ours, 0, @"a", handler) handler](nil, nil, ^(BOOL performed) { done = performed; });
            return done ? @"completed" : @"not";
        });
        same(@"the title is copied", ^NSString *(BOOL ours) {
            NSMutableString *title = [NSMutableString stringWithString:@"x"];
            UIContextualAction *action = make(ours, 0, title, handler);
            [title appendString:@"y"];
            NSString *made = [action title];
            [action setTitle:title];
            [title appendString:@"z"];
            return [made stringByAppendingFormat:@"|%@", [action title]];
        });
        same(@"the image is kept as it is", ^NSString *(BOOL ours) {
            UIImage *image = [UIImage new];
            UIContextualAction *action = make(ours, 0, @"a", handler);
            [action setImage:image];
            return [action image] == image ? @"same" : @"other";
        });
        same(@"an action made by init", ^NSString *(BOOL ours) {
            UIContextualAction *action = fresh_action(ours);
            return [NSString stringWithFormat:@"%ld|%@|%@|%d", (long)[action style], [action title] ?: @"nil", color([action backgroundColor]), [action handler] != nil];
        });
        same(@"an action made by init and given no background", ^NSString *(BOOL ours) {
            UIContextualAction *action = fresh_action(ours);
            [action setBackgroundColor:nil];
            return color([action backgroundColor]);
        });
        same(@"an action does not answer to copy", ^NSString *(BOOL ours) {
            UIContextualAction *action = make(ours, 0, @"a", handler);
            return [NSString stringWithFormat:@"%d|%d", [action respondsToSelector:@selector(copyWithZone:)], [action conformsToProtocol:@protocol(NSSecureCoding)]];
        });
        same(@"the settings an action has no setter for", ^NSString *(BOOL ours) {
            UIContextualAction *action = make(ours, 0, @"a", handler);
            return [NSString stringWithFormat:@"%d", [action respondsToSelector:NSSelectorFromString(@"setStyle:")]];
        });
        same(@"the superclass of an action", ^NSString *(BOOL ours) { return NSStringFromClass([fresh_action(ours) superclass]); });

        UIContextualAction *first = make(NO, 0, @"a", handler), *second = make(NO, 1, @"b", handler);
        same(@"a configuration holds its actions", ^NSString *(BOOL ours) {
            UISwipeActionsConfiguration *configuration = configure(ours, @[first, second]);
            NSArray *actions = [configuration actions];
            return [NSString stringWithFormat:@"%lu|%d|%d|%d", (unsigned long)actions.count, actions[0] == first, actions[1] == second, [configuration performsFirstActionWithFullSwipe]];
        });
        same(@"a configuration keeps the array it was given", ^NSString *(BOOL ours) {
            NSMutableArray *held = [NSMutableArray arrayWithObject:first];
            UISwipeActionsConfiguration *configuration = configure(ours, held);
            [held addObject:second];
            NSArray *actions = [configuration actions];
            return [NSString stringWithFormat:@"%lu|%d|%d", (unsigned long)actions.count, [actions isKindOfClass:[NSMutableArray class]], actions == held];
        });
        same(@"a configuration given no actions", ^NSString *(BOOL ours) {
            UISwipeActionsConfiguration *configuration = configure(ours, nil);
            return [NSString stringWithFormat:@"%d|%d", [configuration actions] == nil, [configuration performsFirstActionWithFullSwipe]];
        });
        same(@"a configuration given something that is no action", ^NSString *(BOOL ours) {
            UISwipeActionsConfiguration *configuration = configure(ours, @[@"a"]);
            return [NSString stringWithFormat:@"%lu", (unsigned long)[[configuration actions] count]];
        });
        same(@"a configuration made by init", ^NSString *(BOOL ours) {
            UISwipeActionsConfiguration *configuration = fresh_configuration(ours);
            return [NSString stringWithFormat:@"%d|%d", [configuration actions] == nil, [configuration performsFirstActionWithFullSwipe]];
        });
        same(@"the full swipe can be turned off and on", ^NSString *(BOOL ours) {
            UISwipeActionsConfiguration *configuration = configure(ours, @[first]);
            [configuration setPerformsFirstActionWithFullSwipe:NO];
            NSString *off = [NSString stringWithFormat:@"%d", [configuration performsFirstActionWithFullSwipe]];
            [configuration setPerformsFirstActionWithFullSwipe:YES];
            return [off stringByAppendingFormat:@"|%d", [configuration performsFirstActionWithFullSwipe]];
        });
        same(@"what a configuration does not answer to", ^NSString *(BOOL ours) {
            UISwipeActionsConfiguration *configuration = configure(ours, @[first]);
            return [NSString stringWithFormat:@"%d|%d|%d", [configuration respondsToSelector:@selector(copyWithZone:)], [configuration conformsToProtocol:@protocol(NSSecureCoding)],
                    [configuration respondsToSelector:NSSelectorFromString(@"setActions:")]];
        });
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
