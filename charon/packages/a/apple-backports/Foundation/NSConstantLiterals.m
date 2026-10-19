#import <Foundation/Foundation.h>
#import <math.h>
#import "CharonMethodProem.h"

// The compiler folds a literal array, dictionary or boxed number that is itself made of
// compile-time constants into a static instance in the binary's own __DATA_CONST, rather than
// building it at runtime. The instance's isa is bound to a class by name, and its remaining bytes
// are the fields below, exactly as clang lays them out for three of the four classes here -
// measured by reading the __objc_intobj, __objc_arrayobj and __objc_dictobj sections of a real
// shipped binary (UTM.app, arm64) that imports NSConstantArray, NSConstantDictionary and
// NSConstantIntegerNumber as strong symbols: each field's chained-fixup rebase target was followed
// to its real destination (a type-encoding C string, an inline pointer pool) to confirm what it
// holds, not assumed from the class's public behaviour. The fourth, NSConstantDoubleNumber, is
// reasoned by analogy to the measured integer layout rather than independently read - see the
// comment at its own layout struct below. iOS 6 never emits such instances itself; carrying the
// class is what lets it host the ones an application already brings.

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

// NSConstantDoubleNumber's layout is reasoned by analogy to NSConstantIntegerNumber's measured
// one above, not independently read off a binary: no shipped binary importing this class as a
// strong symbol was available to this band to disassemble. The analogy is narrow - it is the same
// clang codegen path (a boxed literal, @(expr), that clang can fold at compile time because expr
// is itself constant), emitting the same isa-bound __DATA_CONST instance, with the same
// objCType-then-value shape; only the trailing field's width and encoding character change, from
// the integer class's int64_t/"i" or "q" to this class's double/"d" or "f". Confirming the exact
// byte offsets against a real binary is future work for whichever band next holds one that imports
// this class strongly; see facts/Foundation/NSConstantLiterals.md.
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
    // The shortest decimal that reads back to the same double, matching what a real NSNumber's
    // description promises (a round-tripping value) without reproducing CFNumber's own formatter
    // byte for byte - not held against a host oracle, since no UIKit/Foundation host test exercises
    // this class (it takes a compile-time-constant literal a host-side test cannot construct the
    // same way a real binary's isa-bound instance does).
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
