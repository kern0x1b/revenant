#import <Foundation/Foundation.h>

NSString * const NSSecureUnarchiveFromDataTransformerName = @"NSSecureUnarchiveFromData";

@implementation NSSecureUnarchiveFromDataTransformer

+ (void)load
{
    @autoreleasepool {
        if (![NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName])
            [NSValueTransformer setValueTransformer:[[self alloc] init] forName:NSSecureUnarchiveFromDataTransformerName];
    }
}

+ (NSArray<Class> *)allowedTopLevelClasses
{
    Class wanted = [self transformedValueClass];
    if (wanted)
        return @[wanted];
    return @[[NSArray class], [NSDictionary class], [NSSet class], [NSString class], [NSNumber class],
             [NSDate class], [NSData class], [NSURL class], [NSUUID class], [NSNull class]];
}

- (id)transformedValue:(id)value
{
    if (!value)
        return nil;
    if (![value isKindOfClass:[NSData class]])
        [[NSException exceptionWithName:NSInvalidArgumentException reason:@"Cannot unarchive type from non-NSData object." userInfo:nil] raise];
    NSError *error = nil;
    NSSet *classes = [[NSSet alloc] initWithArray:[[self class] allowedTopLevelClasses]];
    id decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:value error:&error];
    if (!decoded && error)
        [[NSException exceptionWithName:NSInvalidUnarchiveOperationException reason:error.localizedDescription
                               userInfo:@{NSUnderlyingErrorKey: error}] raise];
    return decoded;
}

- (id)reverseTransformedValue:(id)value
{
    if (!value)
        return nil;
    BOOL allowed = NO;
    for (Class candidate in [[self class] allowedTopLevelClasses])
        allowed = allowed || [value isKindOfClass:candidate];
    if (!allowed)
        [[NSException exceptionWithName:NSInvalidArgumentException
                                 reason:[NSString stringWithFormat:@"Object of class %@ is not among allowed top level class list %@",
                                                                   [value class], [[self class] allowedTopLevelClasses]]
                               userInfo:nil] raise];
    NSError *error = nil;
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:&error];
    if (!archived && error)
        [[NSException exceptionWithName:NSInvalidArchiveOperationException reason:error.localizedDescription
                               userInfo:@{NSUnderlyingErrorKey: error}] raise];
    return archived;
}

@end
