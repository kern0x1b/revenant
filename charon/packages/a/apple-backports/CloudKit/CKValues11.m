// What iOS 11 added to the sharing surface: the configuration an operation is run with, and the
// group several operations are run in.
//
// Both are values. CKOperationConfiguration is what an operation reads its container, its timeouts
// and its quality of service from, and CKOperationGroup is the shared name and shared configuration
// of the operations that belong to one request. The operations themselves, and the transport they
// run over, are a later delivery; what is here is everything a caller can build and read before then.

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

@implementation CKOperationConfiguration

- (instancetype)init
{
    self = [super init];
    if (self) {
        // The values a new configuration answers are the ones the header documents: a long-lived
        // operation is not long-lived, cellular access is allowed, and the two timeouts are the ones
        // a URL request of this release carries.
        _longLived = NO;
        _allowsCellularAccess = YES;
        _timeoutIntervalForRequest = 60.0;
        _timeoutIntervalForResource = 7.0 * 24.0 * 60.0 * 60.0;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    CKOperationConfiguration *copy = [[CKOperationConfiguration allocWithZone:zone] init];
    copy.container = _container;
    copy.longLived = _longLived;
    copy.allowsCellularAccess = _allowsCellularAccess;
    copy.qualityOfService = _qualityOfService;
    copy.timeoutIntervalForRequest = _timeoutIntervalForRequest;
    copy.timeoutIntervalForResource = _timeoutIntervalForResource;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKOperationConfiguration: %p; container=%@, longLived=%d, allowsCellularAccess=%d, qualityOfService=%ld, timeoutIntervalForRequest=%g, timeoutIntervalForResource=%g>",
            self, _container, _longLived, _allowsCellularAccess, (long)_qualityOfService,
            _timeoutIntervalForRequest, _timeoutIntervalForResource];
}

@end

@implementation CKOperationGroup

- (instancetype)initWithOperationGroupID:(NSString *)operationGroupID
{
    self = [super init];
    if (self) {
        _operationGroupID = [operationGroupID copy];
        _defaultConfiguration = [[CKOperationConfiguration alloc] init];
    }
    return self;
}

- (instancetype)init
{
    // A group is a named request of the operations in it. CloudKit gives it an identifier when one
    // is not supplied, and this port does the same rather than answering an empty one.
    return [self initWithOperationGroupID:[[NSUUID UUID] UUIDString]];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _operationGroupID = [[coder decodeObjectOfClass:[NSString class] forKey:@"operationGroupID"] copy];
        _name = [[coder decodeObjectOfClass:[NSString class] forKey:@"name"] copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_operationGroupID forKey:@"operationGroupID"];
    [coder encodeObject:_name forKey:@"name"];
}

- (id)copyWithZone:(NSZone *)zone
{
    CKOperationGroup *copy = [[CKOperationGroup allocWithZone:zone] initWithOperationGroupID:_operationGroupID];
    copy.name = _name;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKOperationGroup: %p; operationGroupID=%@, name=%@, expectedSendSize=%lld, expectedReceiveSize=%lld, quantity=%d>",
            self, _operationGroupID, _name, _expectedSendSize, _expectedReceiveSize, _quantity];
}

@end
