#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <uuid/uuid.h>

// The port under names of its own (CharonHostNSUUID, CharonHostConcreteUUID) against the host's NSUUID, on the same inputs.
@interface CharonHostNSUUID : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)UUID;
- (instancetype)initWithUUIDString:(NSString *)string;
- (instancetype)initWithUUIDBytes:(const uuid_t)bytes;
- (void)getUUIDBytes:(uuid_t)bytes;
@property (readonly, copy) NSString *UUIDString;
@end

static int failures;
static int checks;

static void expect(BOOL ok, NSString *what, NSString *detail)
{
    checks++;
    if (ok)
        return;
    failures++;
    printf("FAIL %s: %s\n", what.UTF8String, detail.UTF8String);
}

static void same(id ours, id theirs, NSString *what)
{
    expect(ours == theirs || [ours isEqual:theirs], what, [NSString stringWithFormat:@"ours %@, host %@", ours, theirs]);
}

static NSString *hex(const uuid_t bytes)
{
    NSMutableString *text = [NSMutableString string];
    for (int i = 0; i < 16; i++)
        [text appendFormat:@"%02X", bytes[i]];
    return text;
}

@interface Plain : CharonHostNSUUID
@end
@implementation Plain
@end

@interface Overriding : CharonHostNSUUID
@end
@implementation Overriding
- (void)getUUIDBytes:(uuid_t)bytes
{
    for (int i = 0; i < 16; i++)
        bytes[i] = (unsigned char)(i * 3 + 1);
}
@end

@interface HostPlain : NSUUID
@end
@implementation HostPlain
@end

@interface HostOverriding : NSUUID
@end
@implementation HostOverriding
- (void)getUUIDBytes:(uuid_t)bytes
{
    for (int i = 0; i < 16; i++)
        bytes[i] = (unsigned char)(i * 3 + 1);
}
@end

static NSData *archived(id object, BOOL xml)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    if (xml)
        archiver.outputFormat = NSPropertyListXMLFormat_v1_0;
    [archiver encodeObject:object forKey:@"root"];
    [archiver finishEncoding];
    return data;
}

static NSData *variant(NSData *original, id replacement)
{
    NSMutableDictionary *plist = [NSPropertyListSerialization propertyListWithData:original options:NSPropertyListMutableContainers format:NULL error:NULL];
    NSMutableDictionary *object = plist[@"$objects"][1];
    if (replacement)
        object[@"NS.uuidbytes"] = replacement;
    else
        [object removeObjectForKey:@"NS.uuidbytes"];
    return [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
}

// What decoding `data` answers: the class and string of the object, or the exception.
static NSString *decoded(NSData *data, Class named, BOOL secure)
{
    @try {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        if (named)
            [unarchiver setClass:named forClassName:@"NSUUID"];
        id back = secure ? [unarchiver decodeObjectOfClass:(named ?: [NSUUID class]) forKey:@"root"] : [unarchiver decodeObjectForKey:@"root"];
        return back ? [back UUIDString] : @"nil";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"exception %@: %@", exception.name, exception.reason];
    }
}

