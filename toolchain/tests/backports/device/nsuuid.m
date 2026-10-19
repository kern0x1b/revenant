#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <uuid/uuid.h>
#import "check.h"

@interface Plain : NSUUID
@end
@implementation Plain
@end

@interface Overriding : NSUUID
@end
@implementation Overriding
- (void)getUUIDBytes:(uuid_t)bytes
{
    for (int i = 0; i < 16; i++)
        bytes[i] = (unsigned char)(i * 3 + 1);
}
@end

static void answer(NSString *key, id value)
{
    printf("answer %s %s\n", key.UTF8String, [[value description] UTF8String]);
    fflush(stdout);
}

static NSData *archived(id object)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver encodeObject:object forKey:@"root"];
    [archiver finishEncoding];
    return data;
}

static NSData *variant(NSData *original, id replacement)
{
    NSMutableDictionary *plist = [NSPropertyListSerialization propertyListFromData:original mutabilityOption:NSPropertyListMutableContainers format:NULL errorDescription:NULL];
    NSMutableDictionary *object = [[plist objectForKey:@"$objects"] objectAtIndex:1];
    if (replacement)
        [object setObject:replacement forKey:@"NS.uuidbytes"];
    else
        [object removeObjectForKey:@"NS.uuidbytes"];
    return [NSPropertyListSerialization dataFromPropertyList:plist format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
}

static NSString *decoded(NSData *data)
{
    @try {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        id back = [unarchiver decodeObjectForKey:@"root"];
        return back ? [NSString stringWithFormat:@"%@ %@", NSStringFromClass([back class]), [back UUIDString]] : @"nil";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"exception %@", exception.name];
    }
}

