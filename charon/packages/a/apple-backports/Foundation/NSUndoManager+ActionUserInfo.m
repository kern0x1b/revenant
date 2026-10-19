#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

/* The five things about an action's own state that arrived in iOS 18: undoCount, redoCount,
   setActionUserInfoValue:forKey:, undoActionUserInfoValueForKey: and redoActionUserInfoValueForKey:.
   On 6.1.3 the manager reports neither how deep its stacks are nor anything about an action's user
   info, and a count is not something that can be derived: the release keeps its stacks privately and
   exposes canUndo, isUndoing, isRedoing, groupsByEvent, levelsOfUndo and undoActionName, none of
   which says how many groups there are. So the two stacks are shadowed.

   The manager still does all of the work. Every method below is wrapped with its original captured
   first, so each registration, grouping, undo, redo and removal reaches the release's own code and
   only the shadow is added to; the added five are plain additions, because nothing on 6.1.3 has to be
   called through. The wrapping is the tree's own shape, as NSLayoutManager+Text7.m does it for
   usedRectForTextContainer: - a typed original, a C function of the same signature that observes and
   then forwards, installed from +load and guarded so it happens once. */

/* One array per stack, per manager, hung off the manager the way the rest of the port hangs its
   own: an address of its own as the key, so two managers never share one. */
static const void *UndoShadowStackKey = &UndoShadowStackKey;   /* NSMutableArray of CharonUndoRecord */
static const void *UndoShadowRedoKey = &UndoShadowRedoKey;     /* the same, the redo stack */
static const void *UndoShadowOpenKey = &UndoShadowOpenKey;     /* the group being built, if one is */
static const void *UndoShadowInheritedKey = &UndoShadowInheritedKey;  /* NSMutableDictionary */

typedef void (*RegisterUndoIMP)(id, SEL, id, SEL, id);
typedef void (*UndoActionNameIMP)(id, SEL, NSString *);
typedef void (*VoidIMP)(id, SEL);
typedef void (*RemoveWithTargetIMP)(id, SEL, id);

static RegisterUndoIMP nativeRegisterUndo;
static UndoActionNameIMP nativeSetUndoActionName;
static UndoActionNameIMP nativeSetActionName;
static VoidIMP nativeCloseUndoGroup;
static VoidIMP nativeEndUndoGrouping;
static VoidIMP nativeUndo;
static VoidIMP nativeRedo;
static VoidIMP nativeRemoveAllActions;
static RemoveWithTargetIMP nativeRemoveAllActionsWithTarget;

/* One record per group on a stack: the name the group answers to and the user info hung on it. */
@interface CharonUndoRecord : NSObject
@property (nonatomic, copy) NSString *actionName;
@property (nonatomic, strong) NSMutableDictionary *userInfo;
@property (nonatomic, weak) id target;
@end

@implementation CharonUndoRecord
@synthesize actionName = _actionName;
@synthesize userInfo = _userInfo;
@synthesize target = _target;
- (instancetype)init
{
    if ((self = [super init]))
        _userInfo = [NSMutableDictionary dictionary];
    return self;
}
@end

