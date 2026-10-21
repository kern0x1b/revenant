#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <dlfcn.h>

#pragma clang diagnostic ignored "-Wundeclared-selector"

enum {
    RevenantShift = 1 << 17,
    RevenantControl = 1 << 18,
    RevenantAlternate = 1 << 19,
    RevenantCommand = 1 << 20,
    RevenantModifiers = RevenantShift | RevenantControl | RevenantAlternate | RevenantCommand,
    RevenantKeyDown = 10
};

@interface UIViewController (RevenantAddedKeyCommands)
- (NSArray<UIKeyCommand *> *)revenant_addedKeyCommands;
@end

static long (*gs_type)(void *);
static long (*gs_key_code)(void *);
static long (*gs_flags)(void *);
static CFStringRef (*gs_plain)(void *);

static NSString *revenant_input_for_event(void *event)
{
    long code = gs_key_code ? gs_key_code(event) : 0;
    switch (code) {
        case 0x52: return @"UIKeyInputUpArrow";
        case 0x51: return @"UIKeyInputDownArrow";
        case 0x50: return @"UIKeyInputLeftArrow";
        case 0x4F: return @"UIKeyInputRightArrow";
        case 0x29: return @"UIKeyInputEscape";
        default: break;
    }
    NSString *plain = gs_plain ? CFBridgingRelease(gs_plain(event)) : nil;
    if (!plain.length)
        return nil;
    switch ([plain characterAtIndex:0]) {
        case 0xF700: return @"UIKeyInputUpArrow";
        case 0xF701: return @"UIKeyInputDownArrow";
        case 0xF702: return @"UIKeyInputLeftArrow";
        case 0xF703: return @"UIKeyInputRightArrow";
        case 0x1B: return @"UIKeyInputEscape";
        default: break;
    }
    return plain;
}

static BOOL revenant_command_matches(UIKeyCommand *command, NSString *input, NSInteger flags)
{
    if (![command isKindOfClass:[UIKeyCommand class]] || !command.action || !command.input)
        return NO;
    if ((command.modifierFlags & RevenantModifiers) != (flags & RevenantModifiers))
        return NO;
    return [command.input caseInsensitiveCompare:input] == NSOrderedSame;
}

static UIResponder *revenant_first_responder(UIView *view)
{
    if (view.isFirstResponder)
        return view;
    for (UIView *subview in view.subviews) {
        UIResponder *found = revenant_first_responder(subview);
        if (found)
            return found;
    }
    return nil;
}

static BOOL revenant_fire_key_command(NSString *input, NSInteger flags)
{
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *window = application.keyWindow;
    NSMutableArray *chain = [NSMutableArray array];
    for (UIResponder *responder = revenant_first_responder(window) ?: window; responder; responder = responder.nextResponder)
        [chain addObject:responder];
    if (application.delegate && ![chain containsObject:application.delegate])
        [chain addObject:application.delegate];
    for (id responder in chain) {
        if (![responder respondsToSelector:@selector(keyCommands)])
            continue;
        NSArray *commands = [responder keyCommands] ?: @[];
        if ([responder respondsToSelector:@selector(revenant_addedKeyCommands)])
            commands = [commands arrayByAddingObjectsFromArray:[responder revenant_addedKeyCommands]];
        for (UIKeyCommand *command in commands) {
            if (revenant_command_matches(command, input, flags) && [responder canPerformAction:command.action withSender:command] && [application sendAction:command.action to:responder from:command forEvent:nil])
                return YES;
        }
    }
    return NO;
}

@interface RevenantKeyCommandInstaller : NSObject
@end

@implementation RevenantKeyCommandInstaller

+ (void)load
{
    void *graphics = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY);
    gs_type = graphics ? dlsym(graphics, "GSEventGetType") : NULL;
    gs_key_code = graphics ? dlsym(graphics, "GSEventGetKeyCode") : NULL;
    gs_flags = graphics ? dlsym(graphics, "GSEventGetModifierFlags") : NULL;
    gs_plain = graphics ? dlsym(graphics, "GSEventCopyCharactersIgnoringModifiers") : NULL;
    SEL selector = NSSelectorFromString(@"handleKeyEvent:");
    Method method = class_getInstanceMethod([UIApplication class], selector);
    if (!gs_type || !gs_flags || !gs_plain || !method)
        return;
    void (*original)(id, SEL, void *) = (void (*)(id, SEL, void *))method_getImplementation(method);
    class_replaceMethod([UIApplication class], selector, imp_implementationWithBlock(^(UIApplication *application, void *event) {
        if (event && gs_type(event) == RevenantKeyDown) {
            NSString *input = revenant_input_for_event(event);
            if (input && revenant_fire_key_command(input, (NSInteger)gs_flags(event)))
                return;
        }
        original(application, selector, event);
    }), method_getTypeEncoding(method));
}

@end
