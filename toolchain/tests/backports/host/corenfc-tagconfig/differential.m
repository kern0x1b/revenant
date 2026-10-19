#import <Foundation/Foundation.h>
#import <CoreNFC/CoreNFC.h>
#import <objc/runtime.h>
#import "check.h"

@interface RevenantHostNFCTagCommandConfiguration : NSObject <NSCopying>
@property (nonatomic, assign) NSUInteger maximumRetries;
@property (nonatomic, assign) NSTimeInterval retryInterval;
@end

@interface RevenantHostNFCISO15693CustomCommandConfiguration : RevenantHostNFCTagCommandConfiguration
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

@interface RevenantHostNFCISO15693ReadMultipleBlocksConfiguration : RevenantHostNFCTagCommandConfiguration
@property (nonatomic, assign) NSRange range;
@property (nonatomic, assign) NSUInteger chunkSize;
- (instancetype)initWithRange:(NSRange)range
                    chunkSize:(NSUInteger)chunkSize;
- (instancetype)initWithRange:(NSRange)range
                    chunkSize:(NSUInteger)chunkSize
               maximumRetries:(NSUInteger)maximumRetries
                retryInterval:(NSTimeInterval)retryInterval;
@end

static Class port_class(Class declared, const char *name)
{
    NSString *spelling = [NSString stringWithUTF8String:name];
    Class found = NSClassFromString(spelling);
    revenant_check(found == declared, [[NSString stringWithFormat:@"%@ is carried under its own name", spelling] UTF8String], nil);
    return found;
}

#define PORT_CLASS(c) port_class([c class], #c)

static void check_same(BOOL ours, BOOL theirs, NSString *what)
{
    revenant_check(ours == theirs, [[NSString stringWithFormat:@"%@ answers what CoreNFC answers", what] UTF8String],
                 [NSString stringWithFormat:@"port %d, host %d", ours, theirs]);
}

static void check_same_u(NSUInteger ours, NSUInteger theirs, NSString *what)
{
    revenant_check(ours == theirs, [[NSString stringWithFormat:@"%@ answers what CoreNFC answers", what] UTF8String],
                 [NSString stringWithFormat:@"port %lu, host %lu", (unsigned long)ours, (unsigned long)theirs]);
}

static void check_same_d(double ours, double theirs, NSString *what)
{
    revenant_check(ours == theirs, [[NSString stringWithFormat:@"%@ answers what CoreNFC answers", what] UTF8String],
                 [NSString stringWithFormat:@"port %g, host %g", ours, theirs]);
}

static void check_same_range(NSRange ours, NSRange theirs, NSString *what)
{
    check_same_u(ours.location, theirs.location, [what stringByAppendingString:@".location"]);
    check_same_u(ours.length, theirs.length, [what stringByAppendingString:@".length"]);
}

static void check_same_obj(id ours, id theirs, NSString *what)
{
    revenant_check(ours == theirs || [ours isEqual:theirs],
                 [[NSString stringWithFormat:@"%@ answers what CoreNFC answers", what] UTF8String],
                 [NSString stringWithFormat:@"port %@, host %@", ours, theirs]);
}

static NSData *text(const char *s)
{
    return [NSData dataWithBytes:s length:strlen(s)];
}

