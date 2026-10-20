#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const void *UndoShadowStackKey = &UndoShadowStackKey;
static const void *UndoShadowRedoKey = &UndoShadowRedoKey;
static const void *UndoShadowOpenKey = &UndoShadowOpenKey;
static const void *UndoShadowInheritedKey = &UndoShadowInheritedKey;

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

@interface RevenantUndoRecord : NSObject
@property (nonatomic, copy) NSString *actionName;
@property (nonatomic, strong) NSMutableDictionary *userInfo;
@property (nonatomic, weak) id target;
@end

@implementation RevenantUndoRecord
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

static BOOL UndoShadowRegistrationGoesToRedo(NSUndoManager *manager)
{
    return [manager isUndoing] && ![manager isRedoing];
}

static RevenantUndoRecord *UndoShadowCurrent(NSUndoManager *manager, BOOL creating)
{
    BOOL toRedo = UndoShadowRegistrationGoesToRedo(manager);
    NSMutableArray *open = UndoShadowStack(manager, UndoShadowOpenKey);
    NSMutableArray *target = toRedo ? UndoShadowStack(manager, UndoShadowRedoKey)
                                    : UndoShadowStack(manager, UndoShadowStackKey);
    if (open.count && [target containsObject:open.lastObject])
        return open.lastObject;
    [open removeAllObjects];
    if (!creating)
        return UndoShadowStack(manager, UndoShadowStackKey).lastObject;
    RevenantUndoRecord *record = [RevenantUndoRecord new];
    [open addObject:record];
    NSMutableArray *redo = UndoShadowStack(manager, UndoShadowRedoKey);
    if (toRedo) {
        NSMutableDictionary *inherited = objc_getAssociatedObject(manager, UndoShadowInheritedKey);
        if (inherited)
            [record.userInfo addEntriesFromDictionary:inherited];
        [redo addObject:record];
    } else {
        if (![manager isUndoing] && ![manager isRedoing])
            [redo removeAllObjects];
        objc_setAssociatedObject(manager, UndoShadowInheritedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [UndoShadowStack(manager, UndoShadowStackKey) addObject:record];
    }
    return record;
}

static RevenantUndoRecord *UndoShadowTakeTop(NSMutableArray *stack)
{
    RevenantUndoRecord *record = stack.lastObject;
    if (record)
        [stack removeLastObject];
    return record;
}

static void revenant_registerUndoWithTarget_selector_object(id self, SEL selector, id target, SEL action, id object)
{
    RevenantUndoRecord *record = UndoShadowCurrent(self, YES);
    if (!record.target)
        record.target = target;
    if (!record.actionName)
        record.actionName = NSStringFromSelector(action);
    nativeRegisterUndo(self, selector, target, action, object);
}

static void revenant_setUndoActionName(NSUndoManager *self, SEL selector, NSString *actionName)
{
    UndoShadowCurrent(self, YES).actionName = actionName;
    nativeSetUndoActionName(self, selector, actionName);
}

static void revenant_setActionName(NSUndoManager *self, SEL selector, NSString *actionName)
{
    UndoShadowCurrent(self, YES).actionName = actionName;
    nativeSetActionName(self, selector, actionName);
}

static void revenant_closeUndoGroup(NSUndoManager *self, SEL selector)
{
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    nativeCloseUndoGroup(self, selector);
}

static void revenant_endUndoGrouping(NSUndoManager *self, SEL selector)
{
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    nativeEndUndoGrouping(self, selector);
}

static void revenant_undo(NSUndoManager *self, SEL selector)
{
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    RevenantUndoRecord *undone = UndoShadowTakeTop(UndoShadowStack(self, UndoShadowStackKey));
    objc_setAssociatedObject(self, UndoShadowInheritedKey,
                             undone.userInfo ?: [NSMutableDictionary dictionary], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    nativeUndo(self, selector);
}

static void revenant_redo(NSUndoManager *self, SEL selector)
{
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    UndoShadowTakeTop(UndoShadowStack(self, UndoShadowRedoKey));
    objc_setAssociatedObject(self, UndoShadowInheritedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    nativeRedo(self, selector);
}

static void revenant_removeAllActions(NSUndoManager *self, SEL selector)
{
    [UndoShadowStack(self, UndoShadowStackKey) removeAllObjects];
    [UndoShadowStack(self, UndoShadowRedoKey) removeAllObjects];
    [UndoShadowStack(self, UndoShadowOpenKey) removeAllObjects];
    nativeRemoveAllActions(self, selector);
}

static void revenant_removeAllActionsWithTarget(NSUndoManager *self, SEL selector, id target)
{
    NSMutableArray *survivors = [NSMutableArray array];
    NSMutableArray *undo = UndoShadowStack(self, UndoShadowStackKey);
    for (RevenantUndoRecord *record in undo)
        if (record.target != target)
            [survivors addObject:record];
    [undo setArray:survivors];
    [survivors removeAllObjects];
    NSMutableArray *redo = UndoShadowStack(self, UndoShadowRedoKey);
    for (RevenantUndoRecord *record in redo)
        if (record.target != target)
            [survivors addObject:record];
    [redo setArray:survivors];
    nativeRemoveAllActionsWithTarget(self, selector, target);
}

@interface RevenantUndoManagerInstaller18 : NSObject
@end

@implementation RevenantUndoManagerInstaller18

+ (void)load
{
    if ([NSUndoManager instancesRespondToSelector:@selector(setActionUserInfoValue:forKey:)])
        return;
    Class manager = [NSUndoManager class];
    Method method;
    if ((method = class_getInstanceMethod(manager, @selector(registerUndoWithTarget:selector:object:)))) {
        nativeRegisterUndo = (RegisterUndoIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_registerUndoWithTarget_selector_object);
    }
    if ((method = class_getInstanceMethod(manager, @selector(setUndoActionName:)))) {
        nativeSetUndoActionName = (UndoActionNameIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_setUndoActionName);
    }
    if ((method = class_getInstanceMethod(manager, @selector(closeUndoGroup)))) {
        nativeCloseUndoGroup = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_closeUndoGroup);
    }
    if ((method = class_getInstanceMethod(manager, @selector(setActionName:)))) {
        nativeSetActionName = (UndoActionNameIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_setActionName);
    }
    if ((method = class_getInstanceMethod(manager, @selector(endUndoGrouping)))) {
        nativeEndUndoGrouping = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_endUndoGrouping);
    }
    if ((method = class_getInstanceMethod(manager, @selector(undo)))) {
        nativeUndo = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_undo);
    }
    if ((method = class_getInstanceMethod(manager, @selector(redo)))) {
        nativeRedo = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_redo);
    }
    if ((method = class_getInstanceMethod(manager, @selector(removeAllActions)))) {
        nativeRemoveAllActions = (VoidIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_removeAllActions);
    }
    if ((method = class_getInstanceMethod(manager, @selector(removeAllActionsWithTarget:)))) {
        nativeRemoveAllActionsWithTarget = (RemoveWithTargetIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)revenant_removeAllActionsWithTarget);
    }
}

@end

@implementation NSUndoManager (RevenantActionUserInfo18)

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
    RevenantUndoRecord *record = UndoShadowCurrent(self, NO);
    if (!record) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"setActionUserInfoValue:forKey:: NSUndoManager %p is in invalid state, must begin a group before setting undo action user info", self];
        return;
    }
    record.userInfo[key] = value;
}

- (id)undoActionUserInfoValueForKey:(NSString *)key
{
    RevenantUndoRecord *record = UndoShadowStack(self, UndoShadowStackKey).lastObject;
    return record.userInfo[key];
}

- (id)redoActionUserInfoValueForKey:(NSString *)key
{
    RevenantUndoRecord *record = UndoShadowStack(self, UndoShadowRedoKey).lastObject;
    return record.userInfo[key];
}

@end