int main(void)
{
    @autoreleasepool {
        Class C = NSClassFromString(@"NSUUID");
        BOOL ported = NO;
        CHECK(C != Nil, "NSUUID is a class");
        if (!C)
            return 1;
        const char *image = class_getImageName(C);
        ported = image && strstr(image, "FoundationBackports") != NULL;
        printf("NSUUID comes from %s (%s)\n", image ?: "no image", ported ? "the backports" : "the release");
        answer(@"class", NSStringFromClass(C));
        answer(@"superclass", NSStringFromClass([C superclass]));
        answer(@"secure coding", @([C supportsSecureCoding]));
        answer(@"copying", @([C conformsToProtocol:@protocol(NSCopying)]));
        answer(@"secure protocol", @([C conformsToProtocol:@protocol(NSSecureCoding)]));

        const uuid_t known = {0x12,0x3E,0x45,0x67,0xE8,0x9B,0x12,0xD3,0xA4,0x56,0x42,0x66,0x14,0x17,0x40,0x00};
        const uuid_t zero = {0};
        const uuid_t ff = {255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255};
        const uuid_t inc = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
        NSUUID *a = [[NSUUID alloc] initWithUUIDBytes:known];
        CHECK_EQUAL(a.UUIDString, @"123E4567-E89B-12D3-A456-426614174000", "UUIDString is upper case");
        answer(@"instance class", NSStringFromClass([a class]));
        CHECK_EQUAL(NSStringFromClass([a class]), @"__NSConcreteUUID", "an instance is the concrete class");
        CHECK_EQUAL(NSStringFromClass([[a class] superclass]), @"NSUUID", "the concrete class's superclass");
        CHECK([[a description] hasSuffix:@"123E4567-E89B-12D3-A456-426614174000"], "the description ends with the string");
        if (ported)
            CHECK_EQUAL([a description], @"123E4567-E89B-12D3-A456-426614174000", "the port's description is the string");
        answer(@"description ends with", [[[a description] componentsSeparatedByString:@" "] lastObject]);

        const uuid_t *samples[] = {&known, &zero, &ff, &inc};
        const NSUInteger hashes[] = {211469392, 0, 1114095, 183413583};
        for (int i = 0; i < 4; i++) {
            NSUUID *u = [[NSUUID alloc] initWithUUIDBytes:*samples[i]];
            char name[64];
            snprintf(name, sizeof name, "hash of sample %d", i);
            CHECK_EQUAL(@([u hash]), @(hashes[i]), name);
            answer([NSString stringWithFormat:@"hash %d", i], @([u hash]));
        }
        int mismatches = 0, versions = 0, variants = 0;
        NSMutableSet *seen = [NSMutableSet set];
        for (int i = 0; i < 2000; i++) {
            uuid_t random;
            arc4random_buf(random, 16);
            NSUUID *u = [[NSUUID alloc] initWithUUIDBytes:random];
            if ([u hash] != [[NSData dataWithBytes:random length:16] hash])
                mismatches++;
            NSUUID *made = i % 2 ? [NSUUID UUID] : [[NSUUID alloc] init];
            uuid_t bytes;
            [made getUUIDBytes:bytes];
            [seen addObject:made.UUIDString];
            if ((bytes[6] >> 4) != 4)
                versions++;
            if ((bytes[8] >> 6) != 2)
                variants++;
        }
        CHECK(mismatches == 0, "the hash of 2000 random UUIDs is NSData's");
        CHECK([seen count] == 2000, "2000 new UUIDs are distinct");
        CHECK(versions == 0 && variants == 0, "new UUIDs are version 4, variant 2");

        NSString *upper = @"123E4567-E89B-12D3-A456-426614174000";
        NSArray *cases = @[
            @[@"123E4567-E89B-12D3-A456-426614174000", upper], @[@"123e4567-e89b-12d3-a456-426614174000", upper], @[@"", @"nil"],
            @[@"123E4567E89B12D3A456426614174000", @"nil"], @[@"{123E4567-E89B-12D3-A456-426614174000}", @"nil"],
            @[@"123E4567-E89B-12D3-A456-42661417400", @"nil"], @[@"123E4567-E89B-12D3-A456-4266141740000", @"nil"],
            @[@" 123E4567-E89B-12D3-A456-426614174000", @"nil"], @[@"123E4567-E89B-12D3-A456-426614174000 ", @"nil"],
            @[@"123E4567-E89B-12D3-A456-426614174000\n", @"nil"], @[@"123E4567-E89B-12D3-A456-42661417400G", @"nil"],
            @[@"123E4567-E89B-12D3-A456_426614174000", @"nil"], @[@"00000000-0000-0000-0000-000000000000", @"00000000-0000-0000-0000-000000000000"],
            @[@"FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", @"FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"], @[@"urn:uuid:123E4567-E89B-12D3-A456-426614174000", @"nil"],
            @[@"123E4567-E89B-12D3-A456-426614174000\0extra", upper], @[@"é", @"nil"]];
        int n = 0;
        for (NSArray *c in cases) {
            NSUUID *u = [[NSUUID alloc] initWithUUIDString:[c objectAtIndex:0]];
            char name[64];
            snprintf(name, sizeof name, "parse case %d", n++);
            CHECK_EQUAL(u ? u.UUIDString : @"nil", [c objectAtIndex:1], name);
        }

        NSUUID *b = [[NSUUID alloc] initWithUUIDBytes:known], *other = [[NSUUID alloc] initWithUUIDBytes:inc];
        CHECK([a isEqual:b] && [b isEqual:a] && [a isEqual:a], "equal bytes are equal");
        CHECK(![a isEqual:other] && ![a isEqual:nil] && ![a isEqual:a.UUIDString], "other bytes, nil and a string are not equal");
        CHECK([a copy] == a && [a copyWithZone:nil] == a, "copy is the receiver");
        CHECK(a.hash == b.hash, "equal UUIDs hash alike");
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        [d setObject:@"x" forKey:a];
        CHECK_EQUAL([d objectForKey:b], @"x", "a UUID is a dictionary key");
        NSSet *set = [NSSet setWithObjects:a, b, nil];
        CHECK([set count] == 1, "equal UUIDs are one in a set");
        uuid_t out;
        [a getUUIDBytes:out];
        CHECK(memcmp(out, known, 16) == 0, "getUUIDBytes: gives the bytes");
        CHECK_EQUAL([[[NSUUID alloc] initWithUUIDBytes:zero] UUIDString], @"00000000-0000-0000-0000-000000000000", "the zero UUID");
        CHECK_EQUAL([[NSUUID UUID] class], [a class], "+UUID and initWithUUIDBytes: make the same class");

        CHECK([a respondsToSelector:@selector(compare:)], "compare: is there");
        if ([a respondsToSelector:@selector(compare:)]) {
            NSComparisonResult (*compare)(id, SEL, id) = (NSComparisonResult (*)(id, SEL, id))[a methodForSelector:@selector(compare:)];
            CHECK(compare(a, @selector(compare:), b) == NSOrderedSame, "compare: equal");
            CHECK(compare([[NSUUID alloc] initWithUUIDBytes:zero], @selector(compare:), a) == NSOrderedAscending, "compare: smaller");
            CHECK(compare([[NSUUID alloc] initWithUUIDBytes:ff], @selector(compare:), a) == NSOrderedDescending, "compare: larger");
        }

        NSData *archive = archived(a);
        NSDictionary *plist = [NSPropertyListSerialization propertyListFromData:archive mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
        NSDictionary *object = [[plist objectForKey:@"$objects"] objectAtIndex:1];
        CHECK_EQUAL([object objectForKey:@"NS.uuidbytes"], [NSData dataWithBytes:known length:16], "the archive holds NS.uuidbytes");
        CHECK_EQUAL([[[plist objectForKey:@"$objects"] objectAtIndex:2] objectForKey:@"$classname"], @"NSUUID", "the archive names NSUUID");
        answer(@"archive keys", [[object allKeys] sortedArrayUsingSelector:@selector(compare:)]);
        CHECK_EQUAL(decoded(archive), @"__NSConcreteUUID 123E4567-E89B-12D3-A456-426614174000", "the archive decodes");
        CHECK_EQUAL(decoded(variant(archive, [NSData dataWithBytes:known length:16])), @"__NSConcreteUUID 123E4567-E89B-12D3-A456-426614174000", "a rewritten archive decodes");
        CHECK([decoded(variant(archive, @"123E4567-E89B-12D3-A456-426614174000")) hasPrefix:@"exception"], "a string under the bytes' key is refused");
        NSArray *damaged = @[[NSNull null], [NSData dataWithBytes:known length:15], [NSData dataWithBytes:known length:17], [NSData data]];
        for (id damage in damaged) {
            NSString *result = decoded(variant(archive, damage == [NSNull null] ? nil : damage));
            printf("damaged archive: %s\n", result.UTF8String);
            if (ported)
                CHECK([result hasPrefix:@"exception NSInvalidUnarchiveOperationException"], "a damaged archive is refused");
            else
                CHECK([result hasPrefix:@"__NSConcreteUUID "], "the release's own answer to a damaged archive is a UUID (measured on 6.0)");
        }

        id fromNil = [[NSUUID alloc] initWithUUIDString:(NSString *_Nonnull)nil];
        if (ported)
            CHECK(fromNil == nil, "a nil string gives nil");
        else
            printf("6.0's answer to a nil string: %s\n", fromNil ? [[fromNil description] UTF8String] : "nil");
        if (ported)
            CHECK_EQUAL([[[NSUUID alloc] initWithUUIDBytes:NULL] UUIDString], @"00000000-0000-0000-0000-000000000000", "no bytes give the zero UUID");

        Plain *plain = [[Plain alloc] init];
        CHECK_EQUAL(NSStringFromClass([plain class]), @"Plain", "a subclass keeps its class");
        CHECK([[Plain alloc] initWithUUIDBytes:known] == nil && [[Plain alloc] initWithUUIDString:upper] == nil, "a subclass is not given a UUID to hold");
        uuid_t filled;
        memset(filled, 0xAB, 16);
        [plain getUUIDBytes:filled];
        CHECK(memcmp(filled, zero, 16) == 0, "a subclass that overrides nothing has the zero bytes");
        CHECK_EQUAL(plain.UUIDString, @"", "and an empty string");
        CHECK([plain hash] == 0 && [plain copy] == nil, "and hash 0 and no copy");
        CHECK_EQUAL(NSStringFromClass([[Plain UUID] class]), @"Plain", "+UUID on a subclass");
        Overriding *over = [[Overriding alloc] init];
        uuid_t chosen = {1,4,7,10,13,16,19,22,25,28,31,34,37,40,43,46};
        NSUUID *chosenUUID = [[NSUUID alloc] initWithUUIDBytes:chosen];
        CHECK([over isEqual:chosenUUID] && [chosenUUID isEqual:over], "a subclass that answers getUUIDBytes: equals the concrete UUID of those bytes");
        CHECK([over hash] == [chosenUUID hash], "and has its hash");
        CHECK([over copy] == nil, "and no copy, as the base class answers");
    }
    printf("nsuuid: %d checks, %d failed\n", revenant_checks, revenant_failures);
    return revenant_failures;
}
