#import <Foundation/Foundation.h>
#import <CoreNFC/CoreNFC.h>
#import <objc/runtime.h>
#import "check.h"

// The port's NFCTagCommandConfiguration and its two ISO15693 subclasses, each built from the port's
// own source, against the host's CoreNFC.
//
// Unlike the NDEF differential beside this one there IS an oracle here: the tag-command
// configuration classes are not API_UNAVAILABLE(macOS) the way NFCNDEFMessage.h is, so the same three
// classes exist on the host and every value below is compared with what the host's own object
// answers. The prefix renames in run.sh give the port's classes CharonHost* names, so the port's
// classes and the host's coexist in one process and are asked the same questions in the same order.
//
// The two sets of classes are spelled differently on purpose. The -D renames reach this file and the port's sources alike, so
// `NFCTagCommandConfiguration` here IS the host's class, and the
// port's own class has to be reached by name: its interface is declared locally, with its real
// CharonHost name and the properties the port implements, and NSClassFromString hands back the class
// the port's object file registered under that name.

// What the port's classes answer. The declarations are the properties of the SDK 16.4 headers, typed
// so the checks read as the API does rather than as KVC paths.
@interface CharonHostNFCTagCommandConfiguration : NSObject <NSCopying>
@property (nonatomic, assign) NSUInteger maximumRetries;
@property (nonatomic, assign) NSTimeInterval retryInterval;
@end

@interface CharonHostNFCISO15693CustomCommandConfiguration : CharonHostNFCTagCommandConfiguration
@property (nonatomic, assign) NSUInteger manufacturerCode;
@property (nonatomic, assign) NSUInteger customCommandCode;
@property (nonatomic, copy) NSData *requestParameters;
- (instancetype)initWithManufacturerCode:(NSUInteger)manufacturerCode
                       customCommandCode:(NSUInteger)customCommandCode
                       requestParameters:(NSData *)requestParameters;
- (instancetype)initWithManufacturerCode:(NSUInteger)manufacturerCode
                       customCommandCode:(NSUInteger)customCommandCode
                       requestParameters:(NSData *)requestParameters
                          maximumRetries:(NSUInteger)maximumRetries
                           retryInterval:(NSTimeInterval)retryInterval;
@end

@interface CharonHostNFCISO15693ReadMultipleBlocksConfiguration : CharonHostNFCTagCommandConfiguration
@property (nonatomic, assign) NSRange range;
@property (nonatomic, assign) NSUInteger chunkSize;
- (instancetype)initWithRange:(NSRange)range
                    chunkSize:(NSUInteger)chunkSize;
- (instancetype)initWithRange:(NSRange)range
                    chunkSize:(NSUInteger)chunkSize
               maximumRetries:(NSUInteger)maximumRetries
                retryInterval:(NSTimeInterval)retryInterval;
@end

// The port's class must be the one its object file registered, not a name that resolves to nothing.
static Class port_class(Class declared, const char *name)
{
    NSString *spelling = [NSString stringWithUTF8String:name];
    Class found = NSClassFromString(spelling);
    charon_check(found == declared, [[NSString stringWithFormat:@"%@ is carried under its own name", spelling] UTF8String], nil);
    return found;
}

#define PORT_CLASS(c) port_class([c class], #c)

static void check_same(BOOL ours, BOOL theirs, NSString *what)
{
    charon_check(ours == theirs, [[NSString stringWithFormat:@"%@ answers what CoreNFC answers", what] UTF8String],
                 [NSString stringWithFormat:@"port %d, host %d", ours, theirs]);
}

static void check_same_u(NSUInteger ours, NSUInteger theirs, NSString *what)
{
    charon_check(ours == theirs, [[NSString stringWithFormat:@"%@ answers what CoreNFC answers", what] UTF8String],
                 [NSString stringWithFormat:@"port %lu, host %lu", (unsigned long)ours, (unsigned long)theirs]);
}

static void check_same_d(double ours, double theirs, NSString *what)
{
    charon_check(ours == theirs, [[NSString stringWithFormat:@"%@ answers what CoreNFC answers", what] UTF8String],
                 [NSString stringWithFormat:@"port %g, host %g", ours, theirs]);
}

