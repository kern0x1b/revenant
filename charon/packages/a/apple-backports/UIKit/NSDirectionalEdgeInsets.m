#import <UIKit/UIKit.h>

const NSDirectionalEdgeInsets NSDirectionalEdgeInsetsZero = {0, 0, 0, 0};

NSString *NSStringFromDirectionalEdgeInsets(NSDirectionalEdgeInsets insets)
{
    return NSStringFromUIEdgeInsets(UIEdgeInsetsMake(insets.top, insets.leading, insets.bottom, insets.trailing));
}

NSDirectionalEdgeInsets NSDirectionalEdgeInsetsFromString(NSString *string)
{
    UIEdgeInsets edges = UIEdgeInsetsFromString(string);
    return NSDirectionalEdgeInsetsMake(edges.top, edges.left, edges.bottom, edges.right);
}

@implementation NSValue (CharonDirectionalEdgeInsets)

+ (NSValue *)valueWithDirectionalEdgeInsets:(NSDirectionalEdgeInsets)insets
{
    return [NSValue valueWithBytes:&insets objCType:@encode(NSDirectionalEdgeInsets)];
}

- (NSDirectionalEdgeInsets)directionalEdgeInsetsValue
{
    NSDirectionalEdgeInsets insets = NSDirectionalEdgeInsetsZero;
    if ([self respondsToSelector:@selector(getValue:size:)]) {
        [self getValue:&insets size:sizeof(insets)];
        return insets;
    }
    NSUInteger held = 0;
    NSGetSizeAndAlignment(self.objCType, &held, NULL);
    if (held != sizeof(insets))
        [NSException raise:NSInvalidArgumentException
                    format:@"Cannot get value with size %zu. The type encoded as %s is expected to be %zu bytes",
                           sizeof(insets), self.objCType, (size_t)held];
    [self getValue:&insets];
    return insets;
}

@end

@implementation NSCoder (CharonDirectionalEdgeInsets)

- (void)encodeDirectionalEdgeInsets:(NSDirectionalEdgeInsets)insets forKey:(NSString *)key
{
    [self encodeObject:NSStringFromDirectionalEdgeInsets(insets) forKey:key];
}

- (NSDirectionalEdgeInsets)decodeDirectionalEdgeInsetsForKey:(NSString *)key
{
    NSString *string = self.requiresSecureCoding ? [self decodeObjectOfClass:[NSString class] forKey:key] : [self decodeObjectForKey:key];
    return NSDirectionalEdgeInsetsFromString(string);
}

@end
