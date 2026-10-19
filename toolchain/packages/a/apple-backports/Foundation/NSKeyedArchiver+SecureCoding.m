#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSError *charon_coder_error(NSException *exception, NSInteger code);

static char CharonArchiverDataKey;
static char CharonArchiverFinishedKey;

static NSMutableData *charon_archiver_buffer(NSKeyedArchiver *archiver)
{
    NSMutableData *data = objc_getAssociatedObject(archiver, &CharonArchiverDataKey);
    if (data)
        return data;
    Ivar stream = class_getInstanceVariable([NSKeyedArchiver class], "_stream");
    id output = stream ? object_getIvar(archiver, stream) : nil;
    return [output isKindOfClass:[NSMutableData class]] ? output : nil;
}

@implementation NSKeyedArchiver (CharonSecureCoding)

- (instancetype)initRequiringSecureCoding:(BOOL)requiresSecureCoding
{
    NSMutableData *data = [NSMutableData data];
    if ((self = [self initForWritingWithMutableData:data])) {
        self.requiresSecureCoding = requiresSecureCoding;
        objc_setAssociatedObject(self, &CharonArchiverDataKey, data, OBJC_ASSOCIATION_RETAIN);
    }
    return self;
}

- (NSData *)encodedData
{
    NSMutableData *data = charon_archiver_buffer(self);
    if (!data)
        return [NSMutableData data];
    if (!objc_getAssociatedObject(self, &CharonArchiverFinishedKey)) {
        objc_setAssociatedObject(self, &CharonArchiverFinishedKey, @YES, OBJC_ASSOCIATION_RETAIN);
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
            NSError *underlying = charon_coder_error(exception, NSCoderReadCorruptError);
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderInvalidValueError userInfo:@{NSUnderlyingErrorKey: underlying}];
        }
        return nil;
    }
    return [archiver encodedData];
}

@end
