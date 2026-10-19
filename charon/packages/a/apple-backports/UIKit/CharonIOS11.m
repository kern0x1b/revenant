#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// The API iOS 11.0 added that a 6.1.3 application can reach, and no other release's. One object, so
// everything exported below belongs to 11.0 and to nothing else: the two classes are placed by their
// registry rows' minimum (6.0, every band this port builds) and every category here adds only 11.0
// members, so tools/release-split.lua finds one release across the file's symbols.
//
// What each row's claim rests on, read on this machine and not taken on trust:
//
//   objc-inventory over the 6.1.3 and 4.3 armv7 caches, class-scoped, with a control in the same run:
//   UIPasteboard, UIBarItem, UITextView, UIFocusAnimationCoordinator's owner and UIScrollView are in
//   both releases and carry none of the members added here, and both carry -setItems:, -setContentInset:,
//   -selectedTextInRange: and -addCoordinatedAnimations:completion:, which is what these are built on. The
//   classes UIPasteConfiguration and UIAccessibilityLocationDescriptor are in neither cache, so the port
//   builds them whole, and their members are answered by their own class rows.
//
// Every value here is the release's own or the port's own arithmetic on it. Nothing here stands in for
// UIKit's own event handling, its own table and collection layout, its own focus engine, its own keyboard
// or its own interprocess pasteboard, and the registry rows for those say so where they are listed.

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
        // A configuration names what a target accepts, and a type it already accepts adds nothing to it.
        // Skipping the repeat is what makes -addAcceptableTypeIdentifiers:order independent, which is
        // what the release's own does for the same reason.
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
    // Asked of the class rather than assumed of it: the release's own NSItemProviderReading is a
    // protocol an object adopts, so a class named here may not answer at all, and a configuration that
    // accepted nothing would be worse than one that says what it has.
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

// The three initialisers are one shape with two ways of naming it: a plain string is the attributed
// name's string, so -name and -attributedName never disagree and a caller that set one has both.
// Neither class is redeclared here: the SDK header the port compiles against declares both, and an
// @interface over it is a duplicate definition, so the members below are the header's own.
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

@implementation NSObject (CharonIOS11AccessibilityContent)

// The attributed content of a whole page or of one line of it is the element's own attributed label:
// the release's accessibility label carries no styling, so the styled form is the plain one with no
// attributes dropped. There is no line model to answer a line number against, so a line asks for the
// same string and a caller that paginates gets the whole page on every line rather than a wrong line.
- (NSAttributedString *)accessibilityAttributedPageContent
{
    return self.accessibilityAttributedLabel;
}

- (NSAttributedString *)accessibilityAttributedContentForLineNumber:(NSInteger)lineNumber
{
    return self.accessibilityAttributedPageContent;
}

@end

@implementation UIScrollView (CharonIOS11AccessibilityContent)

// "50%", read off the release's own geometry: where the top of the visible rect sits between the start
// and the end of the content, as a whole number of per cent, which is the shape VoiceOver speaks and the
// only thing this release's UIScrollView has to say about how far along it is. Attributed so a caller
// that hands it to a label keeps the styling it asked for.
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

@implementation UIPickerView (CharonIOS11AccessibilityContent)

// A picker's component has no label of its own on this release: -accessibilityLabel reads empty for a
// component view, so both answers are the empty styled string rather than a name the picker never had.
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

static char CharonItemProvidersKey;
static char CharonItemProvidersExpiryKey;

// The warning clang gives here is about the SDK's own UIPasteboard declaring the method, not about the
// release's: the 6.1.3 and 4.3 selector tables above carry no -setItemProviders:localOnly:expirationDate:,
// so on either release this category's method is the only one there is and nothing is being overridden.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIPasteboard (CharonIOS11ItemProviders)

// The providers an application puts on the pasteboard, held as they were given. The expiration date is
// honoured on the read rather than by a timer, because the release's UIPasteboard has no expiration of
// its own and a timer would be the port guessing when the system meant to expire: a provider whose date
// has passed is simply not in the answer, which is what the caller reads. localOnly is named and not
// kept: the port's pasteboard and its drag both stay inside the one process that began them, so no
// provider ever leaves to another process and the flag has nothing to decide.
- (void)setItemProviders:(NSArray<NSItemProvider *> *)itemProviders
   localOnly:(BOOL)localOnly
 expirationDate:(NSDate *)expirationDate
{
    (void)localOnly;
    objc_setAssociatedObject(self, &CharonItemProvidersKey, [itemProviders copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &CharonItemProvidersExpiryKey, expirationDate, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSArray<NSItemProvider *> *)itemProviders
{
    NSArray *held = objc_getAssociatedObject(self, &CharonItemProvidersKey);
    if (!held)
        return nil;
    NSDate *expiry = objc_getAssociatedObject(self, &CharonItemProvidersExpiryKey);
    if (expiry && [expiry timeIntervalSinceNow] <= 0)
        return nil;
    return held;
}

@end

#pragma mark - UIBarItem's large content image

static char CharonLargeContentImageKey;
static char CharonLargeContentImageInsetsKey;

@implementation UIBarItem (CharonIOS11LargeContentImage)

// The image a bar item shows when it is looked at closely, and the insets that place it. Both are held
// and both read back; what the release draws with them is a context menu, and a release with no context
// menu draws nothing, so the registry row for each is inert rather than implemented.
- (UIImage *)largeContentSizeImage
{
    return objc_getAssociatedObject(self, &CharonLargeContentImageKey);
}

- (void)setLargeContentSizeImage:(UIImage *)largeContentSizeImage
{
    objc_setAssociatedObject(self, &CharonLargeContentImageKey, largeContentSizeImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)largeContentSizeImageInsets
{
    NSValue *held = objc_getAssociatedObject(self, &CharonLargeContentImageInsetsKey);
    return held ? [held UIEdgeInsetsValue] : UIEdgeInsetsZero;
}

- (void)setLargeContentSizeImageInsets:(UIEdgeInsets)largeContentSizeImageInsets
{
    objc_setAssociatedObject(self, &CharonLargeContentImageInsetsKey, [NSValue valueWithUIEdgeInsets:largeContentSizeImageInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark - Coordinated focus animations

@implementation UIFocusAnimationCoordinator (CharonIOS11FocusAnimations)

// The port's coordinator is the same coordinator the release's own object beside it is: it runs the
// animations and then the completion, because there is no focus engine to coordinate with. What these two
// add is the two entry points 11.0 gave the coordinator, so an application written against them is
// called rather than left answering NO to respondsToSelector:.
- (void)addCoordinatedFocusingAnimations:(void (^)(void))animations completion:(void (^)(void))completion
{
    [self addCoordinatedAnimations:animations completion:completion];
}

- (void)addCoordinatedUnfocusingAnimations:(void (^)(void))animations completion:(void (^)(void))completion
{
    [self addCoordinatedAnimations:animations completion:completion];
}

@end