#import <Foundation/Foundation.h>
#import <math.h>
#import "CharonMethodProem.h"

typedef struct {
    Class isa;
    uint64_t count;
    id const *objects;
} CharonConstantArrayLayout;

typedef struct {
    Class isa;
    uint64_t reserved;
    uint64_t count;
    id const *keys;
    id const *objects;
} CharonConstantDictionaryLayout;

typedef struct {
    Class isa;
    const char *objCType;
    int64_t value;
} CharonConstantIntegerNumberLayout;

typedef struct {
    Class isa;
    const char *objCType;
    double value;
} CharonConstantDoubleNumberLayout;

@interface NSConstantArray : NSArray
@end

@implementation NSConstantArray

- (NSUInteger)count
{
    return (NSUInteger)((const CharonConstantArrayLayout *)(__bridge const void *)self)->count;
}

- (id)objectAtIndex:(NSUInteger)index
{
    const CharonConstantArrayLayout *layout = (const CharonConstantArrayLayout *)(__bridge const void *)self;
    if (index >= layout->count) {
        [NSException raise:NSRangeException format:@"%@: index %lu beyond bounds [0 .. %llu]",
                                                     charon_method_proem(self, _cmd), (unsigned long)index,
                                                     layout->count == 0 ? 0 : layout->count - 1];
    }
    return layout->objects[index];
}

@end

@interface NSConstantDictionary : NSDictionary
@end

@implementation NSConstantDictionary

- (NSUInteger)count
{
    return (NSUInteger)((const CharonConstantDictionaryLayout *)(__bridge const void *)self)->count;
}

- (id)objectForKey:(id)key
{
    const CharonConstantDictionaryLayout *layout = (const CharonConstantDictionaryLayout *)(__bridge const void *)self;
    for (uint64_t index = 0; index < layout->count; index++) {
        if ([layout->keys[index] isEqual:key]) {
            return layout->objects[index];
        }
    }
    return nil;
}

- (NSEnumerator *)keyEnumerator
{
    const CharonConstantDictionaryLayout *layout = (const CharonConstantDictionaryLayout *)(__bridge const void *)self;
    return [[NSArray arrayWithObjects:layout->keys count:(NSUInteger)layout->count] objectEnumerator];
}

@end

@interface NSConstantIntegerNumber : NSNumber
@end

@implementation NSConstantIntegerNumber

- (const CharonConstantIntegerNumberLayout *)charon_layout
{
    return (const CharonConstantIntegerNumberLayout *)(__bridge const void *)self;
}

- (const char *)objCType
{
    return [self charon_layout]->objCType;
}

- (void)getValue:(void *)buffer
{
    NSUInteger size = 0;
    NSGetSizeAndAlignment([self objCType], &size, NULL);
    memcpy(buffer, &[self charon_layout]->value, size == 0 ? sizeof(int64_t) : MIN(size, sizeof(int64_t)));
}

- (char)charValue { return (char)[self charon_layout]->value; }
- (unsigned char)unsignedCharValue { return (unsigned char)[self charon_layout]->value; }
- (short)shortValue { return (short)[self charon_layout]->value; }
- (unsigned short)unsignedShortValue { return (unsigned short)[self charon_layout]->value; }
- (int)intValue { return (int)[self charon_layout]->value; }
- (unsigned int)unsignedIntValue { return (unsigned int)[self charon_layout]->value; }
- (long)longValue { return (long)[self charon_layout]->value; }
- (unsigned long)unsignedLongValue { return (unsigned long)[self charon_layout]->value; }
- (long long)longLongValue { return (long long)[self charon_layout]->value; }
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)[self charon_layout]->value; }
- (NSInteger)integerValue { return (NSInteger)[self charon_layout]->value; }
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)[self charon_layout]->value; }
- (float)floatValue { return (float)[self charon_layout]->value; }
- (double)doubleValue { return (double)[self charon_layout]->value; }
- (BOOL)boolValue { return [self charon_layout]->value != 0; }