static NSMutableArray *UndoShadowStack(NSUndoManager *manager, const void *key)
{
    NSMutableArray *stack = objc_getAssociatedObject(manager, key);
    if (!stack) {
        stack = [NSMutableArray array];
        objc_setAssociatedObject(manager, key, stack, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return stack;
}

/* Where a registration lands, measured rather than remembered, from a manager that undoes an action
   which registers its inverse:
     * while undoing  -> the redo stack. undoCount 2 -> undo -> redoCount 1, and the record the action
       registered carries the user info over with it, so redo reads "two" for the tag.
     * while redoing  -> the undo stack again, measured: after one redo undoCount is back to 1.
     * at any other time -> the undo stack, and the redo stack is emptied, measured: registering fresh
       actions after an undo leaves redoCount 0. */
static BOOL UndoShadowRegistrationGoesToRedo(NSUndoManager *manager)
{
    return [manager isUndoing] && ![manager isRedoing];
}

/* The group the release is adding to: the open one if a group is open, else a new record on whichever
   stack this registration belongs to. */
static CharonUndoRecord *UndoShadowCurrent(NSUndoManager *manager, BOOL creating)
{
    BOOL toRedo = UndoShadowRegistrationGoesToRedo(manager);
    NSMutableArray *open = UndoShadowStack(manager, UndoShadowOpenKey);
    /* An open group is only the right record while it sits on the stack this registration belongs to.
       Measured: an action redoing registers its inverse into a group that a registration made during
       the undo had already opened on the redo stack, and the inverse belongs on the undo stack - so
       reusing that record there is what left undoCount 0 where the release says 1. */
    NSMutableArray *target = toRedo ? UndoShadowStack(manager, UndoShadowRedoKey)
                                    : UndoShadowStack(manager, UndoShadowStackKey);
    /* Reused only when it is still a member of the stack this registration goes to. Testing which
       stack it was on is not enough: a record a redo had already popped is on neither, and reusing it
       put a registration into nothing, which is how undoCount came back 0 after a redo. */
    if (open.count && [target containsObject:open.lastObject])
        return open.lastObject;
    [open removeAllObjects];
    if (!creating)
        return UndoShadowStack(manager, UndoShadowStackKey).lastObject;
    CharonUndoRecord *record = [CharonUndoRecord new];
    [open addObject:record];
    NSMutableArray *redo = UndoShadowStack(manager, UndoShadowRedoKey);
    if (toRedo) {
        /* What the undo popped hands its user info to whatever becomes redoable: measured, the
           release's redoActionUserInfoValueForKey: reads "two", the tag of the group just undone,
           after the action registered its inverse. */
        NSMutableDictionary *inherited = objc_getAssociatedObject(manager, UndoShadowInheritedKey);
        if (inherited)
            [record.userInfo addEntriesFromDictionary:inherited];
        [redo addObject:record];
    } else {
        /* A registration outside an undo or a redo is a fresh action, and the release drops what was
           redoable when one arrives. Inside a redo it does not: measured, redoCount is 1 after a redo
           out of 2, so what the redo did not consume stays redoable. */
        if (![manager isUndoing] && ![manager isRedoing])
            [redo removeAllObjects];
        objc_setAssociatedObject(manager, UndoShadowInheritedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [UndoShadowStack(manager, UndoShadowStackKey) addObject:record];
    }
    return record;
}

static CharonUndoRecord *UndoShadowTakeTop(NSMutableArray *stack)
{
    CharonUndoRecord *record = stack.lastObject;
    if (record)
        [stack removeLastObject];
    return record;
}

/* --- the shadow's side of each wrapped method, then the release's --- */

static void charon_registerUndoWithTarget_selector_object(id self, SEL selector, id target, SEL action, id object)
{
    CharonUndoRecord *record = UndoShadowCurrent(self, YES);
    if (!record.target)
        record.target = target;
    if (!record.actionName)
        record.actionName = NSStringFromSelector(action);
    nativeRegisterUndo(self, selector, target, action, object);
}

/* A group's name has two spellings across the releases this port spans - setUndoActionName: on iOS,
   setActionName: elsewhere - and both mean the same thing, so both are wrapped and either one names
   the record. On the host only setActionName: exists, and on 6.1.3 only setUndoActionName: does. */
static void charon_setUndoActionName(NSUndoManager *self, SEL selector, NSString *actionName)
{
    UndoShadowCurrent(self, YES).actionName = actionName;
    nativeSetUndoActionName(self, selector, actionName);
}

static void charon_setActionName(NSUndoManager *self, SEL selector, NSString *actionName)
{
    UndoShadowCurrent(self, YES).actionName = actionName;
    nativeSetActionName(self, selector, actionName);
}

/* Same for ending a group: closeUndoGroup on iOS, endUndoGrouping wherever both releases have it.
   The record stays on the undo stack when the group closes, which is where undo will find it. */
static void charon_closeUndoGroup(NSUndoManager *self, SEL selector)
{
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    nativeCloseUndoGroup(self, selector);
}

static void charon_endUndoGrouping(NSUndoManager *self, SEL selector)
{
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    nativeEndUndoGrouping(self, selector);
}

static void charon_undo(NSUndoManager *self, SEL selector)
{
    /* The record comes off the undo stack and nothing goes onto the redo stack: what becomes
       redoable is whatever the action registers while it runs, which is the release's own model and
       was measured - an action that registers nothing leaves redoCount 0 and canRedo NO. */
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    CharonUndoRecord *undone = UndoShadowTakeTop(UndoShadowStack(self, UndoShadowStackKey));
    /* The popped group's user info is what the redo stack will read, whether or not the action
       registers anything: the plain case measured redoActionUserInfoValueForKey: as nil because
       nothing was redoable at all, not because the info was dropped. */
    objc_setAssociatedObject(self, UndoShadowInheritedKey,
                             undone.userInfo ?: [NSMutableDictionary dictionary], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    nativeUndo(self, selector);
}

static void charon_redo(NSUndoManager *self, SEL selector)
{
    /* Likewise: the action running during a redo registers its own inverse, and that registration is
       what lands back on the undo stack. */
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    UndoShadowTakeTop(UndoShadowStack(self, UndoShadowRedoKey));
    objc_setAssociatedObject(self, UndoShadowInheritedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    nativeRedo(self, selector);
}

static void charon_removeAllActions(NSUndoManager *self, SEL selector)
{
    [UndoShadowStack(self, UndoShadowStackKey) removeAllObjects];
    [UndoShadowStack(self, UndoShadowRedoKey) removeAllObjects];
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    nativeRemoveAllActions(self, selector);
}

static void charon_removeAllActionsWithTarget(NSUndoManager *self, SEL selector, id target)
{
    NSMutableArray *survivors = [NSMutableArray array];
    NSMutableArray *undo = UndoShadowStack(self, UndoShadowStackKey);
    for (CharonUndoRecord *record in undo)
        if (record.target != target)
            [survivors addObject:record];
    [undo setArray:survivors];
    [survivors removeAllObjects];
    NSMutableArray *redo = UndoShadowStack(self, UndoShadowRedoKey);
    for (CharonUndoRecord *record in redo)
        if (record.target != target)
            [survivors addObject:record];
    [redo setArray:survivors];
    nativeRemoveAllActionsWithTarget(self, selector, target);
}

@interface CharonUndoManagerInstaller18 : NSObject
@end

@implementation CharonUndoManagerInstaller18

+ (void)load
{
    /* Where the release has these five itself there is nothing to shadow: counting as well as counting
       the release's own stack would answer twice what is there. The guard is also what makes this run
       once - a second install would wrap this file's own functions. */
    if ([NSUndoManager instancesRespondToSelector:@selector(setActionUserInfoValue:forKey:)])
        return;
    Class manager = [NSUndoManager class];
    Method method;
    if ((method = class_getInstanceMethod(manager, @selector(registerUndoWithTarget:selector:object:)))) {
        nativeRegisterUndo = (RegisterUndoIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_registerUndoWithTarget_selector_object);
    }
    if ((method = class_getInstanceMethod(manager, @selector(setUndoActionName:)))) {
        nativeSetUndoActionName = (UndoActionNameIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_setUndoActionName);
    }
    if ((method = class_getInstanceMethod(manager, @selector(closeUndoGroup)))) {
        nativeCloseUndoGroup = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_closeUndoGroup);
    }
    if ((method = class_getInstanceMethod(manager, @selector(setActionName:)))) {
        nativeSetActionName = (UndoActionNameIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_setActionName);
    }
    if ((method = class_getInstanceMethod(manager, @selector(endUndoGrouping)))) {
        nativeEndUndoGrouping = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_endUndoGrouping);
    }
    if ((method = class_getInstanceMethod(manager, @selector(undo)))) {
        nativeUndo = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_undo);
    }
    if ((method = class_getInstanceMethod(manager, @selector(redo)))) {
        nativeRedo = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_redo);
    }
    if ((method = class_getInstanceMethod(manager, @selector(removeAllActions)))) {
        nativeRemoveAllActions = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_removeAllActions);
    }
    if ((method = class_getInstanceMethod(manager, @selector(removeAllActionsWithTarget:)))) {
        nativeRemoveAllActionsWithTarget = (RemoveWithTargetIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)charon_removeAllActionsWithTarget);
    }
}

