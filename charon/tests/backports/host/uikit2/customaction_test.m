#import "uirest.h"

// The accessibility custom action's constructors and properties that the port carries beyond the name and target: the
// handler, the image and the attributed name. The same calls with the same arguments on the port's class and on the
// system's, in one process; the answers are the names, the identities of the image and target, the handler's result
// and how often it ran, and the selector.

// The port's perform, declared here for the sends below: the class is the port's own and the system has no such method.
@protocol charonPerformable
- (BOOL)charonPerform;
@end

@interface charonCustomActionTarget : NSObject
@property (nonatomic) NSInteger performed;
- (void)charonAction;
- (void)charonRecord:(id)action;
@end

@implementation charonCustomActionTarget
- (void)charonAction
{
}
- (void)charonRecord:(id)action
{
    self.performed++;
}
@end

static NSArray *action_lines(Class cls, charonCustomActionTarget *target, UIImage *image)
{
    NSMutableArray *lines = [NSMutableArray array];
    __block NSInteger ran = 0;
    BOOL (^handler)(id) = ^BOOL(id action) {
        ran++;
        return YES;
    };

    id byHandler = [[cls alloc] initWithName:@"open" actionHandler:handler];
    [lines addObject:ur_line(@"handler name", [byHandler name])];
    [lines addObject:ur_line(@"handler kept", ur_yes([byHandler actionHandler] != nil))];
    BOOL (^kept)(id) = (BOOL (^)(id))[byHandler actionHandler];
    BOOL result = kept ? kept(byHandler) : NO;
    [lines addObject:ur_line(@"handler result", ur_yes(result))];
    [lines addObject:ur_line(@"handler ran", @(ran))];
    [lines addObject:ur_line(@"handler has no image", ur_yes([byHandler image] == nil))];

    id withImage = [[cls alloc] initWithName:@"share" image:image actionHandler:handler];
    [lines addObject:ur_line(@"image handler name", [withImage name])];
    [lines addObject:ur_line(@"image kept", ur_yes([withImage image] == image))];
    [lines addObject:ur_line(@"image handler kept", ur_yes([withImage actionHandler] != nil))];

    id withTarget = [[cls alloc] initWithName:@"print" image:image target:target selector:@selector(charonAction)];
    [lines addObject:ur_line(@"target name", [withTarget name])];
    [lines addObject:ur_line(@"target image", ur_yes([withTarget image] == image))];
    [lines addObject:ur_line(@"target kept", ur_yes([withTarget target] == target))];
    [lines addObject:ur_line(@"target selector", NSStringFromSelector([withTarget selector]))];
    [lines addObject:ur_line(@"target has no handler", ur_yes([withTarget actionHandler] == nil))];

    NSAttributedString *named = [[NSAttributedString alloc] initWithString:@"attributed"];
    id byAttributed = [[cls alloc] initWithAttributedName:named actionHandler:handler];
    [lines addObject:ur_line(@"attributed name", [byAttributed name])];
    [lines addObject:ur_line(@"attributed name kept", [[byAttributed attributedName] string])];
    [lines addObject:ur_line(@"attributed handler kept", ur_yes([byAttributed actionHandler] != nil))];

    // The setters: the handler and the image are read back as they were set.
    id plain = [[cls alloc] initWithName:@"plain" target:nil selector:NULL];
    [plain setActionHandler:handler];
    [plain setImage:image];
    [lines addObject:ur_line(@"set handler kept", ur_yes([plain actionHandler] != nil))];
    [lines addObject:ur_line(@"set image kept", ur_yes([plain image] == image))];
    [plain setImage:nil];
    [lines addObject:ur_line(@"cleared image", ur_yes([plain image] == nil))];
    return lines;
}

int main(void)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostUIAccessibilityCustomAction");
        charon_check(ours != Nil, "the port's custom action is linked under its host name", @"missing");
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(2, 2), NO, 1);
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        charonCustomActionTarget *target = [[charonCustomActionTarget alloc] init];
        ur_agree(@"custom action", action_lines(ours, target, image), action_lines([UIAccessibilityCustomAction class], target, image));

        // The invocation: performing an action calls its handler once, with the action, and returns the handler's answer;
        // performing a target action sends its selector once to the target, with the action; an action with neither
        // performs nothing. The system has no such call - the accessibility system makes it - so these are the port's own.
        __block NSInteger handled = 0;
        __block id handledWith = nil;
        id byHandler = [[ours alloc] initWithName:@"open" actionHandler:^BOOL(id action) {
            handled++;
            handledWith = action;
            return YES;
        }];
        BOOL answered = [(id<charonPerformable>)byHandler charonPerform];
        charon_check(answered && handled == 1 && handledWith == byHandler, "performing a handler action calls its handler once, with the action",
                     [NSString stringWithFormat:@"answer %d handled %ld", answered, (long)handled]);

        charonCustomActionTarget *recorder = [[charonCustomActionTarget alloc] init];
        id byTarget = [[ours alloc] initWithName:@"record" target:recorder selector:@selector(charonRecord:)];
        BOOL sent = [(id<charonPerformable>)byTarget charonPerform];
        charon_check(sent && recorder.performed == 1, "performing a target action sends its selector once to the target",
                     [NSString stringWithFormat:@"sent %d performed %ld", sent, (long)recorder.performed]);

        id nothing = [[ours alloc] initWithName:@"nothing" target:nil selector:NULL];
        charon_check(![(id<charonPerformable>)nothing charonPerform],"an action with neither a handler nor a target performs nothing", @"performed");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures ? 1 : 0;
    }
}
