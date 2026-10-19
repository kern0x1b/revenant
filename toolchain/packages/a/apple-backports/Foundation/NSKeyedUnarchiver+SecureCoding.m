#import <Foundation/Foundation.h>

NSError *charon_coder_error(NSException *exception, NSInteger code);

static id charon_unarchive(NSSet *classes, NSData *data, NSError **error)
{
    NSError *failure = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&failure];
    if (!unarchiver) {
        if (error)
            *error = failure;
        return nil;
    }
    unarchiver.requiresSecureCoding = YES;
    [unarchiver setDecodingFailurePolicy:NSDecodingFailurePolicySetErrorAndReturn];
    id decoded = [unarchiver decodeTopLevelObjectOfClasses:classes forKey:NSKeyedArchiveRootObjectKey error:&failure];
    if (failure) {
        if (error)
            *error = failure;
        return nil;
    }
    return decoded;
}

@implementation NSKeyedUnarchiver (CharonSecureCoding)

- (instancetype)initForReadingFromData:(NSData *)data error:(NSError **)error
{
    @try {
        self = [self initForReadingWithData:data];
    } @catch (NSException *exception) {
        if (error)
            *error = charon_coder_error(exception, NSCoderReadCorruptError);
        return nil;
    }
    if (!self) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderReadCorruptError
                                     userInfo:@{NSDebugDescriptionErrorKey: @"the data is not a keyed archive"}];
        return nil;
    }
    self.requiresSecureCoding = YES;
    [self setDecodingFailurePolicy:NSDecodingFailurePolicySetErrorAndReturn];
    return self;
}

+ (id)unarchivedObjectOfClass:(Class)cls fromData:(NSData *)data error:(NSError **)error
{
    return charon_unarchive([NSSet setWithObject:cls], data, error);
}

+ (id)unarchivedObjectOfClasses:(NSSet *)classes fromData:(NSData *)data error:(NSError **)error
{
    return charon_unarchive(classes, data, error);
}

@end
