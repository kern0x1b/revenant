// json1.m - NSJSONSerialization on the release it runs on, through the name an application writes. A command-line program: build it as
// a daemon target that requires charon@apple-backports and run it with `xmake emulate -r 4.3|5.0|6.0 run /usr/libexec/json1`
// (below6/run.sh does both). Below iOS 5.0 the class is the backports' (libFoundationBackports.dylib), from 5.0 the release's, and the
// program is held to the same answers on both.
//
// This is a call test, not a differential: it calls every method of the class from the 26.2 header, including the two stream methods
// of 7.0, and holds to the answers that hold on every release this port carries - a round trip, the validity a write agrees with, an
// error where the text is not JSON, the bytes a stream read back. It emits no `answer` lines on purpose: the wording and the positions of
// a parse failure, and the order of an unsorted dictionary's keys, differ between the release's own NSJSONSerialization and the
// backports' (facts/Foundation/NSJSONSerialization.md), and those are measured against the host by tests/backports/host/json1 rather
// than across releases, which have no common answer to compare.
//
// What the release's own class of 5.0 and later does not have at all - the two options of 15.0 and the two stream methods of 7.0 - is
// checked only where the class is the backports', which the program says out loud and the runner can see: on a release that carries
// its own class these are called and answered, but the checks that need the newer behaviour are marked as not applicable rather than
// failed.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <string.h>
#import "check.h"

// The reading options of 15.0 by their value: the port's headers of the release name none of them (the names sit behind an
// availability the generator's rule (tools/gen/target_availability.lua) lowers), so a program that wants them passes the
// numbers, as an application built for a newer SDK does.
static const NSJSONReadingOptions kMutableContainers = 1UL << 0;
static const NSJSONReadingOptions kMutableLeaves = 1UL << 1;
static const NSJSONReadingOptions kFragments = 1UL << 2;
static const NSJSONReadingOptions kJSON5 = 1UL << 3;
static const NSJSONReadingOptions kTopLevelDictionaryAssumed = 1UL << 4;

static const NSJSONWritingOptions kPrettyPrinted = 1UL << 0;
static const NSJSONWritingOptions kSortedKeys = 1UL << 1;
static const NSJSONWritingOptions kWriteFragments = 1UL << 2;
static const NSJSONWritingOptions kWithoutEscapingSlashes = 1UL << 3;

static NSData *utf8(NSString *text) { return [text dataUsingEncoding:NSUTF8StringEncoding]; }

static NSString *text_of(NSData *data)
{
    return data ? [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] description] : nil;
}

