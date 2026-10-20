#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - UIPasteConfiguration

@implementation UIPasteConfiguration {
    NSMutableArray *_typeIdentifiers;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _typeIdentifiers = [NSMutableArray array];
    return self;
}

- (instancetype)initWithAcceptableTypeIdentifiers:(NSArray<NSString *> *)acceptableTypeIdentifiers
{
    self = [self init];
    if (self)
        [self addAcceptableTypeIdentifiers:acceptableTypeIdentifiers];
    return self;
}

- (void)addAcceptableTypeIdentifiers:(NSArray<NSString *> *)acceptableTypeIdentifiers
{
    for (NSString *identifier in acceptableTypeIdentifiers) {
        if ([identifier isKindOfClass:[NSString class]] && ![_typeIdentifiers containsObject:identifier])
            [_typeIdentifiers addObject:identifier];
    }
}

- (instancetype)initWithTypeIdentifiersForAcceptingClass:(Class<NSItemProviderReading>)aClass
{
    self = [self init];
    if (self)
        [self addTypeIdentifiersForAcceptingClass:aClass];
    return self;
}

- (void)addTypeIdentifiersForAcceptingClass:(Class<NSItemProviderReading>)aClass
{
    if (![aClass respondsToSelector:@selector(readableTypeIdentifiersForItemProvider)])
        return;
    NSArray *identifiers = [aClass readableTypeIdentifiersForItemProvider];
    if ([identifiers isKindOfClass:[NSArray class]])
        [self addAcceptableTypeIdentifiers:identifiers];
}

- (NSArray<NSString *> *)acceptableTypeIdentifiers
{
    return [_typeIdentifiers copy];
}

- (void)setAcceptableTypeIdentifiers:(NSArray<NSString *> *)acceptableTypeIdentifiers
{
    _typeIdentifiers = [NSMutableArray array];
    [self addAcceptableTypeIdentifiers:acceptableTypeIdentifiers];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithAcceptableTypeIdentifiers:_typeIdentifiers];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self)
        _typeIdentifiers = [NSMutableArray arrayWithArray:[coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:NSStringFromSelector(@selector(acceptableTypeIdentifiers))]];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_typeIdentifiers forKey:NSStringFromSelector(@selector(acceptableTypeIdentifiers))];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

#pragma mark - UIAccessibilityLocationDescriptor

@implementation UIAccessibilityLocationDescriptor {
    __weak UIView *_view;
    CGPoint _point;
    NSString *_name;
    NSAttributedString *_attributedName;
}

- (instancetype)initWithName:(NSString *)name point:(CGPoint)point inView:(UIView *)view
{
    return [self initWithAttributedName:[[NSAttributedString alloc] initWithString:name ?: @""] point:point inView:view];
}

- (instancetype)initWithName:(NSString *)name view:(UIView *)view
{
    return [self initWithName:name point:CGPointZero inView:view];
}

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName point:(CGPoint)point inView:(UIView *)view
{
    self = [super init];
    if (self) {
        _attributedName = [attributedName copy];
        _name = [_attributedName.string copy];
        _point = point;
        _view = view;
    }
    return self;
}

- (UIView *)view
{
    return _view;
}

- (CGPoint)point
{
    return _point;
}

- (NSString *)name
{
    return _name;
}

- (NSAttributedString *)attributedName
{
    return _attributedName;
}

@end

#pragma mark - UIAccessibilityReadingContent, and the delegates that describe a component in text

@implementation NSObject (RevenantIOS11AccessibilityContent)

- (NSAttributedString *)accessibilityAttributedPageContent
{
    return self.accessibilityAttributedLabel;
}

- (NSAttributedString *)accessibilityAttributedContentForLineNumber:(NSInteger)lineNumber
{
    return self.accessibilityAttributedPageContent;
}

@end

@implementation UIScrollView (RevenantIOS11AccessibilityContent)

- (NSAttributedString *)accessibilityAttributedScrollStatusForScrollView:(UIScrollView *)scrollView
{
    if (!scrollView)
        return nil;
    CGFloat visible = CGRectGetHeight(scrollView.bounds);
    CGFloat content = scrollView.contentSize.height;
    NSInteger perCent = 100;
    if (visible > 0 && content > visible)
        perCent = (NSInteger)lrint(100.0 * (scrollView.contentOffset.y + visible) / content);
    perCent = MAX(0, MIN(100, perCent));
    NSString *status = [NSString stringWithFormat:@"%ld%%", (long)perCent];
    return [[NSAttributedString alloc] initWithString:status];
}

@end

@implementation UIPickerView (RevenantIOS11AccessibilityContent)

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView accessibilityAttributedLabelForComponent:(NSInteger)component
{
    return [[NSAttributedString alloc] initWithString:@""];
}

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView accessibilityAttributedHintForComponent:(NSInteger)component
{
    return [[NSAttributedString alloc] initWithString:@""];
}

@end

#pragma mark - UIPasteboard's item providers

static char RevenantItemProvidersKey;
static char RevenantItemProvidersExpiryKey;

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIPasteboard (RevenantIOS11ItemProviders)

- (void)setItemProviders:(NSArray<NSItemProvider *> *)itemProviders
   localOnly:(BOOL)localOnly
 expirationDate:(NSDate *)expirationDate
{
    (void)localOnly;
    objc_setAssociatedObject(self, &RevenantItemProvidersKey, [itemProviders copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &RevenantItemProvidersExpiryKey, expirationDate, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSArray<NSItemProvider *> *)itemProviders
{
    NSArray *held = objc_getAssociatedObject(self, &RevenantItemProvidersKey);
    if (!held)
        return nil;
    NSDate *expiry = objc_getAssociatedObject(self, &RevenantItemProvidersExpiryKey);
    if (expiry && [expiry timeIntervalSinceNow] <= 0)
        return nil;
    return held;
}

@end

#pragma mark - UIBarItem's large content image

static char RevenantLargeContentImageKey;
static char RevenantLargeContentImageInsetsKey;

@implementation UIBarItem (RevenantIOS11LargeContentImage)

- (UIImage *)largeContentSizeImage
{
    return objc_getAssociatedObject(self, &RevenantLargeContentImageKey);
}

- (void)setLargeContentSizeImage:(UIImage *)largeContentSizeImage
{
    objc_setAssociatedObject(self, &RevenantLargeContentImageKey, largeContentSizeImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)largeContentSizeImageInsets
{
    NSValue *held = objc_getAssociatedObject(self, &RevenantLargeContentImageInsetsKey);
    return held ? [held UIEdgeInsetsValue] : UIEdgeInsetsZero;
}

- (void)setLargeContentSizeImageInsets:(UIEdgeInsets)largeContentSizeImageInsets
{
    objc_setAssociatedObject(self, &RevenantLargeContentImageInsetsKey, [NSValue valueWithUIEdgeInsets:largeContentSizeImageInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark - Coordinated focus animations

@implementation UIFocusAnimationCoordinator (RevenantIOS11FocusAnimations)

- (void)addCoordinatedFocusingAnimations:(void (^)(void))animations completion:(void (^)(void))completion
{
    [self addCoordinatedAnimations:animations completion:completion];
}

- (void)addCoordinatedUnfocusingAnimations:(void (^)(void))animations completion:(void (^)(void))completion
{
    [self addCoordinatedAnimations:animations completion:completion];
}

@end
