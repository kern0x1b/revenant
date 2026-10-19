#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <string.h>

/* What an NSUndoManager's own action state reads, the same five the port adds, driven through one
   sequence on both sides. Every value is printed flat, so run.sh can compare them without knowing
   what any of them means. */

static id send_id(id target, SEL selector, id arg)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(target, selector, arg);
}

static void send_set(id target, SEL selector, id value, id arg)
{
    ((void (*)(id, SEL, id, id))objc_msgSend)(target, selector, value, arg);
}

static void send_void(id target, SEL selector)
{
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

static unsigned long long send_count(id target, SEL selector)
{
    return ((unsigned long long (*)(id, SEL))objc_msgSend)(target, selector);
}

static const char *image_of(id cls, SEL selector, BOOL is_class)
{
    Method m = is_class ? class_getClassMethod(cls, selector) : class_getInstanceMethod(cls, selector);
    if (!m)
        return "NO SUCH METHOD";
    Dl_info info;
    if (dladdr(method_getImplementation(m), &info) && info.dli_fname)
        return info.dli_fname;
    return "?";
}

static NSString *describe_id(id value)
{
    if (!value)
        return @"(nil)";
    if ([value isKindOfClass:[NSString class]])
        return [NSString stringWithFormat:@"\"%@\"", value];
    return [value description];
}

/* The undo actions have to land on something, or the manager has nothing to send them to. The
   manager is given back, because the usual way an undo action becomes redoable is for the action to
   register its inverse while it runs - the release does not build a redo stack by remembering what
   it undid. */
@interface CharonUndoTarget : NSObject
@property (nonatomic, assign) NSUInteger fired;
@property (nonatomic, weak) NSUndoManager *manager;
@property (nonatomic, copy) NSString *inverseName;
@end

@implementation CharonUndoTarget
@synthesize fired = _fired;
@synthesize manager = _manager;
@synthesize inverseName = _inverseName;

- (void)note:(id)sender
{
    (void)sender;
    _fired++;
    NSUndoManager *manager = _manager;
    if (!manager)
        return;
    /* Registering while undoing is what fills the redo stack; while redoing it fills the undo stack
       again. The name is spelled the way this release spells it, picked once here. */
    BOOL whileUndoing = manager.isUndoing;
    BOOL whileRedoing = manager.isRedoing;
    if (!whileUndoing && !whileRedoing)
        return;
    [manager registerUndoWithTarget:self selector:@selector(note:) object:self];
    SEL nameAction = [manager respondsToSelector:NSSelectorFromString(@"setUndoActionName:")]
                   ? NSSelectorFromString(@"setUndoActionName:") : NSSelectorFromString(@"setActionName:");
    send_id(manager, nameAction, _inverseName ?: @"inverse");
}

@end

int main(void)
{
#ifdef PORT_SIDE
    printf("side\tport\n");
#else
    printf("side\tsystem\n");
#endif

    Class manager = [NSUndoManager class];
    SEL undoCount = NSSelectorFromString(@"undoCount");
    SEL redoCount = NSSelectorFromString(@"redoCount");
    SEL setUserInfo = NSSelectorFromString(@"setActionUserInfoValue:forKey:");
    SEL undoUserInfo = NSSelectorFromString(@"undoActionUserInfoValueForKey:");
    SEL redoUserInfo = NSSelectorFromString(@"redoActionUserInfoValueForKey:");

    const char *names[] = {"undoCount", "redoCount", "setActionUserInfoValue:forKey:",
                           "undoActionUserInfoValueForKey:", "redoActionUserInfoValueForKey:"};
    for (int i = 0; i < 5; i++) {
        SEL s = NSSelectorFromString([NSString stringWithUTF8String:names[i]]);
        printf("image.%s\t%s\n", names[i], image_of(manager, s, NO));
    }

    NSUndoManager *undo = [NSUndoManager new];
    /* The release groups by event by default, so two registrations in one turn of the run loop are
       one group and a count would be counting run loops. Turned off so each registration is a group
       on both sides, which is the case the port's shadow models. */
    [undo setGroupsByEvent:NO];

    printf("fresh.undoCount\t%llu\n", send_count(undo, undoCount));
    printf("fresh.redoCount\t%llu\n", send_count(undo, redoCount));
    printf("fresh.canUndo\t%s\n", [undo canUndo] ? "YES" : "NO");
    printf("fresh.undoUserInfo(k)\t%s\n", describe_id(send_id(undo, undoUserInfo, @"k")).UTF8String);

    NSUndoManager *cleared = [NSUndoManager new];
    send_void(cleared, NSSelectorFromString(@"removeAllActions"));
    printf("cleared.undoCount\t%llu\n", send_count(cleared, undoCount));
    printf("cleared.redoCount\t%llu\n", send_count(cleared, redoCount));

    /* With nothing registered there is no action group, and what the release does about that is a
       measurement, not an assumption - so it is caught and named rather than let it end the run. */
    @try {
        send_set(undo, setUserInfo, @"x", @"k");
        printf("empty.setUserInfo\tno exception\n");
    }
    @catch (NSException *e) {
        printf("empty.setUserInfo\traised %s\n", e.name.UTF8String);
    }


    /* iOS names a group with setUndoActionName:, the host with setActionName:, and the compiler
       checks a direct send against the header it has - so the name is picked once, by selector. */
    SEL nameAction = [undo respondsToSelector:NSSelectorFromString(@"setUndoActionName:")]
                   ? NSSelectorFromString(@"setUndoActionName:") : NSSelectorFromString(@"setActionName:");

    CharonUndoTarget *target = [CharonUndoTarget new];
    target.manager = undo;
    target.inverseName = @"inverse-of-second";
    [undo beginUndoGrouping];
    [undo registerUndoWithTarget:target selector:@selector(note:) object:target];
    send_id(undo, nameAction, @"first");
    /* Set on a mutable string and changed afterwards: the release holds user info by value, so the
       action must still read what was set and not what the string became. */
    NSMutableString *value = [NSMutableString stringWithString:@"one"];
    send_set(undo, setUserInfo, value, @"tag");
    [value appendString:@"-changed"];
    printf("userinfo.copyHeld\t%s\n",
           [send_id(undo, undoUserInfo, @"tag") isEqualToString:@"one"] ? "YES" : "NO");
    printf("userinfo.mutableAfterSet\t%s\n", value.UTF8String);
    send_set(undo, setUserInfo, @"one", @"tag");
    [undo endUndoGrouping];

    [undo beginUndoGrouping];
    [undo registerUndoWithTarget:target selector:@selector(note:) object:target];
    send_id(undo, nameAction, @"second");
    send_set(undo, setUserInfo, @"two", @"tag");
    [undo endUndoGrouping];

    printf("two-groups.undoCount\t%llu\n", send_count(undo, undoCount));
    printf("two-groups.redoCount\t%llu\n", send_count(undo, redoCount));
    printf("two-groups.undoActionName\t%s\n", undo.undoActionName.UTF8String);
    printf("two-groups.undoUserInfo(tag)\t%s\n", describe_id(send_id(undo, undoUserInfo, @"tag")).UTF8String);

    send_void(undo, NSSelectorFromString(@"undo"));
    printf("after-undo.undoCount\t%llu\n", send_count(undo, undoCount));
    printf("after-undo.redoCount\t%llu\n", send_count(undo, redoCount));
    printf("after-undo.redoActionName\t%s\n", undo.redoActionName.UTF8String);
    printf("after-undo.redoUserInfo(tag)\t%s\n", describe_id(send_id(undo, redoUserInfo, @"tag")).UTF8String);
    printf("after-undo.fired\t%lu\n", (unsigned long)target.fired);

    send_void(undo, NSSelectorFromString(@"undo"));
    printf("after-undo2.undoCount\t%llu\n", send_count(undo, undoCount));
    printf("after-undo2.redoCount\t%llu\n", send_count(undo, redoCount));
    printf("after-undo2.fired\t%lu\n", (unsigned long)target.fired);

    send_void(undo, NSSelectorFromString(@"redo"));
    printf("after-redo.undoCount\t%llu\n", send_count(undo, undoCount));
    printf("after-redo.redoCount\t%llu\n", send_count(undo, redoCount));
    printf("after-redo.redoActionName\t%s\n", undo.redoActionName.UTF8String);
    printf("after-redo.fired\t%lu\n", (unsigned long)target.fired);

    /* Rule three needs a case of its own: a registration arriving when nothing is undoing or
       redoing, with something still redoable behind it. That is the only way to see whether a fresh
       action empties the redo stack. */
    printf("before-new-registration.redoCount\t%llu\n", send_count(undo, redoCount));
    CharonUndoTarget *later = [CharonUndoTarget new];
    later.manager = nil;
    [undo beginUndoGrouping];
    [undo registerUndoWithTarget:later selector:@selector(note:) object:later];
    [undo endUndoGrouping];
    printf("after-new-registration.undoCount\t%llu\n", send_count(undo, undoCount));
    printf("after-new-registration.redoCount\t%llu\n", send_count(undo, redoCount));

    /* The other case: an action that registers nothing while it runs, which is what the first
       sequence measured - the redo stack stays empty and redo has nothing to do. */
    NSUndoManager *plain = [NSUndoManager new];
    [plain setGroupsByEvent:NO];
    CharonUndoTarget *plainTarget = [CharonUndoTarget new];
    plainTarget.manager = nil;   /* registers nothing while undoing: the second case */
    [plain beginUndoGrouping];
    [plain registerUndoWithTarget:plainTarget selector:@selector(note:) object:plainTarget];
    send_id(plain, nameAction, @"plain");
    [plain endUndoGrouping];
    printf("plain.undoCount\t%llu\n", send_count(plain, undoCount));
    send_void(plain, NSSelectorFromString(@"undo"));
    printf("plain.afterUndo.undoCount\t%llu\n", send_count(plain, undoCount));
    printf("plain.afterUndo.redoCount\t%llu\n", send_count(plain, redoCount));
    printf("plain.afterUndo.canRedo\t%s\n", [plain canRedo] ? "YES" : "NO");

    return 0;
}