@end

@implementation NSUndoManager (CharonActionUserInfo18)

/* These five are additions, so nothing here is called through, and they are keyed per manager: a
   manager that has registered nothing still answers 0, nil and nil rather than having nothing at all. */

- (NSUInteger)undoCount
{
    return UndoShadowStack(self, UndoShadowStackKey).count;
}

- (NSUInteger)redoCount
{
    return UndoShadowStack(self, UndoShadowRedoKey).count;
}

- (void)setActionUserInfoValue:(id)value forKey:(NSString *)key
{
    /* With no group open and nothing on the undo stack the release refuses, and says so:
     * NSInternalInconsistencyException, "must begin a group before setting undo action user info".
     * Measured, not assumed - and it is the reason this does not create a group the way the rest of
     * the shadow does, because a group made here would be one the release does not have. */
    CharonUndoRecord *record = UndoShadowCurrent(self, NO);
    if (!record) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"setActionUserInfoValue:forKey:: NSUndoManager %p is in invalid state, must begin a group before setting undo action user info", self];
        return;
    }
    /* Held, not copied. The release does not copy it either, and that was measured rather than
       assumed: a mutable string set as user info and appended to afterwards reads back with the
       append on it, so copying here would answer differently from the release. */
    record.userInfo[key] = value;
}

- (id)undoActionUserInfoValueForKey:(NSString *)key
{
    CharonUndoRecord *record = UndoShadowStack(self, UndoShadowStackKey).lastObject;
    return record.userInfo[key];
}

- (id)redoActionUserInfoValueForKey:(NSString *)key
{
    CharonUndoRecord *record = UndoShadowStack(self, UndoShadowRedoKey).lastObject;
    return record.userInfo[key];
}

@end
