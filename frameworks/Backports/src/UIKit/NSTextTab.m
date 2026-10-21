#import <UIKit/UIKit.h>
#import "../revenant_alias.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

REVENANT_ALIAS(NSTextTab)

static const char RevenantTabAlignmentKey;
static const char RevenantTabLocationKey;
static const char RevenantTabOptionsKey;

@implementation NSTextTab (RevenantColumns)

+ (NSCharacterSet *)columnTerminatorsForLocale:(NSLocale *)locale
{
    NSString *separator = locale ? [locale objectForKey:NSLocaleDecimalSeparator] : @".";
    return [NSCharacterSet characterSetWithCharactersInString:separator.length ? separator : @"."];
}

- (instancetype)initWithTextAlignment:(NSTextAlignment)alignment location:(CGFloat)location options:(NSDictionary *)options
{
    if ((self = [super init])) {
        objc_setAssociatedObject(self, &RevenantTabAlignmentKey, @(alignment), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &RevenantTabLocationKey, @(location), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &RevenantTabOptionsKey, [options copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return self;
}

- (NSTextAlignment)alignment
{
    return [objc_getAssociatedObject(self, &RevenantTabAlignmentKey) integerValue];
}

- (CGFloat)location
{
    return [objc_getAssociatedObject(self, &RevenantTabLocationKey) doubleValue];
}

- (NSDictionary *)options
{
    return objc_getAssociatedObject(self, &RevenantTabOptionsKey);
}

@end