- (NSString *)stringValue
{
    return [NSString stringWithFormat:@"%lld", [self charon_layout]->value];
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return [self stringValue];
}

- (NSString *)description
{
    return [self stringValue];
}

- (NSComparisonResult)compare:(NSNumber *)other
{
    long long mine = [self longLongValue];
    long long theirs = [other longLongValue];
    if (mine < theirs) return NSOrderedAscending;
    if (mine > theirs) return NSOrderedDescending;
    return NSOrderedSame;
}

- (BOOL)isEqualToNumber:(NSNumber *)other
{
    return other != nil && [self longLongValue] == [other longLongValue];
}

- (BOOL)isEqual:(id)other
{
    if (self == other) {
        return YES;
    }
    if (![other isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    return [self isEqualToNumber:other];
}

- (NSUInteger)hash
{
    return (NSUInteger)[self longLongValue];
}

@end

@interface NSConstantDoubleNumber : NSNumber
@end

@implementation NSConstantDoubleNumber

- (const CharonConstantDoubleNumberLayout *)charon_layout
{
    return (const CharonConstantDoubleNumberLayout *)(__bridge const void *)self;
}

- (const char *)objCType
{
    return [self charon_layout]->objCType;
}

- (void)getValue:(void *)buffer
{
    double value = [self charon_layout]->value;
    if (strcmp([self objCType], @encode(float)) == 0) {
        float narrowed = (float)value;
        memcpy(buffer, &narrowed, sizeof(narrowed));
        return;
    }
    NSUInteger size = 0;
    NSGetSizeAndAlignment([self objCType], &size, NULL);
    memcpy(buffer, &value, size == 0 ? sizeof(double) : MIN(size, sizeof(double)));
}

- (char)charValue { return (char)[self charon_layout]->value; }
- (unsigned char)unsignedCharValue { return (unsigned char)[self charon_layout]->value; }
- (short)shortValue { return (short)[self charon_layout]->value; }
- (unsigned short)unsignedShortValue { return (unsigned short)[self charon_layout]->value; }
- (int)intValue { return (int)[self charon_layout]->value; }
- (unsigned int)unsignedIntValue { return (unsigned int)[self charon_layout]->value; }
- (long)longValue { return (long)[self charon_layout]->value; }
- (unsigned long)unsignedLongValue { return (unsigned long)[self charon_layout]->value; }
- (long long)longLongValue { return (long long)[self charon_layout]->value; }
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)[self charon_layout]->value; }
- (NSInteger)integerValue { return (NSInteger)[self charon_layout]->value; }
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)[self charon_layout]->value; }
- (float)floatValue { return (float)[self charon_layout]->value; }
- (double)doubleValue { return [self charon_layout]->value; }
- (BOOL)boolValue { return [self charon_layout]->value != 0; }

- (NSString *)stringValue
{
    double value = [self charon_layout]->value;
    if (isnan(value))
        return @"nan";
    if (isinf(value))
        return value > 0 ? @"+inf" : @"-inf";
    for (int precision = 1; precision <= 17; precision++) {
        NSString *candidate = [NSString stringWithFormat:@"%.*g", precision, value];
        if (candidate.doubleValue == value)
            return candidate;
    }
    return [NSString stringWithFormat:@"%.17g", value];
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return [self stringValue];
}

- (NSString *)description
{
    return [self stringValue];
}

- (NSComparisonResult)compare:(NSNumber *)other
{
    double mine = [self doubleValue];
    double theirs = [other doubleValue];
    if (mine < theirs) return NSOrderedAscending;
    if (mine > theirs) return NSOrderedDescending;
    return NSOrderedSame;
}

- (BOOL)isEqualToNumber:(NSNumber *)other
{
    return other != nil && [self doubleValue] == [other doubleValue];
}

- (BOOL)isEqual:(id)other
{
    if (self == other) {
        return YES;
    }
    if (![other isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    return [self isEqualToNumber:other];
}

- (NSUInteger)hash
{
    return [@([self doubleValue]) hash];
}

@end
