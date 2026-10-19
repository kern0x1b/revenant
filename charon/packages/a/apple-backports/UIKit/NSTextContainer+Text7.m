#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *ExclusionKey = &ExclusionKey;
static const void *WidthTracksKey = &WidthTracksKey;
static const void *HeightTracksKey = &HeightTracksKey;
static const void *BreakModeKey = &BreakModeKey;

@interface NSTextContainer (CharonNative)
- (NSUInteger)maximumNumberOfLines;
- (instancetype)initWithContainerSize:(CGSize)size;
- (CGSize)containerSize;
- (void)setContainerSize:(CGSize)size;
- (CGRect)lineFragmentRectForProposedRect:(CGRect)proposed sweepDirection:(NSUInteger)sweep movementDirection:(NSUInteger)movement remainingRect:(CGRect *)remaining;
@end

typedef BOOL (*SimpleIMP)(id, SEL);
static SimpleIMP native_simple;

static BOOL is_simple(NSTextContainer *self, SEL selector)
{
    return native_simple(self, selector) && ![self exclusionPaths].count && ![self maximumNumberOfLines];
}

@interface CharonTextContainer7 : NSObject
@end

@implementation CharonTextContainer7

+ (void)load
{
    if ([NSTextContainer instancesRespondToSelector:@selector(exclusionPaths)])
        return;
    Method method = class_getInstanceMethod([NSTextContainer class], @selector(isSimpleRectangularTextContainer));
    if (method) {
        native_simple = (SimpleIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)is_simple);
    }
}

@end

@implementation NSTextContainer (CharonText7)

- (instancetype)initWithSize:(CGSize)size
{
    return [self initWithContainerSize:size];
}

- (CGSize)size
{
    return [self containerSize];
}

- (void)setSize:(CGSize)size
{
    [self setContainerSize:size];
}

- (NSArray<UIBezierPath *> *)exclusionPaths
{
    return objc_getAssociatedObject(self, ExclusionKey) ?: @[];
}

- (void)setExclusionPaths:(NSArray<UIBezierPath *> *)paths
{
    objc_setAssociatedObject(self, ExclusionKey, [paths copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)widthTracksTextView
{
    return [objc_getAssociatedObject(self, WidthTracksKey) boolValue];
}

- (void)setWidthTracksTextView:(BOOL)tracks
{
    objc_setAssociatedObject(self, WidthTracksKey, @(tracks), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)heightTracksTextView
{
    return [objc_getAssociatedObject(self, HeightTracksKey) boolValue];
}

- (void)setHeightTracksTextView:(BOOL)tracks
{
    objc_setAssociatedObject(self, HeightTracksKey, @(tracks), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSLineBreakMode)lineBreakMode
{
    return (NSLineBreakMode)[objc_getAssociatedObject(self, BreakModeKey) integerValue];
}

- (void)setLineBreakMode:(NSLineBreakMode)mode
{
    objc_setAssociatedObject(self, BreakModeKey, @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGRect)lineFragmentRectForProposedRect:(CGRect)proposed atIndex:(NSUInteger)index writingDirection:(NSWritingDirection)direction remainingRect:(CGRect *)remaining
{
    return [self lineFragmentRectForProposedRect:proposed sweepDirection:direction == NSWritingDirectionRightToLeft ? 0 : 1 movementDirection:3 remainingRect:remaining];
}

@end
