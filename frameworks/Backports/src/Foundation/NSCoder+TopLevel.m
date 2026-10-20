#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantCoderErrorKey;
static char RevenantCoderPolicyKey;

NSError *revenant_coder_error(NSException *exception, NSInteger code)
{
    NSString *reason = exception.reason.length ? exception.reason : exception.name;
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:reason ? @{NSDebugDescriptionErrorKey: reason} : nil];
}

id revenant_decode_top_level(NSCoder *coder, NSString *key, id (^decode)(void), NSError **error)
{
    id decoded = nil;
    NSError *failure = nil;
    @try {
        decoded = decode();
    } @catch (NSException *exception) {
        if ([exception.name isEqualToString:NSInvalidArgumentException] || [exception.name isEqualToString:NSInvalidUnarchiveOperationException] ||
            [exception.name isEqualToString:NSGenericException] || [exception.name isEqualToString:NSRangeException])
            failure = revenant_coder_error(exception, NSCoderReadCorruptError);
        else
            @throw;
    }
    if (!failure)
        failure = objc_getAssociatedObject(coder, &RevenantCoderErrorKey);
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

@implementation NSCoder (RevenantTopLevel)

- (NSError *)error
{
    return objc_getAssociatedObject(self, &RevenantCoderErrorKey);
}

- (void)failWithError:(NSError *)error
{
    NSNumber *policy = objc_getAssociatedObject(self, &RevenantCoderPolicyKey);
    if (!policy || policy.integerValue == NSDecodingFailurePolicyRaiseException)
        [NSException raise:NSInvalidUnarchiveOperationException format:@"%@", error.localizedDescription];
    objc_setAssociatedObject(self, &RevenantCoderErrorKey, error, OBJC_ASSOCIATION_RETAIN);
}

- (NSDecodingFailurePolicy)decodingFailurePolicy
{
    NSNumber *policy = objc_getAssociatedObject(self, &RevenantCoderPolicyKey);
    return policy ? (NSDecodingFailurePolicy)policy.integerValue : NSDecodingFailurePolicyRaiseException;
}

- (void)setDecodingFailurePolicy:(NSDecodingFailurePolicy)decodingFailurePolicy
{
    objc_setAssociatedObject(self, &RevenantCoderPolicyKey, @(decodingFailurePolicy), OBJC_ASSOCIATION_RETAIN);
}

- (id)decodeTopLevelObjectAndReturnError:(NSError **)error
{
    return revenant_decode_top_level(self, nil, ^{
        return [self decodeObject];
    }, error);
}

- (id)decodeTopLevelObjectForKey:(NSString *)key error:(NSError **)error
{
    return revenant_decode_top_level(self, key, ^{
        return [self decodeObjectForKey:key];
    }, error);
}

- (id)decodeTopLevelObjectOfClass:(Class)aClass forKey:(NSString *)key error:(NSError **)error
{
    return revenant_decode_top_level(self, key, ^{
        return [self decodeObjectOfClass:aClass forKey:key];
    }, error);
}

- (id)decodeTopLevelObjectOfClasses:(NSSet *)classes forKey:(NSString *)key error:(NSError **)error
{
    return revenant_decode_top_level(self, key, ^{
        return [self decodeObjectOfClasses:classes forKey:key];
    }, error);
}

@end