int main(void)
{
    @autoreleasepool {
        Class self_class = NSClassFromString(@"NSJSONSerialization");
        const char *image = class_getImageName(self_class);
        BOOL ported = image && strstr(image, "FoundationBackports") != NULL;
        printf("NSJSONSerialization comes from %s (%s)\n", image ?: "no image", ported ? "the backports" : "the release");
        CHECK(self_class != Nil, "NSJSONSerialization is a class");
        if (!self_class)
            return 1;

        NSDictionary *object = @{@"a": @1, @"b": @[@"x", @YES, [NSNull null]], @"c": @{@"d": @2.5}};
        NSDictionary *one = @{@"a": @1};
        NSDictionary *nonStringKey = [NSDictionary dictionaryWithObject:@1 forKey:@2];
        NSArray *notANumber = @[@(INFINITY)];

        // +isValidJSONObject:
        CHECK([NSJSONSerialization isValidJSONObject:object], "a dictionary is a JSON object");
        NSArray *arrayOfValues = @[@1, @"x"];
        CHECK([NSJSONSerialization isValidJSONObject:arrayOfValues], "an array of JSON values is one");
        CHECK(![NSJSONSerialization isValidJSONObject:@"a string"], "a string at the top is not");
        CHECK(![NSJSONSerialization isValidJSONObject:@1], "a number at the top is not");
        CHECK(![NSJSONSerialization isValidJSONObject:nonStringKey], "a non-string key is not");
        CHECK(![NSJSONSerialization isValidJSONObject:notANumber], "an infinity is not");

        // +dataWithJSONObject:options:error:
        NSError *error = nil;
        NSData *compact = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
        CHECK(compact != nil && error == nil, "a dictionary writes");
        // One key, so the text does not depend on the order an unsorted dictionary is written in.
        NSData *oneData = [NSJSONSerialization dataWithJSONObject:one options:0 error:NULL];
        CHECK_EQUAL(text_of(oneData), @"{\"a\":1}", "the compact text of a one-key dictionary");
        // More than one key: the order is the dictionary's own, so the text is held to what it reads back as.
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:compact options:0 error:NULL], object, "the compact text reads back");
        NSData *arrayData = [NSJSONSerialization dataWithJSONObject:(@[@1, @2]) options:0 error:NULL];
        CHECK(arrayData != nil, "an array writes");

        NSData *pretty = [NSJSONSerialization dataWithJSONObject:one options:kPrettyPrinted error:&error];
        CHECK(pretty != nil && error == nil, "a dictionary writes pretty printed");
        NSString *prettyText = [[NSString alloc] initWithData:pretty encoding:NSUTF8StringEncoding];
        CHECK([prettyText rangeOfString:@"\n  \"a\" : 1\n"].location != NSNotFound, "the pretty text is indented");
        NSData *prettyEmpty = [NSJSONSerialization dataWithJSONObject:[NSArray array] options:kPrettyPrinted error:NULL];
        NSString *prettyEmptyText = [[NSString alloc] initWithData:prettyEmpty encoding:NSUTF8StringEncoding];
        CHECK(ported ? [prettyEmptyText isEqualToString:@"[\n\n]"] : [prettyEmptyText hasPrefix:@"["],
              ported ? "a pretty printed empty array is a bracket, a newline and a bracket" : "a pretty printed empty array is written");
        NSData *slashes = [NSJSONSerialization dataWithJSONObject:@{@"u": @"a/b"} options:kWithoutEscapingSlashes error:&error];
        NSData *escapedSlash = [NSJSONSerialization dataWithJSONObject:@{@"u": @"a/b"} options:0 error:NULL];
        // The option is a bit of iOS 13 the release's own class has never heard of, so there the slash is escaped
        // either way; what the backports do with it is checked where they are the class that reads it.
        CHECK(ported ? [text_of(slashes) isEqualToString:@"{\"u\":\"a/b\"}"]
                     : [text_of(slashes) rangeOfString:@"\\/"].location != NSNotFound,
              ported ? "a slash is not escaped under its own option" : "the release escapes a slash with or without its option");
        CHECK([text_of(escapedSlash) rangeOfString:@"\\/"].location != NSNotFound, "a slash is escaped without it");
        NSData *decimal = [NSJSONSerialization dataWithJSONObject:[NSDecimalNumber decimalNumberWithString:@"1.5"] options:kWriteFragments error:NULL];
        CHECK([text_of(decimal) isEqualToString:@"1.5"], "a decimal at the top writes under the fragment option");
        NSData *oneTenth = [NSJSONSerialization dataWithJSONObject:@(0.1) options:kWriteFragments error:NULL];
        CHECK([[NSJSONSerialization JSONObjectWithData:oneTenth options:kFragments error:NULL] doubleValue] == 0.1,
              "a double survives a write and a read");

        // the exceptions a write raises
        @try {
            [NSJSONSerialization dataWithJSONObject:@"a string" options:0 error:NULL];
            CHECK(NO, "a string at the top raises");
        } @catch (NSException *exception) {
            CHECK([exception.name isEqualToString:NSInvalidArgumentException], "a string at the top raises NSInvalidArgumentException");
        }
        @try {
            [NSJSONSerialization dataWithJSONObject:nonStringKey options:0 error:NULL];
            CHECK(NO, "a non-string key raises");
        } @catch (NSException *exception) {
            CHECK([[exception.reason description] rangeOfString:@"non-string"].location != NSNotFound, "a non-string key says so");
        }
        @try {
            [NSJSONSerialization dataWithJSONObject:notANumber options:0 error:NULL];
            CHECK(NO, "an infinity raises");
        } @catch (NSException *exception) {
            CHECK([[exception.reason description] rangeOfString:@"number value"].location != NSNotFound, "an infinity says so");
        }
        // A decimal that is not a number is refused the same way and with its own wording, which is not the double
        // path's: the host says "NaN number in JSON write" where an infinity says "Invalid number value ...".
        NSDecimalNumber *notANumberDecimal = [NSDecimalNumber notANumber];
        CHECK(![NSJSONSerialization isValidJSONObject:@[notANumberDecimal]], "a decimal that is not a number is not valid");
        for (NSNumber *shape in @[@0, @1, @2, @3, @4]) {
            id object = nil;
            NSJSONWritingOptions options = 0;
            switch (shape.integerValue) {
                case 0: object = @[notANumberDecimal]; break;
                case 1: object = @{@"k": notANumberDecimal}; break;
                case 2: object = @[notANumberDecimal]; options = NSJSONWritingPrettyPrinted; break;
                case 3: object = notANumberDecimal; options = kWriteFragments; break;
                default: object = @[@[notANumberDecimal]]; break;
            }
            NSString *what = [NSString stringWithFormat:@"a decimal that is not a number raises in shape %@", shape];
            @try {
                [NSJSONSerialization dataWithJSONObject:object options:options error:NULL];
                CHECK(NO, [what UTF8String]);
            } @catch (NSException *exception) {
                CHECK([[exception.reason description] isEqualToString:@"NaN number in JSON write"], [what UTF8String]);
            }
        }

        // +JSONObjectWithData:options:error:
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:compact options:0 error:&error], object, "the round trip");
        CHECK(error == nil, "the round trip has no error");
        NSArray *spaced = @[@1, @2, @3];
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"  [1, 2 , 3]  ") options:0 error:NULL], spaced, "space is skipped");
        CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"[1,]") options:0 error:NULL] != nil, "a trailing comma in an array is read");
        CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"{\"a\":1,}") options:0 error:NULL] != nil, "a trailing comma in an object is read");
        id mutable = [NSJSONSerialization JSONObjectWithData:compact options:kMutableContainers error:NULL];
        CHECK([mutable isKindOfClass:[NSDictionary class]] && [mutable isKindOfClass:[NSMutableDictionary class]],
              "the mutable containers option gives a mutable dictionary");
        id leaves = [NSJSONSerialization JSONObjectWithData:utf8(@"{\"a\":\"b\"}") options:kMutableLeaves error:NULL];
        CHECK([leaves valueForKey:@"a"] != nil, "the mutable leaves option reads the leaf");
        id fragment = [NSJSONSerialization JSONObjectWithData:utf8(@"42") options:kFragments error:NULL];
        CHECK([fragment isEqual:@42], "a fragment is read under its own option");
        CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"42") options:0 error:NULL] == nil, "a fragment is refused without it");
        CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"{a:1}") options:0 error:NULL] == nil, "a bare key is refused without json5");
        if (ported) {
            CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"{a:1}") options:kJSON5 error:NULL] != nil, "a json5 bare key is read");
            CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"[.5, 0x10, +1]") options:kJSON5 error:NULL] != nil,
                  "json5 reads a leading dot, a hex and a leading plus");
            CHECK([[NSJSONSerialization JSONObjectWithData:utf8(@"a=1") options:kTopLevelDictionaryAssumed error:NULL] count] == 0u,
                  "the top level dictionary option reads a body with a bare key in it");
            // The option is a bit the compiler writes into this very call, and the release's own class of 5.0 knows
            // nothing of it (registry/Foundation/ios11.json), so the order is the dictionary's own there.
            NSData *sorted = [NSJSONSerialization dataWithJSONObject:object options:kSortedKeys error:NULL];
            CHECK([[[NSString alloc] initWithData:sorted encoding:NSUTF8StringEncoding] hasPrefix:@"{\"a\":"],
                  "sorted keys put the first key of -localizedStandardCompare: first");
        } else {
            printf("skip json5, the top level dictionary option and sorted keys: the release's own class has none of them\n");
        }

        // the five encodings the header documents, and the marks
        NSString *wide_text = @"{\"k\":\"héllo\"}";
        NSArray *encodings = @[@(NSUTF8StringEncoding), @(NSUTF16LittleEndianStringEncoding), @(NSUTF16BigEndianStringEncoding),
                               @(NSUTF32LittleEndianStringEncoding), @(NSUTF32BigEndianStringEncoding)];
        NSDictionary *wide = @{@"k": @"héllo"};
        for (NSNumber *encoding in encodings) {
            NSData *plain = [wide_text dataUsingEncoding:(NSStringEncoding)encoding.unsignedIntegerValue];
            CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:plain options:0 error:NULL], wide, "a wide encoding is read");
        }

        // a key an object already carries is read once, and the value it already holds is the one that stays
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"{\"a\":1,\"a\":2}") options:0 error:NULL], @{@"a": @1},
                    "a repeated key keeps the first value");
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"{\"a\":1,\"a\":2,\"a\":3}") options:0 error:NULL], @{@"a": @1},
                    "and the first of three");
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"{\"b\":0,\"a\":1,\"b\":2}") options:0 error:NULL],
                    (@{@"a": @1, @"b": @0}), "and a first value that is zero is kept over a later one");
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"{\"a\":{\"b\":1,\"b\":2}}") options:0 error:NULL],
                    (@{@"a": @{@"b": @1}}), "and a nested one");
        // the exponent field is a field: three digits under any sign, four without one, five never
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"[1e0001]") options:kFragments error:NULL], @[@10],
                    "a four digit exponent without a sign is read");
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"[1e0100]") options:kFragments error:NULL], @[@1e100],
                    "and carries its value");
        CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"[1e00000]") options:kFragments error:NULL] == nil,
              "a five digit exponent is refused however small its value");
        CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"[1e-0001]") options:kFragments error:NULL] == nil,
              "a four digit exponent with a sign is refused");
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"[1e-1]") options:kFragments error:NULL], @[@0.1],
                    "a one digit exponent with a sign is read");
        // a JSON5 container whose only content is a comment is the empty container
        for (NSNumber *shape in @[@"[/*c*/]", @"{/*c*/}", @"[/****/]", @"[/*a*//*b*/]"]) {
            NSString *what = [NSString stringWithFormat:@"a JSON5 container holding only a comment is empty: %@", shape];
            CHECK([NSJSONSerialization JSONObjectWithData:utf8([shape description]) options:kJSON5 error:NULL] != nil,
                  [what UTF8String]);
        }
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithData:utf8(@"[//c\n]") options:kJSON5 error:NULL], @[],
                    "and with a line comment");
        CHECK([NSJSONSerialization JSONObjectWithData:utf8(@"[/*c*/]") options:0 error:NULL] == nil,
              "and only under the JSON5 option");

        // the errors a read gives
        NSArray *refused = @[@"", @"nul", @"[1 2]", @"{\"a\"}", @"{\"a\":1", @"[01]"];
        for (NSString *bad in refused) {
            NSError *why = nil;
            CHECK([NSJSONSerialization JSONObjectWithData:utf8(bad) options:0 error:&why] == nil && why != nil,
                  "a text that is not JSON is refused");
        }
        {
            NSError *why = nil;
            [NSJSONSerialization JSONObjectWithData:utf8(@"nul") options:0 error:&why];
            CHECK([why.domain isEqualToString:NSCocoaErrorDomain] && why.code == NSPropertyListReadCorruptError,
                  "the refusal is a property list corruption of the cocoa domain");
            CHECK(why.userInfo[NSDebugDescriptionErrorKey] != nil, "the refusal says what was wrong");
        }

        // +writeJSONObject:toStream:options:error: and +JSONObjectWithStream:options:error: (7.0)
        NSString *path = @"/tmp/charon-json1.json";
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        NSOutputStream *out = [NSOutputStream outputStreamToFileAtPath:path append:NO];
        [out open];
        NSError *writeError = nil;
        NSInteger written = [NSJSONSerialization writeJSONObject:object toStream:out options:0 error:&writeError];
        [out close];
        CHECK(written == (NSInteger)compact.length && writeError == nil, "a dictionary writes to a stream");
        NSString *onDisk = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        CHECK_EQUAL(onDisk, text_of(compact), "the stream holds what the data method wrote");
        NSInputStream *in = [NSInputStream inputStreamWithFileAtPath:path];
        [in open];
        NSError *readError = nil;
        CHECK_EQUAL([NSJSONSerialization JSONObjectWithStream:in options:0 error:&readError], object, "a stream reads back");
        [in close];
        CHECK(readError == nil, "reading the stream has no error");
        NSInputStream *missing = [NSInputStream inputStreamWithFileAtPath:@"/tmp/charon-json1-absent.json"];
        [missing open];
        NSError *missingError = nil;
        CHECK([NSJSONSerialization JSONObjectWithStream:missing options:0 error:&missingError] == nil, "a stream of nothing is refused");
        [missing close];
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