int main(void)
{
    @autoreleasepool {
        Class ours = [CharonHostNSUUID class];
        Class theirs = [NSUUID class];
        expect(ours != theirs, @"the classes are two", @"one class");
        const uuid_t known = {0x12,0x3E,0x45,0x67,0xE8,0x9B,0x12,0xD3,0xA4,0x56,0x42,0x66,0x14,0x17,0x40,0x00};
        const uuid_t zero = {0};
        const uuid_t ff = {255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255};
        const uuid_t inc = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
        const uuid_t edge1 = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1};
        const uuid_t edge2 = {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

        // parsing: the same strings, the same answers
        NSArray *strings = @[@"123E4567-E89B-12D3-A456-426614174000", @"123e4567-e89b-12d3-a456-426614174000", @"", @"123E4567E89B12D3A456426614174000",
                             @"{123E4567-E89B-12D3-A456-426614174000}", @"123E4567-E89B-12D3-A456-42661417400", @"123E4567-E89B-12D3-A456-4266141740000",
                             @" 123E4567-E89B-12D3-A456-426614174000", @"123E4567-E89B-12D3-A456-426614174000 ", @"123E4567-E89B-12D3-A456-426614174000\n",
                             @"123E4567-E89B-12D3-A456-42661417400G", @"123E4567-E89B-12D3-A456_426614174000", @"00000000-0000-0000-0000-000000000000",
                             @"FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", @"urn:uuid:123E4567-E89B-12D3-A456-426614174000",
                             @"123E4567-E89B-12D3-A456-426614174000\0extra", @"é", @"123E4567-E89B-12D3-A456-42661417400é", @"-123E4567-E89B-12D3-A456-42661417400",
                             @"123E4567-E89B-12D3-A456-426614174000-", @"0x3E4567-E89B-12D3-A456-426614174000", @"123E4567-E89B-12D3-A456-4266141740+0"];
        int index = 0;
        for (NSString *string in strings) {
            id o = [[ours alloc] initWithUUIDString:string], t = [[theirs alloc] initWithUUIDString:string];
            NSString *what = [NSString stringWithFormat:@"parse case %d", index++];
            same(o ? [o UUIDString] : @"nil", t ? [t UUIDString] : @"nil", what);
            if (o && t) {
                uuid_t a, b;
                [o getUUIDBytes:a];
                [t getUUIDBytes:b];
                expect(memcmp(a, b, 16) == 0, [what stringByAppendingString:@" bytes"], hex(a));
            }
        }
        same([[ours alloc] initWithUUIDString:(NSString *_Nonnull)nil] ? @"object" : @"nil", [[theirs alloc] initWithUUIDString:(NSString *_Nonnull)nil] ? @"object" : @"nil", @"a nil string");

        // bytes, string, and the zero pointer
        const uuid_t *samples[] = {&known, &zero, &ff, &inc, &edge1, &edge2};
        NSMutableArray *ourObjects = [NSMutableArray array], *theirObjects = [NSMutableArray array];
        for (int i = 0; i < 6; i++) {
            id o = [[ours alloc] initWithUUIDBytes:*samples[i]], t = [[theirs alloc] initWithUUIDBytes:*samples[i]];
            [ourObjects addObject:o];
            [theirObjects addObject:t];
            NSString *what = [NSString stringWithFormat:@"sample %d", i];
            same([o UUIDString], [t UUIDString], [what stringByAppendingString:@" string"]);
            same([o description], [t description], [what stringByAppendingString:@" description"]);
            same(@([o hash]), @([t hash]), [what stringByAppendingString:@" hash"]);
            same(@([o hash]), @([[NSData dataWithBytes:*samples[i] length:16] hash]), [what stringByAppendingString:@" hash is NSData's"]);
            uuid_t back;
            [o getUUIDBytes:back];
            expect(memcmp(back, *samples[i], 16) == 0, [what stringByAppendingString:@" bytes back"], hex(back));
            expect([o copy] == o && [o copyWithZone:nil] == o, [what stringByAppendingString:@" copy is self"], @"");
            expect([[o class] superclass] == ours, [what stringByAppendingString:@" the concrete class's superclass is NSUUID"], NSStringFromClass([[o class] superclass]));
        }
        same([[[ours alloc] initWithUUIDBytes:NULL] UUIDString], [[[theirs alloc] initWithUUIDBytes:NULL] UUIDString], @"NULL bytes");

        // equality: every pair, in both directions, across the two classes
        for (int i = 0; i < 6; i++) {
            for (int j = 0; j < 6; j++) {
                NSString *what = [NSString stringWithFormat:@"isEqual %d %d", i, j];
                same(@([ourObjects[i] isEqual:ourObjects[j]]), @([theirObjects[i] isEqual:theirObjects[j]]), what);
            }
            same(@([ourObjects[i] isEqual:nil]), @([theirObjects[i] isEqual:nil]), @"isEqual: nil");
            same(@([ourObjects[i] isEqual:[ourObjects[i] UUIDString]]), @([theirObjects[i] isEqual:[theirObjects[i] UUIDString]]), @"isEqual: its string");
            same(@([ourObjects[i] isEqual:[NSData dataWithBytes:*samples[i] length:16]]), @NO, @"isEqual: its data");
        }

        // random UUIDs: version 4, variant 2, not equal to each other, a hash that is NSData's
        NSMutableSet *seen = [NSMutableSet set];
        int hashMismatches = 0, versions = 0, variants = 0;
        for (int i = 0; i < 2000; i++) {
            id o = i % 2 ? [ours UUID] : [[ours alloc] init];
            uuid_t bytes;
            [o getUUIDBytes:bytes];
            [seen addObject:[o UUIDString]];
            if ((bytes[6] >> 4) != 4)
                versions++;
            if ((bytes[8] >> 6) != 2)
                variants++;
            if ([o hash] != [[NSData dataWithBytes:bytes length:16] hash])
                hashMismatches++;
        }
        same(@(seen.count), @2000, @"2000 random UUIDs are distinct");
        same(@(versions), @0, @"random UUIDs of version 4");
        same(@(variants), @0, @"random UUIDs of variant 2");
        same(@(hashMismatches), @0, @"hash of 2000 random UUIDs is NSData's");
        same(@([[[ours UUID] UUIDString] length]), @36, @"a random UUID's string length");

        // the class cluster
        same(NSStringFromClass([[ours alloc] class]), @"CharonHostConcreteUUID", @"alloc gives the concrete class");
        same(NSStringFromClass([NSUUID alloc].class), NSStringFromClass([[theirs alloc] class]), @"the host's alloc is a concrete class too");
        same(@([ours supportsSecureCoding]), @([theirs supportsSecureCoding]), @"supportsSecureCoding");
        same(@([ours conformsToProtocol:@protocol(NSCopying)]), @YES, @"NSCopying");
        same(@([ours conformsToProtocol:@protocol(NSSecureCoding)]), @YES, @"NSSecureCoding");
        same(@([[ours UUID] isKindOfClass:ours]), @YES, @"an instance is a kind of the class");
        id plainOurs = [[Plain alloc] init], plainTheirs = [[HostPlain alloc] init];
        same(NSStringFromClass([plainOurs class]), @"Plain", @"a subclass keeps its class through init");
        expect([[Plain UUID] class] == [Plain class] && [[HostPlain UUID] class] == [HostPlain class], @"a subclass's +UUID", NSStringFromClass([[Plain UUID] class]));
        same([[[Plain alloc] initWithUUIDBytes:known] description] ?: @"nil", [[[HostPlain alloc] initWithUUIDBytes:known] description] ?: @"nil", @"a subclass's initWithUUIDBytes:");
        same([[[Plain alloc] initWithUUIDString:strings[0]] description] ?: @"nil", [[[HostPlain alloc] initWithUUIDString:strings[0]] description] ?: @"nil", @"a subclass's initWithUUIDString:");
        uuid_t p, q;
        memset(p, 0xAB, 16);
        memset(q, 0xAB, 16);
        [plainOurs getUUIDBytes:p];
        [plainTheirs getUUIDBytes:q];
        same(hex(p), hex(q), @"a subclass's getUUIDBytes: writes zero");
        same([plainOurs UUIDString], [plainTheirs UUIDString], @"a subclass's UUIDString");
        same(@([plainOurs hash]), @([plainTheirs hash]), @"a subclass's hash");
        same(@([plainOurs isEqual:[[Plain alloc] init]]), @([plainTheirs isEqual:[[HostPlain alloc] init]]), @"two subclass instances");
        same([plainOurs copy] ?: @"nil", [plainTheirs copy] ?: @"nil", @"a subclass's copy");
        id overOurs = [[Overriding alloc] init], overTheirs = [[HostOverriding alloc] init];
        same([overOurs UUIDString], [overTheirs UUIDString], @"an overriding subclass's UUIDString");
        same(@([overOurs hash]), @([overTheirs hash]), @"an overriding subclass's hash");
        same(@([overOurs isEqual:overOurs]), @([overTheirs isEqual:overTheirs]), @"an overriding subclass equal to itself");
        uuid_t w = {1,4,7,10,13,16,19,22,25,28,31,34,37,40,43,46};
        same(@([overOurs isEqual:[[ours alloc] initWithUUIDBytes:w]]), @([overTheirs isEqual:[[theirs alloc] initWithUUIDBytes:w]]), @"an overriding subclass equal to a concrete one");
        same(@([[[ours alloc] initWithUUIDBytes:w] isEqual:overOurs]), @([[[theirs alloc] initWithUUIDBytes:w] isEqual:overTheirs]), @"a concrete one equal to an overriding subclass");
        same(@([overOurs copy] == overOurs), @([overTheirs copy] == overTheirs), @"an overriding subclass's copy");
        same([overOurs description] ? @YES : @NO, @YES, @"an overriding subclass has a description");

        // archives: what each writes, what each reads
        id oKnown = ourObjects[0], tKnown = theirObjects[0];
        NSString *ourXML = [[NSString alloc] initWithData:archived(oKnown, YES) encoding:NSUTF8StringEncoding];
        NSString *theirXML = [[NSString alloc] initWithData:archived(tKnown, YES) encoding:NSUTF8StringEncoding];
        same([ourXML stringByReplacingOccurrencesOfString:@"CharonHostNSUUID" withString:@"NSUUID"], theirXML, @"the archive of a UUID, class names aside");
        NSData *hostArchive = archived(tKnown, NO);
        same(decoded(hostArchive, ours, NO), decoded(hostArchive, nil, NO), @"decoding the host's archive");
        same(decoded(hostArchive, ours, YES), decoded(hostArchive, nil, YES), @"decoding the host's archive securely");
        NSData *ourArchive = [[NSData alloc] initWithBase64EncodedString:[archived(oKnown, NO) base64EncodedStringWithOptions:0] options:0];
        same(decoded(ourArchive, ours, NO), [tKnown UUIDString], @"decoding the port's archive with the port");
        NSMutableDictionary *renamed = [NSPropertyListSerialization propertyListWithData:archived(oKnown, NO) options:NSPropertyListMutableContainers format:NULL error:NULL];
        renamed[@"$objects"][2][@"$classname"] = @"NSUUID";
        renamed[@"$objects"][2][@"$classes"] = @[@"NSUUID", @"NSObject"];
        NSData *renamedArchive = [NSPropertyListSerialization dataWithPropertyList:renamed format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        same(decoded(renamedArchive, nil, NO), [tKnown UUIDString], @"the port's archive under the class name NSUUID, decoded by the host");
        NSArray *damages = @[@[@"missing key", [NSNull null]], @[@"15 bytes", [NSData dataWithBytes:known length:15]], @[@"17 bytes", [NSData dataWithBytes:known length:17]],
                             @[@"no bytes", [NSData data]], @[@"a string", @"123E4567-E89B-12D3-A456-426614174000"]];
        for (NSArray *damage in damages) {
            id replacement = damage[1] == [NSNull null] ? nil : damage[1];
            NSData *broken = variant(hostArchive, replacement);
            same(decoded(broken, ours, NO), decoded(broken, nil, NO), [@"a damaged archive: " stringByAppendingString:damage[0]]);
            same(decoded(broken, ours, YES), decoded(broken, nil, YES), [@"a damaged archive, secure: " stringByAppendingString:damage[0]]);
        }
        NSData *subclassArchive = archived(overTheirs, NO);
        same(subclassArchive.length > 0 ? @YES : @NO, @YES, @"the host archives a subclass");
        same([[NSString alloc] initWithData:archived(overOurs, YES) encoding:NSUTF8StringEncoding].length > 0 ? @YES : @NO, @YES, @"the port archives a subclass");
    }
    printf("%d checks, %d failed\n", checks, failures);
    return failures ? 1 : 0;
}