static void base_class(void)
{
    RevenantHostNFCTagCommandConfiguration *ours = [[PORT_CLASS(RevenantHostNFCTagCommandConfiguration) alloc] init];
    NFCTagCommandConfiguration *theirs = [[NFCTagCommandConfiguration alloc] init];

    check_same_u(ours.maximumRetries, theirs.maximumRetries, @"maximumRetries of a fresh configuration");
    check_same_d(ours.retryInterval, theirs.retryInterval, @"retryInterval of a fresh configuration");
    check_same_u(ours.maximumRetries, 0, @"maximumRetries of a fresh configuration");
    check_same_d(ours.retryInterval, 0, @"retryInterval of a fresh configuration");

    check_same([ours conformsToProtocol:@protocol(NSCopying)], [theirs conformsToProtocol:@protocol(NSCopying)],
               @"NSCopying conformance");
    check_same([ours respondsToSelector:@selector(copyWithZone:)], [theirs respondsToSelector:@selector(copyWithZone:)],
               @"-copyWithZone: is what answers");

    ours.maximumRetries = 1000; theirs.maximumRetries = 1000;
    check_same_u(ours.maximumRetries, theirs.maximumRetries, @"maximumRetries above the header's range");
    check_same_u(ours.maximumRetries, 1000, @"maximumRetries above the header's range is kept as given");

    ours.retryInterval = -5; theirs.retryInterval = -5;
    check_same_d(ours.retryInterval, theirs.retryInterval, @"a negative retryInterval");

    ours.maximumRetries = 3; theirs.maximumRetries = 3;
    ours.retryInterval = 0.25; theirs.retryInterval = 0.25;
    RevenantHostNFCTagCommandConfiguration *ourcopy = [ours copy];
    NFCTagCommandConfiguration *theircopy = [theirs copy];
    check_same([ourcopy class] == [ours class], [theircopy class] == [theirs class], @"a copy is of the same class");
    check_same_u(ourcopy.maximumRetries, theircopy.maximumRetries, @"maximumRetries of a copy");
    check_same_d(ourcopy.retryInterval, theircopy.retryInterval, @"retryInterval of a copy");

    RevenantHostNFCTagCommandConfiguration *ours2 = [[PORT_CLASS(RevenantHostNFCTagCommandConfiguration) alloc] init];
    NFCTagCommandConfiguration *theirs2 = [[NFCTagCommandConfiguration alloc] init];
    ours2.maximumRetries = 3; theirs2.maximumRetries = 3;
    ours2.retryInterval = 0.25; theirs2.retryInterval = 0.25;
    check_same([ours isEqual:ours2], [theirs isEqual:theirs2], @"isEqual: over two configurations of the same fields");
    check_same([ours isEqual:ours2], NO, @"isEqual: over two configurations of the same fields is NO");
}

