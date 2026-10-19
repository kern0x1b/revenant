#import <CoreNFC/CoreNFC.h>

// The tag command configurations as iOS 11.0 has them: NFCTagCommandConfiguration and the two
// subclasses of it the ISO15693 tag declares. All three arrived in iOS 11.0, so they are all here;
// the classes and members iOS 13.0 added to the framework are elsewhere, because an object carries
// the API of one release.
//
// A configuration is a value. It is made with the fields an application sets, read back through its
// properties, and copied; nothing in it is a session, a tag or a radio, so it is made and used on a
// 4S and an iPad 2 exactly as it is on a device with an NFC radio. What it is FOR needs a session and
// a tag, and the sessions of the framework answer as a device without the radio does: +readingAvailable
// is NO and a session cannot be made (facts/CoreNFC/NFCReaderSession.md). So a caller here can build,
// keep and copy a configuration, and cannot send it anywhere - which is the one thing a configuration
// exists for, and is absent for a reason of its own rather than by a stub answering.
//
// The semantics below are the host's own, measured rather than read off the header, which states valid
// ranges but does not say what happens outside them (facts/CoreNFC/TagConfiguration.md):
//   - every field is kept exactly as it was given. A manufacturer code of 0x1FF stays 0x1FF although
//     the header calls 0x00 to 0xFF valid, maximumRetries of 1000 stays 1000 although the header calls
//     0 to 256 valid, a retry interval of -5 stays -5, and a zero-length read range stays zero length
//     although the header says length shall not be 0. Nothing clamps and nothing raises: the host
//     answers with the number it was given in every one of those cases.
//   - -init leaves every field zero and requestParameters nil. The three- and four-field initialisers
//     of each subclass set what they name and leave the retry fields of the base at zero, which is what
//     the header describes as the default: zero maximum retries and a zero retry interval
//     and what the host answers.
//   - -copy is NSCopying and the copy is independent: setting requestParameters on the copy leaves the
//     original's alone, and a copy of a subclass is the subclass, carrying the base's retry fields too.
//     -isEqual: is NSObject's, so two configurations with identical fields are not equal: measured
//     isEqual 0 for two objects built from the same range, chunk size, retries and interval.
//
// The members that arrived after 11.0 are not here: -[NFCTag identifier], -[NFCTag available],
// -[NFCTag asNFCISO15693Tag] and the rest of the tag protocol, and the reader sessions themselves, are
// objects this release does not have.

@implementation NFCTagCommandConfiguration

@synthesize maximumRetries = _maximumRetries, retryInterval = _retryInterval;

- (id)copyWithZone:(NSZone *)zone
{
    // [self class] and not NFCTagCommandConfiguration: the host copies a subclass into its own class,
    // and a base-typed copy of a subclass is that subclass, carrying the retry fields it was given.
    NFCTagCommandConfiguration *copy = [[self class] allocWithZone:zone];
    copy.maximumRetries = self.maximumRetries;
    copy.retryInterval = self.retryInterval;
    return copy;
}

@end

@implementation NFCISO15693CustomCommandConfiguration

@synthesize manufacturerCode = _manufacturerCode, customCommandCode = _customCommandCode, requestParameters = _requestParameters;

- (instancetype)initWithManufacturerCode:(NSUInteger)manufacturerCode
                       customCommandCode:(NSUInteger)customCommandCode
                       requestParameters:(NSData *)requestParameters
{
    self = [super init];
    if (self) {
        _manufacturerCode = manufacturerCode;
        _customCommandCode = customCommandCode;
        _requestParameters = [requestParameters copy];
    }
    return self;
}

- (instancetype)initWithManufacturerCode:(NSUInteger)manufacturerCode
                       customCommandCode:(NSUInteger)customCommandCode
                       requestParameters:(NSData *)requestParameters
                          maximumRetries:(NSUInteger)maximumRetries
                           retryInterval:(NSTimeInterval)retryInterval
{
    self = [self initWithManufacturerCode:manufacturerCode
                        customCommandCode:customCommandCode
                        requestParameters:requestParameters];
    if (self) {
        self.maximumRetries = maximumRetries;
        self.retryInterval = retryInterval;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // All three of this class's own fields, not just the parameters: the base's copyWithZone: knows
    // nothing of them, and a copy that dropped them would be a configuration that names no command.
    // The parameters are copied too, so a copy's request data is its own: the host answers the
    // original "hi" and the copy "other" after the copy is given new data.
    NFCISO15693CustomCommandConfiguration *copy = [super copyWithZone:zone];
    copy.manufacturerCode = self.manufacturerCode;
    copy.customCommandCode = self.customCommandCode;
    copy.requestParameters = self.requestParameters;
    return copy;
}

@end

@implementation NFCISO15693ReadMultipleBlocksConfiguration

@synthesize range = _range, chunkSize = _chunkSize;

- (instancetype)initWithRange:(NSRange)range
                    chunkSize:(NSUInteger)chunkSize
{
    self = [super init];
    if (self) {
        _range = range;
        _chunkSize = chunkSize;
    }
    return self;
}

- (instancetype)initWithRange:(NSRange)range
                    chunkSize:(NSUInteger)chunkSize
               maximumRetries:(NSUInteger)maximumRetries
                retryInterval:(NSTimeInterval)retryInterval
{
    self = [self initWithRange:range chunkSize:chunkSize];
    if (self) {
        self.maximumRetries = maximumRetries;
        self.retryInterval = retryInterval;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NFCISO15693ReadMultipleBlocksConfiguration *copy = [super copyWithZone:zone];
    copy.range = self.range;
    copy.chunkSize = self.chunkSize;
    return copy;
}

@end