static void check_same_range(NSRange ours, NSRange theirs, NSString *what)
{
    check_same_u(ours.location, theirs.location, [what stringByAppendingString:@".location"]);
    check_same_u(ours.length, theirs.length, [what stringByAppendingString:@".length"]);
}

static void check_same_obj(id ours, id theirs, NSString *what)
{
    charon_check(ours == theirs || [ours isEqual:theirs],
                 [[NSString stringWithFormat:@"%@ answers what CoreNFC answers", what] UTF8String],
                 [NSString stringWithFormat:@"port %@, host %@", ours, theirs]);
}

static NSData *text(const char *s)
{
    return [NSData dataWithBytes:s length:strlen(s)];
}

// ---------------------------------------------------------------- the base class

static void base_class(void)
{
    CharonHostNFCTagCommandConfiguration *ours = [[PORT_CLASS(CharonHostNFCTagCommandConfiguration) alloc] init];
    NFCTagCommandConfiguration *theirs = [[NFCTagCommandConfiguration alloc] init];

    check_same_u(ours.maximumRetries, theirs.maximumRetries, @"maximumRetries of a fresh configuration");
    check_same_d(ours.retryInterval, theirs.retryInterval, @"retryInterval of a fresh configuration");
    check_same_u(ours.maximumRetries, 0, @"maximumRetries of a fresh configuration");
    check_same_d(ours.retryInterval, 0, @"retryInterval of a fresh configuration");

    check_same([ours conformsToProtocol:@protocol(NSCopying)], [theirs conformsToProtocol:@protocol(NSCopying)],
               @"NSCopying conformance");
    check_same([ours respondsToSelector:@selector(copyWithZone:)], [theirs respondsToSelector:@selector(copyWithZone:)],
               @"-copyWithZone: is what answers");

    // The header calls 0 to 256 the valid range for retries and seconds the unit for the interval.
    // The host keeps the numbers it is given, out of range and all.
    ours.maximumRetries = 1000; theirs.maximumRetries = 1000;
    check_same_u(ours.maximumRetries, theirs.maximumRetries, @"maximumRetries above the header's range");
    check_same_u(ours.maximumRetries, 1000, @"maximumRetries above the header's range is kept as given");

    ours.retryInterval = -5; theirs.retryInterval = -5;
    check_same_d(ours.retryInterval, theirs.retryInterval, @"a negative retryInterval");

    ours.maximumRetries = 3; theirs.maximumRetries = 3;
    ours.retryInterval = 0.25; theirs.retryInterval = 0.25;
    CharonHostNFCTagCommandConfiguration *ourcopy = [ours copy];
    NFCTagCommandConfiguration *theircopy = [theirs copy];
    check_same([ourcopy class] == [ours class], [theircopy class] == [theirs class], @"a copy is of the same class");
    check_same_u(ourcopy.maximumRetries, theircopy.maximumRetries, @"maximumRetries of a copy");
    check_same_d(ourcopy.retryInterval, theircopy.retryInterval, @"retryInterval of a copy");

    // -isEqual: is NSObject's, on both sides: two configurations built from the same fields are not
    // equal, which is what stops a caller using one as a dictionary key for the other.
    CharonHostNFCTagCommandConfiguration *ours2 = [[PORT_CLASS(CharonHostNFCTagCommandConfiguration) alloc] init];
    NFCTagCommandConfiguration *theirs2 = [[NFCTagCommandConfiguration alloc] init];
    ours2.maximumRetries = 3; theirs2.maximumRetries = 3;
    ours2.retryInterval = 0.25; theirs2.retryInterval = 0.25;
    check_same([ours isEqual:ours2], [theirs isEqual:theirs2], @"isEqual: over two configurations of the same fields");
    check_same([ours isEqual:ours2], NO, @"isEqual: over two configurations of the same fields is NO");
}

// ------------------------------------------------- the manufacturer custom command

