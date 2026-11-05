#import <UIKit/UIKit.h>

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
