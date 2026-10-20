#import <Foundation/Foundation.h>
#import <math.h>
#import "RevenantMethodProem.h"

typedef struct {
    Class isa;
    uint64_t count;
    id const *objects;
} RevenantConstantArrayLayout;

typedef struct {
    Class isa;
    uint64_t reserved;
    uint64_t count;
    id const *keys;
    id const *objects;
} RevenantConstantDictionaryLayout;

typedef struct {
    Class isa;
    const char *objCType;
    int64_t value;
} RevenantConstantIntegerNumberLayout;

typedef struct {
    Class isa;
    const char *objCType;
    double value;
} RevenantConstantDoubleNumberLayout;

@interface NSConstantArray : NSArray
@end

@implementation NSConstantArray

- (NSUInteger)count
{
    return (NSUInteger)((const RevenantConstantArrayLayout *)(__bridge const void *)self)->count;
}

- (id)objectAtIndex:(NSUInteger)index
{
    const RevenantConstantArrayLayout *layout = (const RevenantConstantArrayLayout *)(__bridge const void *)self;
    if (index >= layout->count) {
        [NSException raise:NSRangeException format:@"%@: index %lu beyond bounds [0 .. %llu]",
                                                     revenant_method_proem(self, _cmd), (unsigned long)index,
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
    return (NSUInteger)((const RevenantConstantDictionaryLayout *)(__bridge const void *)self)->count;
}

- (id)objectForKey:(id)key
{
    const RevenantConstantDictionaryLayout *layout = (const RevenantConstantDictionaryLayout *)(__bridge const void *)self;
    for (uint64_t index = 0; index < layout->count; index++) {
        if ([layout->keys[index] isEqual:key]) {
            return layout->objects[index];
        }
    }
    return nil;
}

- (NSEnumerator *)keyEnumerator
{
    const RevenantConstantDictionaryLayout *layout = (const RevenantConstantDictionaryLayout *)(__bridge const void *)self;
    return [[NSArray arrayWithObjects:layout->keys count:(NSUInteger)layout->count] objectEnumerator];
}

@end

@interface NSConstantIntegerNumber : NSNumber
@end

@implementation NSConstantIntegerNumber

- (const RevenantConstantIntegerNumberLayout *)revenant_layout
{
    return (const RevenantConstantIntegerNumberLayout *)(__bridge const void *)self;
}

- (const char *)objCType
{
    return [self revenant_layout]->objCType;
}

- (void)getValue:(void *)buffer
{
    NSUInteger size = 0;
    NSGetSizeAndAlignment([self objCType], &size, NULL);
    memcpy(buffer, &[self revenant_layout]->value, size == 0 ? sizeof(int64_t) : MIN(size, sizeof(int64_t)));
}

- (char)charValue { return (char)[self revenant_layout]->value; }
- (unsigned char)unsignedCharValue { return (unsigned char)[self revenant_layout]->value; }
- (short)shortValue { return (short)[self revenant_layout]->value; }
- (unsigned short)unsignedShortValue { return (unsigned short)[self revenant_layout]->value; }
- (int)intValue { return (int)[self revenant_layout]->value; }
- (unsigned int)unsignedIntValue { return (unsigned int)[self revenant_layout]->value; }
- (long)longValue { return (long)[self revenant_layout]->value; }
- (unsigned long)unsignedLongValue { return (unsigned long)[self revenant_layout]->value; }
- (long long)longLongValue { return (long long)[self revenant_layout]->value; }
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)[self revenant_layout]->value; }
- (NSInteger)integerValue { return (NSInteger)[self revenant_layout]->value; }
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)[self revenant_layout]->value; }
- (float)floatValue { return (float)[self revenant_layout]->value; }
- (double)doubleValue { return (double)[self revenant_layout]->value; }
- (BOOL)boolValue { return [self revenant_layout]->value != 0; }

- (NSString *)stringValue
{
    return [NSString stringWithFormat:@"%lld", [self revenant_layout]->value];
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

- (const RevenantConstantDoubleNumberLayout *)revenant_layout
{
    return (const RevenantConstantDoubleNumberLayout *)(__bridge const void *)self;
}

- (const char *)objCType
{
    return [self revenant_layout]->objCType;
}

- (void)getValue:(void *)buffer
{
    double value = [self revenant_layout]->value;
    if (strcmp([self objCType], @encode(float)) == 0) {
        float narrowed = (float)value;
        memcpy(buffer, &narrowed, sizeof(narrowed));
        return;
    }
    NSUInteger size = 0;
    NSGetSizeAndAlignment([self objCType], &size, NULL);
    memcpy(buffer, &value, size == 0 ? sizeof(double) : MIN(size, sizeof(double)));
}

- (char)charValue { return (char)[self revenant_layout]->value; }
- (unsigned char)unsignedCharValue { return (unsigned char)[self revenant_layout]->value; }
- (short)shortValue { return (short)[self revenant_layout]->value; }
- (unsigned short)unsignedShortValue { return (unsigned short)[self revenant_layout]->value; }
- (int)intValue { return (int)[self revenant_layout]->value; }
- (unsigned int)unsignedIntValue { return (unsigned int)[self revenant_layout]->value; }
- (long)longValue { return (long)[self revenant_layout]->value; }
- (unsigned long)unsignedLongValue { return (unsigned long)[self revenant_layout]->value; }
- (long long)longLongValue { return (long long)[self revenant_layout]->value; }
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)[self revenant_layout]->value; }
- (NSInteger)integerValue { return (NSInteger)[self revenant_layout]->value; }
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)[self revenant_layout]->value; }
- (float)floatValue { return (float)[self revenant_layout]->value; }
- (double)doubleValue { return [self revenant_layout]->value; }
- (BOOL)boolValue { return [self revenant_layout]->value != 0; }

- (NSString *)stringValue
{
    double value = [self revenant_layout]->value;
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
