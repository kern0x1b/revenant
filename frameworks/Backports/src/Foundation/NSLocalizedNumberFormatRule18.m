#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSString * const NSLocalizedNumberFormatAttributeName = @"NSLocalizedNumberFormat";

@implementation NSLocalizedNumberFormatRule

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (NSLocalizedNumberFormatRule *)automatic
{
    static NSLocalizedNumberFormatRule *automatic;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        automatic = class_createInstance([NSLocalizedNumberFormatRule class], 0);
    });
    return automatic;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [NSLocalizedNumberFormatRule automatic];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[NSLocalizedNumberFormatRule class]];
}

- (NSUInteger)hash
{
    return (NSUInteger)(__bridge void *)[NSLocalizedNumberFormatRule class];
}

@end
