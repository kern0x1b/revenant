#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSError *revenant_coder_error(NSException *exception, NSInteger code);

static char RevenantArchiverDataKey;
static char RevenantArchiverFinishedKey;

static NSMutableData *revenant_archiver_buffer(NSKeyedArchiver *archiver)
{
    NSMutableData *data = objc_getAssociatedObject(archiver, &RevenantArchiverDataKey);
    if (data)
        return data;
    Ivar stream = class_getInstanceVariable([NSKeyedArchiver class], "_stream");
    id output = stream ? object_getIvar(archiver, stream) : nil;
    return [output isKindOfClass:[NSMutableData class]] ? output : nil;
}

@implementation NSKeyedArchiver (RevenantSecureCoding)

- (instancetype)initRequiringSecureCoding:(BOOL)requiresSecureCoding
{
    NSMutableData *data = [NSMutableData data];
    if ((self = [self initForWritingWithMutableData:data])) {
        self.requiresSecureCoding = requiresSecureCoding;
        objc_setAssociatedObject(self, &RevenantArchiverDataKey, data, OBJC_ASSOCIATION_RETAIN);
    }
    return self;
}

- (NSData *)encodedData
{
    NSMutableData *data = revenant_archiver_buffer(self);
    if (!data)
        return [NSMutableData data];
    if (!objc_getAssociatedObject(self, &RevenantArchiverFinishedKey)) {
        objc_setAssociatedObject(self, &RevenantArchiverFinishedKey, @YES, OBJC_ASSOCIATION_RETAIN);
        [self finishEncoding];
    }
    return data;
}

+ (NSData *)archivedDataWithRootObject:(id)object requiringSecureCoding:(BOOL)requiresSecureCoding error:(NSError **)error
{
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:requiresSecureCoding];
    @try {
        [archiver encodeObject:object forKey:NSKeyedArchiveRootObjectKey];
    } @catch (NSException *exception) {
        if (error) {
            NSError *underlying = revenant_coder_error(exception, NSCoderReadCorruptError);
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderInvalidValueError userInfo:@{NSUnderlyingErrorKey: underlying}];
        }
        return nil;
    }
    return [archiver encodedData];
}

@end
