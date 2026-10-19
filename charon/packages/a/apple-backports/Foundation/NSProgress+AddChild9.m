#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static const int64_t CharonProgressScale = 1000000;
static const char charon_link_key;
static const char charon_parent_key;
static const char charon_mirrors_key;

@interface CharonProgressLink : NSObject
@property (nonatomic, strong) NSProgress *child;
@property (nonatomic, weak) NSProgress *mirror;
@property (nonatomic, weak) NSProgress *parent;
- (void)synchronize;
@end

@implementation CharonProgressLink
@synthesize child = _child;
@synthesize mirror = _mirror;
@synthesize parent = _parent;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self synchronize];
}

- (void)synchronize
{
    NSProgress *child = _child;
    NSProgress *mirror = _mirror;
    if (!child || !mirror)
        return;
    double fraction = child.fractionCompleted;
    if (!(fraction > 0))
        fraction = 0;
    NSProgress *parent = _parent;
    [parent willChangeValueForKey:@"fractionCompleted"];
    mirror.completedUnitCount = fraction >= 1 ? CharonProgressScale : (int64_t)(fraction * CharonProgressScale);
    [parent didChangeValueForKey:@"fractionCompleted"];
    if (fraction >= 1)
        [self detach];
}

- (void)detach
{
    NSProgress *child = _child;
    if (!child)
        return;
    _child = nil;
    [child removeObserver:self forKeyPath:@"fractionCompleted"];
}

- (void)dealloc
{
    [self detach];
}

@end

@implementation NSProgress (CharonAddChild)

- (void)addChild:(NSProgress *)child withPendingUnitCount:(int64_t)inUnitCount
{
    NSValue *held = objc_getAssociatedObject(child, &charon_parent_key);
    if (held)
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSProgress addChild:withPendingUnitCount:]: NSProgress %p was already the child of another progress %p", child, held.nonretainedObjectValue];
    objc_setAssociatedObject(child, &charon_parent_key, [NSValue valueWithNonretainedObject:self], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self becomeCurrentWithPendingUnitCount:inUnitCount];
    NSProgress *mirror = [NSProgress progressWithTotalUnitCount:CharonProgressScale];
    [self resignCurrent];
    CharonProgressLink *link = [[CharonProgressLink alloc] init];
    link.child = child;
    link.mirror = mirror;
    link.parent = self;
    [child addObserver:link forKeyPath:@"fractionCompleted" options:0 context:NULL];
    objc_setAssociatedObject(mirror, &charon_link_key, link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableArray *mirrors = objc_getAssociatedObject(self, &charon_mirrors_key);
    if (!mirrors) {
        mirrors = [NSMutableArray array];
        objc_setAssociatedObject(self, &charon_mirrors_key, mirrors, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [mirrors addObject:mirror];
    [link synchronize];
}

@end

static void charon_pass_on(NSProgress *parent, SEL selector)
{
    for (NSProgress *mirror in [objc_getAssociatedObject(parent, &charon_mirrors_key) copy]) {
        CharonProgressLink *link = objc_getAssociatedObject(mirror, &charon_link_key);
        NSProgress *child = link.child;
        if (child)
            ((void (*)(id, SEL))objc_msgSend)(child, selector);
    }
}

@interface CharonProgressPatch : NSObject
@end

@implementation CharonProgressPatch

+ (void)load
{
    Class progress = [NSProgress class];
    // Below iOS 6, where NSProgress.m carries the class itself, instancesRespondToSelector: measures YES for
    // -addChild:withPendingUnitCount: already at +load time, even though this package's own class never implements it
    // natively (Foundation/NSProgress.m has no such method) - the timing this method's own comment (charon/AGENTS.md,
    // "+load in a backport") assumes for a category on the release's class does not carry over to a class this package
    // carries itself, measured on the emulator. Decided on the release alone, as that trap says: below iOS 6.0 the real
    // OS has no NSProgress at all, so this is always our own class and the swizzle always installs; from 6.0 (genuinely
    // no addChild until 9.0) instancesRespondToSelector: is read as before.
    BOOL ours = NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0;
    if (!ours && [NSProgress instancesRespondToSelector:@selector(addChild:withPendingUnitCount:)])
        return;
    for (NSValue *value in @[[NSValue valueWithPointer:@selector(cancel)], [NSValue valueWithPointer:@selector(pause)]]) {
        SEL selector = [value pointerValue];
        void (*original)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation(progress, selector);
        class_replaceMethod(progress, selector, imp_implementationWithBlock(^(NSProgress *self_) {
            original(self_, selector);
            charon_pass_on(self_, selector);
        }), method_getTypeEncoding(class_getInstanceMethod(progress, selector)));
    }
}

@end
