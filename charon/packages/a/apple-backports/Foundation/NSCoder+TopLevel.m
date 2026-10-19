#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char CharonCoderErrorKey;
static char CharonCoderPolicyKey;

NSError *charon_coder_error(NSException *exception, NSInteger code)
{
    NSString *reason = exception.reason.length ? exception.reason : exception.name;
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:reason ? @{NSDebugDescriptionErrorKey: reason} : nil];
}

id charon_decode_top_level(NSCoder *coder, NSString *key, id (^decode)(void), NSError **error)
{
    id decoded = nil;
    NSError *failure = nil;
    @try {
        decoded = decode();
    } @catch (NSException *exception) {
        if ([exception.name isEqualToString:NSInvalidArgumentException] || [exception.name isEqualToString:NSInvalidUnarchiveOperationException] ||
            [exception.name isEqualToString:NSGenericException] || [exception.name isEqualToString:NSRangeException])
            failure = charon_coder_error(exception, NSCoderReadCorruptError);
        else
            @throw;
    }
    if (!failure)
        failure = objc_getAssociatedObject(coder, &CharonCoderErrorKey);
    if (!failure && !decoded)
        failure = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderValueNotFoundError
                                  userInfo:key ? @{NSDebugDescriptionErrorKey: [NSString stringWithFormat:@"requested key: '%@'", key]} : nil];
    if (failure) {
        decoded = nil;
        if (error)
            *error = failure;
    }
    return decoded;
}

@implementation NSCoder (CharonTopLevel)

- (NSError *)error
{
    return objc_getAssociatedObject(self, &CharonCoderErrorKey);
}

- (void)failWithError:(NSError *)error
{
    NSNumber *policy = objc_getAssociatedObject(self, &CharonCoderPolicyKey);
    if (!policy || policy.integerValue == NSDecodingFailurePolicyRaiseException)
        [NSException raise:NSInvalidUnarchiveOperationException format:@"%@", error.localizedDescription];
    objc_setAssociatedObject(self, &CharonCoderErrorKey, error, OBJC_ASSOCIATION_RETAIN);
}

- (NSDecodingFailurePolicy)decodingFailurePolicy
{
    NSNumber *policy = objc_getAssociatedObject(self, &CharonCoderPolicyKey);
    return policy ? (NSDecodingFailurePolicy)policy.integerValue : NSDecodingFailurePolicyRaiseException;
}

- (void)setDecodingFailurePolicy:(NSDecodingFailurePolicy)decodingFailurePolicy
{
    objc_setAssociatedObject(self, &CharonCoderPolicyKey, @(decodingFailurePolicy), OBJC_ASSOCIATION_RETAIN);
}

- (id)decodeTopLevelObjectAndReturnError:(NSError **)error
{
    return charon_decode_top_level(self, nil, ^{
        return [self decodeObject];
    }, error);
}

- (id)decodeTopLevelObjectForKey:(NSString *)key error:(NSError **)error
{
    return charon_decode_top_level(self, key, ^{
        return [self decodeObjectForKey:key];
    }, error);
}

- (id)decodeTopLevelObjectOfClass:(Class)aClass forKey:(NSString *)key error:(NSError **)error
{
    return charon_decode_top_level(self, key, ^{
        return [self decodeObjectOfClass:aClass forKey:key];
    }, error);
}

- (id)decodeTopLevelObjectOfClasses:(NSSet *)classes forKey:(NSString *)key error:(NSError **)error
{
    return charon_decode_top_level(self, key, ^{
        return [self decodeObjectOfClasses:classes forKey:key];
    }, error);
}

@end