static void custom_command(void)
{
    CharonHostNFCISO15693CustomCommandConfiguration *ours =
        [[PORT_CLASS(CharonHostNFCISO15693CustomCommandConfiguration) alloc] init];
    NFCISO15693CustomCommandConfiguration *theirs = [[NFCISO15693CustomCommandConfiguration alloc] init];

    check_same_u(ours.manufacturerCode, theirs.manufacturerCode, @"manufacturerCode of a fresh configuration");
    check_same_u(ours.customCommandCode, theirs.customCommandCode, @"customCommandCode of a fresh configuration");
    check_same_obj(ours.requestParameters, theirs.requestParameters, @"requestParameters of a fresh configuration");
    check_same(ours.requestParameters == nil, theirs.requestParameters == nil,
               @"requestParameters of a fresh configuration");
    check_same(ours.requestParameters == nil, YES, @"requestParameters of a fresh configuration is nil");

    check_same([ours superclass] == PORT_CLASS(CharonHostNFCTagCommandConfiguration),
               [theirs superclass] == [NFCTagCommandConfiguration class], @"the base class of a custom command configuration");

    // The header calls 0x00-0xFF the valid manufacturer range and 0xA0-0xDF the valid command range.
    // The host keeps both numbers it was given.
    CharonHostNFCISO15693CustomCommandConfiguration *our_out =
        [[PORT_CLASS(CharonHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:0x1FF
                                                                                     customCommandCode:0x5
                                                                                     requestParameters:nil];
    NFCISO15693CustomCommandConfiguration *their_out =
        [[NFCISO15693CustomCommandConfiguration alloc] initWithManufacturerCode:0x1FF customCommandCode:0x5 requestParameters:nil];
    check_same_u(our_out.manufacturerCode, their_out.manufacturerCode, @"manufacturerCode above the header's range");
    check_same_u(our_out.customCommandCode, their_out.customCommandCode, @"customCommandCode below the header's range");
    check_same_u(our_out.manufacturerCode, 0x1FF, @"manufacturerCode above the header's range is kept as given");
    check_same_u(our_out.customCommandCode, 0x5, @"customCommandCode below the header's range is kept as given");

    ours.manufacturerCode = 0x12345; theirs.manufacturerCode = 0x12345;
    check_same_u(ours.manufacturerCode, theirs.manufacturerCode, @"manufacturerCode set far above the header's range");
    ours.customCommandCode = 0x3FF; theirs.customCommandCode = 0x3FF;
    check_same_u(ours.customCommandCode, theirs.customCommandCode, @"customCommandCode set above the header's range");

    // The three-field initialiser leaves the base's retry fields at zero, which the header says it does.
    NSData *params = text("hi");
    CharonHostNFCISO15693CustomCommandConfiguration *our_three =
        [[PORT_CLASS(CharonHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:0x04
                                                                                     customCommandCode:0xA0
                                                                                     requestParameters:params];
    NFCISO15693CustomCommandConfiguration *their_three =
        [[NFCISO15693CustomCommandConfiguration alloc] initWithManufacturerCode:0x04 customCommandCode:0xA0 requestParameters:params];
    check_same_u(our_three.manufacturerCode, their_three.manufacturerCode, @"manufacturerCode of the three-field initialiser");
    check_same_u(our_three.customCommandCode, their_three.customCommandCode, @"customCommandCode of the three-field initialiser");
    check_same_obj(our_three.requestParameters, their_three.requestParameters, @"requestParameters of the three-field initialiser");
    check_same_u(our_three.maximumRetries, their_three.maximumRetries, @"maximumRetries of the three-field initialiser");
    check_same_d(our_three.retryInterval, their_three.retryInterval, @"retryInterval of the three-field initialiser");
    check_same_u(our_three.maximumRetries, 0, @"the three-field initialiser leaves maximumRetries at zero");
    check_same_d(our_three.retryInterval, 0, @"the three-field initialiser leaves retryInterval at zero");

    // The five-field initialiser sets all five.
    CharonHostNFCISO15693CustomCommandConfiguration *our_five =
        [[PORT_CLASS(CharonHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:0x04
                                                                                     customCommandCode:0xA0
                                                                                     requestParameters:params
                                                                                        maximumRetries:5
                                                                                         retryInterval:1.5];
    NFCISO15693CustomCommandConfiguration *their_five =
        [[NFCISO15693CustomCommandConfiguration alloc] initWithManufacturerCode:0x04 customCommandCode:0xA0 requestParameters:params maximumRetries:5 retryInterval:1.5];
    check_same_u(our_five.manufacturerCode, their_five.manufacturerCode, @"manufacturerCode of the five-field initialiser");
    check_same_u(our_five.customCommandCode, their_five.customCommandCode, @"customCommandCode of the five-field initialiser");
    check_same_u(our_five.maximumRetries, their_five.maximumRetries, @"maximumRetries of the five-field initialiser");
    check_same_d(our_five.retryInterval, their_five.retryInterval, @"retryInterval of the five-field initialiser");
    check_same_u(our_five.maximumRetries, 5, @"maximumRetries of the five-field initialiser is what was asked");
    check_same_d(our_five.retryInterval, 1.5, @"retryInterval of the five-field initialiser is what was asked");

    // A copy carries all five, and its request data is its own.
    CharonHostNFCISO15693CustomCommandConfiguration *ourcopy = [our_five copy];
    NFCISO15693CustomCommandConfiguration *theircopy = [their_five copy];
    check_same([ourcopy class] == [our_five class], [theircopy class] == [their_five class], @"a copy of a custom command configuration is of the same class");
    check_same_u(ourcopy.manufacturerCode, theircopy.manufacturerCode, @"manufacturerCode of a copy");
    check_same_u(ourcopy.customCommandCode, theircopy.customCommandCode, @"customCommandCode of a copy");
    check_same_u(ourcopy.maximumRetries, theircopy.maximumRetries, @"maximumRetries of a copy");
    check_same_d(ourcopy.retryInterval, theircopy.retryInterval, @"retryInterval of a copy");
    check_same_obj(ourcopy.requestParameters, theircopy.requestParameters, @"requestParameters of a copy");

    ourcopy.requestParameters = text("other");
    theircopy.requestParameters = text("other");
    check_same_obj(our_five.requestParameters, their_five.requestParameters,
                   @"the original's requestParameters after the copy's were set");
    check_same_obj(our_five.requestParameters, their_five.requestParameters, @"the original is untouched by the copy");
    check_same_obj(ourcopy.requestParameters, theircopy.requestParameters, @"the copy carries the requestParameters it was set");

    CharonHostNFCISO15693CustomCommandConfiguration *ournil =
        [[PORT_CLASS(CharonHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:1 customCommandCode:2 requestParameters:nil];
    NFCISO15693CustomCommandConfiguration *theirnil =
        [[NFCISO15693CustomCommandConfiguration alloc] initWithManufacturerCode:1 customCommandCode:2 requestParameters:nil];
    CharonHostNFCISO15693CustomCommandConfiguration *ournilcopy = [ournil copy];
    NFCISO15693CustomCommandConfiguration *theirnilcopy = [theirnil copy];
    check_same(ournilcopy.requestParameters == nil, theirnilcopy.requestParameters == nil,
               @"nil requestParameters through a copy");
    check_same(ournilcopy.manufacturerCode, theirnilcopy.manufacturerCode, @"manufacturerCode through a copy of a nil-parameters configuration");
    check_same_u(ournilcopy.maximumRetries, theirnilcopy.maximumRetries, @"maximumRetries through a copy of a nil-parameters configuration");
}

// ------------------------------------------------------- read multiple blocks

static void read_multiple_blocks(void)
{
    CharonHostNFCISO15693ReadMultipleBlocksConfiguration *ours =
        [[PORT_CLASS(CharonHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] init];
    NFCISO15693ReadMultipleBlocksConfiguration *theirs = [[NFCISO15693ReadMultipleBlocksConfiguration alloc] init];

    check_same_u(ours.range.location, theirs.range.location, @"range.location of a fresh configuration");
    check_same_u(ours.range.length, theirs.range.length, @"range.length of a fresh configuration");
    check_same_u(ours.chunkSize, theirs.chunkSize, @"chunkSize of a fresh configuration");
    check_same_u(ours.range.location, 0, @"range.location of a fresh configuration");
    check_same_u(ours.range.length, 0, @"range.length of a fresh configuration");
    check_same_u(ours.chunkSize, 0, @"chunkSize of a fresh configuration");

    check_same([ours superclass] == PORT_CLASS(CharonHostNFCTagCommandConfiguration),
               [theirs superclass] == [NFCTagCommandConfiguration class], @"the base class of a read-multiple-blocks configuration");

    // The header says the start index is 0x00 to 0xFF and the length shall not be 0. The host keeps
    // both numbers it was given.
    CharonHostNFCISO15693ReadMultipleBlocksConfiguration *our_zero =
        [[PORT_CLASS(CharonHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] initWithRange:NSMakeRange(300, 0) chunkSize:0];
    NFCISO15693ReadMultipleBlocksConfiguration *their_zero =
        [[NFCISO15693ReadMultipleBlocksConfiguration alloc] initWithRange:NSMakeRange(300, 0) chunkSize:0];
    check_same_range(our_zero.range, their_zero.range, @"a zero-length range above the header's start index");
    check_same_u(our_zero.range.length, 0, @"a zero-length range stays zero length");

    CharonHostNFCISO15693ReadMultipleBlocksConfiguration *our_high =
        [[PORT_CLASS(CharonHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] initWithRange:NSMakeRange(1000, 5) chunkSize:0];
    NFCISO15693ReadMultipleBlocksConfiguration *their_high =
        [[NFCISO15693ReadMultipleBlocksConfiguration alloc] initWithRange:NSMakeRange(1000, 5) chunkSize:0];
    check_same_range(our_high.range, their_high.range, @"a range whose start index is above the header's");

    // The two-field initialiser leaves the base's retry fields at zero.
    CharonHostNFCISO15693ReadMultipleBlocksConfiguration *our_two =
        [[PORT_CLASS(CharonHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] initWithRange:NSMakeRange(3, 4) chunkSize:2];
    NFCISO15693ReadMultipleBlocksConfiguration *their_two =
        [[NFCISO15693ReadMultipleBlocksConfiguration alloc] initWithRange:NSMakeRange(3, 4) chunkSize:2];
    check_same_range(our_two.range, their_two.range, @"the range of the two-field initialiser");
    check_same_u(our_two.chunkSize, their_two.chunkSize, @"chunkSize of the two-field initialiser");
    check_same_u(our_two.maximumRetries, their_two.maximumRetries, @"maximumRetries of the two-field initialiser");
    check_same_d(our_two.retryInterval, their_two.retryInterval, @"retryInterval of the two-field initialiser");
    check_same_u(our_two.maximumRetries, 0, @"the two-field initialiser leaves maximumRetries at zero");
    check_same_d(our_two.retryInterval, 0, @"the two-field initialiser leaves retryInterval at zero");

    // The four-field initialiser sets all four.
    CharonHostNFCISO15693ReadMultipleBlocksConfiguration *our_four =
        [[PORT_CLASS(CharonHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] initWithRange:NSMakeRange(3, 4)
                                                                                    chunkSize:2
                                                                               maximumRetries:7
                                                                                retryInterval:2.5];
    NFCISO15693ReadMultipleBlocksConfiguration *their_four =
        [[NFCISO15693ReadMultipleBlocksConfiguration alloc] initWithRange:NSMakeRange(3, 4) chunkSize:2 maximumRetries:7 retryInterval:2.5];
    check_same_range(our_four.range, their_four.range, @"the range of the four-field initialiser");
    check_same_u(our_four.chunkSize, their_four.chunkSize, @"chunkSize of the four-field initialiser");
    check_same_u(our_four.maximumRetries, their_four.maximumRetries, @"maximumRetries of the four-field initialiser");
    check_same_d(our_four.retryInterval, their_four.retryInterval, @"retryInterval of the four-field initialiser");
    check_same_u(our_four.maximumRetries, 7, @"maximumRetries of the four-field initialiser is what was asked");
    check_same_d(our_four.retryInterval, 2.5, @"retryInterval of the four-field initialiser is what was asked");

    CharonHostNFCISO15693ReadMultipleBlocksConfiguration *ourcopy = [our_four copy];
    NFCISO15693ReadMultipleBlocksConfiguration *theircopy = [their_four copy];
    check_same([ourcopy class] == [our_four class], [theircopy class] == [their_four class],
               @"a copy of a read-multiple-blocks configuration is of the same class");
    check_same_range(ourcopy.range, theircopy.range, @"the range of a copy");
    check_same_u(ourcopy.chunkSize, theircopy.chunkSize, @"chunkSize of a copy");
    check_same_u(ourcopy.maximumRetries, theircopy.maximumRetries, @"maximumRetries of a copy");
    check_same_d(ourcopy.retryInterval, theircopy.retryInterval, @"retryInterval of a copy");

    // A copy is a value of its own: setting the original leaves it alone.
    our_four.range = NSMakeRange(99, 9); their_four.range = NSMakeRange(99, 9);
    check_same_range(ourcopy.range, theircopy.range, @"a copy is unaffected by the original being set");
    our_four.chunkSize = 77; their_four.chunkSize = 77;
    check_same_u(ourcopy.chunkSize, theircopy.chunkSize, @"chunkSize of a copy is unaffected by the original being set");
}

// The three configurations are values and are carried whole. The reader session they would be used
// with is carried in the same library (CoreNFC/NFCReaderSession.m, where the session rows are
// implemented), and carrying the configurations must not have grown a second one: the session's
// selectors are checked against the host's own, so a session that lacks one fails here rather than
// passing unnoticed.
static void check_true(BOOL passed, NSString *what)
{
    charon_check(passed, [what UTF8String], nil);
}

static void session_answers_as_host(void)
{
    Class our_base = NSClassFromString(@"CharonHostNFCReaderSession");
    check_true(our_base != Nil, @"NFCReaderSession is carried");
    check_same([our_base instancesRespondToSelector:@selector(beginSession)],
               [NFCReaderSession instancesRespondToSelector:@selector(beginSession)],
               @"beginSession of a reader session");
    check_same([our_base instancesRespondToSelector:@selector(invalidateSession)],
               [NFCReaderSession instancesRespondToSelector:@selector(invalidateSession)],
               @"invalidateSession of a reader session");
    check_same([our_base instancesRespondToSelector:@selector(sessionQueue)],
               [NFCReaderSession instancesRespondToSelector:@selector(sessionQueue)],
               @"sessionQueue of a reader session");
    check_same([our_base instancesRespondToSelector:@selector(alertMessage)],
               [NFCReaderSession instancesRespondToSelector:@selector(alertMessage)],
               @"alertMessage of a reader session");

    check_true([NFCReaderSession class] != Nil, @"the host has NFCReaderSession");
    check_true([NFCISO15693ReaderSession class] != Nil, @"the host has NFCISO15693ReaderSession");
    check_true(NSClassFromString(@"CharonHostNFCISO15693ReaderSession") != Nil,
               @"the port carries NFCISO15693ReaderSession, as the host does");
    check_true(NSClassFromString(@"CharonHostNFCTagReaderSession") == Nil,
               @"NFCTagReaderSession is absent from the port");

    // A configuration is not a way to reach a tag: carrying it must not have added a send, and the
    // copy that carries a configuration's own request data is still there.
    CharonHostNFCISO15693CustomCommandConfiguration *config =
        [[PORT_CLASS(CharonHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:1
                                                                                     customCommandCode:2
                                                                                     requestParameters:nil];
    check_true(![config respondsToSelector:@selector(sendCustomCommandWithConfiguration:completionHandler:)],
               @"a custom command configuration cannot send a command");
    check_true([config respondsToSelector:@selector(copyWithZone:)],
               @"a custom command configuration still copies");

    // And the port's value is its own class, not the host's class of the same API: the two coexist
    // in this process under one name apart, which is what makes the comparison above a comparison.
    check_true([NSStringFromClass([(id)config class]) hasPrefix:@"CharonHost"],
               @"the port's class carries the CharonHost prefix");
    check_true(NSClassFromString(@"CharonHostNFCISO15693CustomCommandConfiguration") !=
               NSClassFromString(@"NFCISO15693CustomCommandConfiguration"),
               @"the port's class and the host's class of the same API are two classes");
    // The host's own object, built the same way, answers 0 as well: the two are separate classes
    // with the same defaults, which is the point of the comparison and not an accident of it.
    NFCISO15693CustomCommandConfiguration *host_config =
        [[NFCISO15693CustomCommandConfiguration alloc] initWithManufacturerCode:1 customCommandCode:2 requestParameters:nil];
    check_same_u(((CharonHostNFCTagCommandConfiguration *)config).maximumRetries, host_config.maximumRetries,
                 @"the base's maximumRetries of a fresh configuration on both sides");
    check_same_u(((CharonHostNFCTagCommandConfiguration *)config).maximumRetries, 0,
                 @"the base's maximumRetries of a fresh configuration");
}

int main(void)
{
    @autoreleasepool {
        base_class();
        custom_command();
        read_multiple_blocks();
        session_answers_as_host();
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}