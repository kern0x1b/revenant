#import <CoreNFC/CoreNFC.h>

@implementation NFCTagCommandConfiguration

@synthesize maximumRetries = _maximumRetries, retryInterval = _retryInterval;

- (id)copyWithZone:(NSZone *)zone
{
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
