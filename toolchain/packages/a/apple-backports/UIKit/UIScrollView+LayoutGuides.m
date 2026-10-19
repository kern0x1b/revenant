#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UILayoutGuide (CharonScroll)
- (UIView *)charon_view;
@end

@interface UIScrollView (CharonLayoutGuidesPrivate)
- (void)charon_updateLayoutGuides;
@end

static char charon_content_guide_key;
static char charon_frame_guide_key;
static char charon_frame_constraints_key;
static char charon_observer_key;
static char charon_explicit_size_key;
static char charon_desired_offset_key;
static char charon_apply_key;

static BOOL charon_in_layout;
static BOOL charon_in_size;

@interface CharonScrollGuideObserver : NSObject
@property (nonatomic, weak) UIScrollView *scrollView;
@end

@implementation CharonScrollGuideObserver
@synthesize scrollView = _scrollView;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!charon_in_size && !charon_in_layout)
        [_scrollView setNeedsUpdateConstraints];
}

- (void)dealloc
{
    UIScrollView *view = _scrollView;
    if (view)
        [view removeObserver:self forKeyPath:@"frame"];
}

@end

static void charon_scroll_hook(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SEL layout = @selector(layoutSubviews);
        Method method = class_getInstanceMethod([UIScrollView class], layout);
        void (*original)(id, SEL) = (void (*)(id, SEL))method_getImplementation(method);
        class_replaceMethod([UIScrollView class], layout, imp_implementationWithBlock(^(UIScrollView *self) {
            BOOL guided = objc_getAssociatedObject(self, &charon_observer_key) != nil;
            BOOL outer = charon_in_layout;
            charon_in_layout = guided;
            original(self, layout);
            charon_in_layout = outer;
            UILayoutGuide *content = objc_getAssociatedObject(self, &charon_content_guide_key);
            if (content && !objc_getAssociatedObject(self, &charon_apply_key)) {
                CGSize size = content.layoutFrame.size;
                if (size.width > 0 && size.height > 0) {
                    objc_setAssociatedObject(self, &charon_apply_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        objc_setAssociatedObject(self, &charon_apply_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        CGSize wanted = content.layoutFrame.size;
                        if (wanted.width > 0 && wanted.height > 0)
                            self.contentSize = wanted;
                    });
                }
            }
        }), method_getTypeEncoding(method));
        SEL getSize = @selector(contentSize);
        Method getSizeMethod = class_getInstanceMethod([UIScrollView class], getSize);
        CGSize (*getSizeOriginal)(id, SEL) = (CGSize (*)(id, SEL))method_getImplementation(getSizeMethod);
        class_replaceMethod([UIScrollView class], getSize, imp_implementationWithBlock(^CGSize(UIScrollView *self) {
            UILayoutGuide *content = objc_getAssociatedObject(self, &charon_content_guide_key);
            if (content) {
                CGSize size = content.layoutFrame.size;
                if (size.width > 0 && size.height > 0)
                    return size;
            }
            return getSizeOriginal(self, getSize);
        }), method_getTypeEncoding(getSizeMethod));
        SEL update = @selector(updateConstraints);
        Method updateMethod = class_getInstanceMethod([UIScrollView class], update);
        void (*updateOriginal)(id, SEL) = (void (*)(id, SEL))method_getImplementation(updateMethod);
        class_replaceMethod([UIScrollView class], update, imp_implementationWithBlock(^(UIScrollView *self) {
            if (objc_getAssociatedObject(self, &charon_observer_key))
                [self charon_updateLayoutGuides];
            updateOriginal(self, update);
        }), method_getTypeEncoding(updateMethod));
        SEL setOffset = @selector(setContentOffset:);
        Method setOffsetMethod = class_getInstanceMethod([UIScrollView class], setOffset);
        void (*setOffsetOriginal)(id, SEL, CGPoint) = (void (*)(id, SEL, CGPoint))method_getImplementation(setOffsetMethod);
        class_replaceMethod([UIScrollView class], setOffset, imp_implementationWithBlock(^(UIScrollView *self, CGPoint point) {
            if (!charon_in_size && objc_getAssociatedObject(self, &charon_observer_key))
                objc_setAssociatedObject(self, &charon_desired_offset_key, [NSValue valueWithCGPoint:point], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            setOffsetOriginal(self, setOffset, point);
        }), method_getTypeEncoding(setOffsetMethod));
        SEL setSize = @selector(setContentSize:);
        Method setSizeMethod = class_getInstanceMethod([UIScrollView class], setSize);
        void (*setSizeOriginal)(id, SEL, CGSize) = (void (*)(id, SEL, CGSize))method_getImplementation(setSizeMethod);
        class_replaceMethod([UIScrollView class], setSize, imp_implementationWithBlock(^(UIScrollView *self, CGSize size) {
            if (objc_getAssociatedObject(self, &charon_content_guide_key)) {
                NSValue *explicit = objc_getAssociatedObject(self, &charon_explicit_size_key);
                BOOL empty = size.width <= 0 && size.height <= 0;
                if (empty && explicit && [explicit CGSizeValue].width > 0)
                    size = [explicit CGSizeValue];
                else if (!empty && !charon_in_layout)
                    objc_setAssociatedObject(self, &charon_explicit_size_key, [NSValue valueWithCGSize:size], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            BOOL guided = objc_getAssociatedObject(self, &charon_observer_key) != nil;
            BOOL outer = charon_in_size;
            charon_in_size = guided;
            setSizeOriginal(self, setSize, size);
            charon_in_size = outer;
            NSValue *desired = guided ? objc_getAssociatedObject(self, &charon_desired_offset_key) : nil;
            if (desired && size.width > 0 && size.height > 0 && !self.isDragging && !self.isDecelerating) {
                CGPoint wanted = [desired CGPointValue];
                wanted.x = MAX(0, MIN(wanted.x, size.width - self.bounds.size.width));
                wanted.y = MAX(0, MIN(wanted.y, size.height - self.bounds.size.height));
                if (!CGPointEqualToPoint(wanted, self.contentOffset)) {
                    charon_in_size = YES;
                    setOffsetOriginal(self, setOffset, wanted);
                    charon_in_size = outer;
                }
            }
        }), method_getTypeEncoding(setSizeMethod));
    });
}

static void charon_observe(UIScrollView *view)
{
    charon_scroll_hook();
    if (objc_getAssociatedObject(view, &charon_observer_key))
        return;
    CharonScrollGuideObserver *observer = [[CharonScrollGuideObserver alloc] init];
    observer.scrollView = view;
    objc_setAssociatedObject(view, &charon_observer_key, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [view addObserver:observer forKeyPath:@"frame" options:0 context:NULL];
}

@implementation UIScrollView (CharonLayoutGuides)

- (UILayoutGuide *)charon_makeGuide:(NSString *)identifier
{
    UILayoutGuide *guide = [[UILayoutGuide alloc] init];
    guide.identifier = identifier;
    [self addLayoutGuide:guide];
    return guide;
}

- (UILayoutGuide *)frameLayoutGuide
{
    UILayoutGuide *guide = objc_getAssociatedObject(self, &charon_frame_guide_key);
    if (guide)
        return guide;
    guide = [self charon_makeGuide:@"UIScrollViewFrameLayoutGuide"];
    objc_setAssociatedObject(self, &charon_frame_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_observe(self);
    [self charon_updateLayoutGuides];
    return guide;
}

- (UILayoutGuide *)contentLayoutGuide
{
    UILayoutGuide *guide = objc_getAssociatedObject(self, &charon_content_guide_key);
    if (guide)
        return guide;
    objc_setAssociatedObject(self, &charon_explicit_size_key, [NSValue valueWithCGSize:self.contentSize], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    guide = [self charon_makeGuide:@"UIScrollViewContentLayoutGuide"];
    objc_setAssociatedObject(self, &charon_content_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIView *item = [guide charon_view];
    NSArray *constraints = @[
        [NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:0]
    ];
    NSValue *explicit = objc_getAssociatedObject(self, &charon_explicit_size_key);
    [self addConstraints:constraints];
    if (explicit && !CGSizeEqualToSize([explicit CGSizeValue], self.contentSize))
        self.contentSize = [explicit CGSizeValue];
    charon_observe(self);
    return guide;
}

- (void)charon_updateLayoutGuides
{
    UILayoutGuide *guide = objc_getAssociatedObject(self, &charon_frame_guide_key);
    if (!guide)
        return;
    NSArray *frame = objc_getAssociatedObject(self, &charon_frame_constraints_key);
    CGSize size = self.bounds.size;
    if (frame) {
        CGFloat constants[] = {size.width, size.height};
        for (NSUInteger index = 0; index < 2; index++) {
            NSLayoutConstraint *constraint = frame[index];
            if (fabs(constraint.constant - constants[index]) > 0.01)
                constraint.constant = constants[index];
        }
        return;
    }
    UIView *item = [guide charon_view];
    NSArray *fresh = @[
        [NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:size.width],
        [NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:size.height],
        [NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:0]
    ];
    objc_setAssociatedObject(self, &charon_frame_constraints_key, fresh, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addConstraints:fresh];
}

@end