static void custom_command(void)
{
    RevenantHostNFCISO15693CustomCommandConfiguration *ours =
        [[PORT_CLASS(RevenantHostNFCISO15693CustomCommandConfiguration) alloc] init];
    NFCISO15693CustomCommandConfiguration *theirs = [[NFCISO15693CustomCommandConfiguration alloc] init];

    check_same_u(ours.manufacturerCode, theirs.manufacturerCode, @"manufacturerCode of a fresh configuration");
    check_same_u(ours.customCommandCode, theirs.customCommandCode, @"customCommandCode of a fresh configuration");
    check_same_obj(ours.requestParameters, theirs.requestParameters, @"requestParameters of a fresh configuration");
    check_same(ours.requestParameters == nil, theirs.requestParameters == nil,
               @"requestParameters of a fresh configuration");
    check_same(ours.requestParameters == nil, YES, @"requestParameters of a fresh configuration is nil");

    check_same([ours superclass] == PORT_CLASS(RevenantHostNFCTagCommandConfiguration),
               [theirs superclass] == [NFCTagCommandConfiguration class], @"the base class of a custom command configuration");

    RevenantHostNFCISO15693CustomCommandConfiguration *our_out =
        [[PORT_CLASS(RevenantHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:0x1FF
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

    NSData *params = text("hi");
    RevenantHostNFCISO15693CustomCommandConfiguration *our_three =
        [[PORT_CLASS(RevenantHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:0x04
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

    RevenantHostNFCISO15693CustomCommandConfiguration *our_five =
        [[PORT_CLASS(RevenantHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:0x04
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

    RevenantHostNFCISO15693CustomCommandConfiguration *ourcopy = [our_five copy];
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

    RevenantHostNFCISO15693CustomCommandConfiguration *ournil =
        [[PORT_CLASS(RevenantHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:1 customCommandCode:2 requestParameters:nil];
    NFCISO15693CustomCommandConfiguration *theirnil =
        [[NFCISO15693CustomCommandConfiguration alloc] initWithManufacturerCode:1 customCommandCode:2 requestParameters:nil];
    RevenantHostNFCISO15693CustomCommandConfiguration *ournilcopy = [ournil copy];
    NFCISO15693CustomCommandConfiguration *theirnilcopy = [theirnil copy];
    check_same(ournilcopy.requestParameters == nil, theirnilcopy.requestParameters == nil,
               @"nil requestParameters through a copy");
    check_same(ournilcopy.manufacturerCode, theirnilcopy.manufacturerCode, @"manufacturerCode through a copy of a nil-parameters configuration");
    check_same_u(ournilcopy.maximumRetries, theirnilcopy.maximumRetries, @"maximumRetries through a copy of a nil-parameters configuration");
}

static void read_multiple_blocks(void)
{
    RevenantHostNFCISO15693ReadMultipleBlocksConfiguration *ours =
        [[PORT_CLASS(RevenantHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] init];
    NFCISO15693ReadMultipleBlocksConfiguration *theirs = [[NFCISO15693ReadMultipleBlocksConfiguration alloc] init];

    check_same_u(ours.range.location, theirs.range.location, @"range.location of a fresh configuration");
    check_same_u(ours.range.length, theirs.range.length, @"range.length of a fresh configuration");
    check_same_u(ours.chunkSize, theirs.chunkSize, @"chunkSize of a fresh configuration");
    check_same_u(ours.range.location, 0, @"range.location of a fresh configuration");
    check_same_u(ours.range.length, 0, @"range.length of a fresh configuration");
    check_same_u(ours.chunkSize, 0, @"chunkSize of a fresh configuration");

    check_same([ours superclass] == PORT_CLASS(RevenantHostNFCTagCommandConfiguration),
               [theirs superclass] == [NFCTagCommandConfiguration class], @"the base class of a read-multiple-blocks configuration");

    RevenantHostNFCISO15693ReadMultipleBlocksConfiguration *our_zero =
        [[PORT_CLASS(RevenantHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] initWithRange:NSMakeRange(300, 0) chunkSize:0];
    NFCISO15693ReadMultipleBlocksConfiguration *their_zero =
        [[NFCISO15693ReadMultipleBlocksConfiguration alloc] initWithRange:NSMakeRange(300, 0) chunkSize:0];
    check_same_range(our_zero.range, their_zero.range, @"a zero-length range above the header's start index");
    check_same_u(our_zero.range.length, 0, @"a zero-length range stays zero length");

    RevenantHostNFCISO15693ReadMultipleBlocksConfiguration *our_high =
        [[PORT_CLASS(RevenantHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] initWithRange:NSMakeRange(1000, 5) chunkSize:0];
    NFCISO15693ReadMultipleBlocksConfiguration *their_high =
        [[NFCISO15693ReadMultipleBlocksConfiguration alloc] initWithRange:NSMakeRange(1000, 5) chunkSize:0];
    check_same_range(our_high.range, their_high.range, @"a range whose start index is above the header's");

    RevenantHostNFCISO15693ReadMultipleBlocksConfiguration *our_two =
        [[PORT_CLASS(RevenantHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] initWithRange:NSMakeRange(3, 4) chunkSize:2];
    NFCISO15693ReadMultipleBlocksConfiguration *their_two =
        [[NFCISO15693ReadMultipleBlocksConfiguration alloc] initWithRange:NSMakeRange(3, 4) chunkSize:2];
    check_same_range(our_two.range, their_two.range, @"the range of the two-field initialiser");
    check_same_u(our_two.chunkSize, their_two.chunkSize, @"chunkSize of the two-field initialiser");
    check_same_u(our_two.maximumRetries, their_two.maximumRetries, @"maximumRetries of the two-field initialiser");
    check_same_d(our_two.retryInterval, their_two.retryInterval, @"retryInterval of the two-field initialiser");
    check_same_u(our_two.maximumRetries, 0, @"the two-field initialiser leaves maximumRetries at zero");
    check_same_d(our_two.retryInterval, 0, @"the two-field initialiser leaves retryInterval at zero");

    RevenantHostNFCISO15693ReadMultipleBlocksConfiguration *our_four =
        [[PORT_CLASS(RevenantHostNFCISO15693ReadMultipleBlocksConfiguration) alloc] initWithRange:NSMakeRange(3, 4)
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

    RevenantHostNFCISO15693ReadMultipleBlocksConfiguration *ourcopy = [our_four copy];
    NFCISO15693ReadMultipleBlocksConfiguration *theircopy = [their_four copy];
    check_same([ourcopy class] == [our_four class], [theircopy class] == [their_four class],
               @"a copy of a read-multiple-blocks configuration is of the same class");
    check_same_range(ourcopy.range, theircopy.range, @"the range of a copy");
    check_same_u(ourcopy.chunkSize, theircopy.chunkSize, @"chunkSize of a copy");
    check_same_u(ourcopy.maximumRetries, theircopy.maximumRetries, @"maximumRetries of a copy");
    check_same_d(ourcopy.retryInterval, theircopy.retryInterval, @"retryInterval of a copy");

    our_four.range = NSMakeRange(99, 9); their_four.range = NSMakeRange(99, 9);
    check_same_range(ourcopy.range, theircopy.range, @"a copy is unaffected by the original being set");
    our_four.chunkSize = 77; their_four.chunkSize = 77;
    check_same_u(ourcopy.chunkSize, theircopy.chunkSize, @"chunkSize of a copy is unaffected by the original being set");
}

static void check_true(BOOL passed, NSString *what)
{
    revenant_check(passed, [what UTF8String], nil);
}

static void session_answers_as_host(void)
{
    Class our_base = NSClassFromString(@"RevenantHostNFCReaderSession");
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
    check_true(NSClassFromString(@"RevenantHostNFCISO15693ReaderSession") != Nil,
               @"the port carries NFCISO15693ReaderSession, as the host does");
    check_true(NSClassFromString(@"RevenantHostNFCTagReaderSession") == Nil,
               @"NFCTagReaderSession is absent from the port");

    RevenantHostNFCISO15693CustomCommandConfiguration *config =
        [[PORT_CLASS(RevenantHostNFCISO15693CustomCommandConfiguration) alloc] initWithManufacturerCode:1
                                                                                     customCommandCode:2
                                                                                     requestParameters:nil];
    check_true(![config respondsToSelector:@selector(sendCustomCommandWithConfiguration:completionHandler:)],
               @"a custom command configuration cannot send a command");
    check_true([config respondsToSelector:@selector(copyWithZone:)],
               @"a custom command configuration still copies");

    check_true([NSStringFromClass([(id)config class]) hasPrefix:@"RevenantHost"],
               @"the port's class carries the RevenantHost prefix");
    check_true(NSClassFromString(@"RevenantHostNFCISO15693CustomCommandConfiguration") !=
               NSClassFromString(@"NFCISO15693CustomCommandConfiguration"),
               @"the port's class and the host's class of the same API are two classes");
    NFCISO15693CustomCommandConfiguration *host_config =
        [[NFCISO15693CustomCommandConfiguration alloc] initWithManufacturerCode:1 customCommandCode:2 requestParameters:nil];
    check_same_u(((RevenantHostNFCTagCommandConfiguration *)config).maximumRetries, host_config.maximumRetries,
                 @"the base's maximumRetries of a fresh configuration on both sides");
    check_same_u(((RevenantHostNFCTagCommandConfiguration *)config).maximumRetries, 0,
                 @"the base's maximumRetries of a fresh configuration");
}

int main(void)
{
    @autoreleasepool {
        base_class();
        custom_command();
        read_multiple_blocks();
        session_answers_as_host();
        printf("%d of %d checks failed\n", revenant_failures, revenant_checks);
        return revenant_failures;
    }
}
