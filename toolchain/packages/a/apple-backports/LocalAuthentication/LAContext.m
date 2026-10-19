#import <LocalAuthentication/LocalAuthentication.h>

extern NSString *const LAErrorDomain;

static NSError *charon_error(NSInteger code, NSString *description, NSString *debug)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey];
    if (debug)
        info[NSDebugDescriptionErrorKey] = debug;
    return [NSError errorWithDomain:LAErrorDomain code:code userInfo:info];
}

@implementation LAContext {
    BOOL _invalidated;
    NSString *_localizedFallbackTitle;
    NSNumber *_maxBiometryFailures;
    NSString *_localizedCancelTitle;
    NSTimeInterval _touchIDAuthenticationAllowableReuseDuration;
    NSString *_localizedReason;
    BOOL _interactionNotAllowed;
    NSMutableDictionary<NSNumber *, NSData *> *_credentials;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _credentials = [NSMutableDictionary dictionary];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (NSError *)charon_errorForPolicy:(LAPolicy)policy
{
    if (_invalidated)
        return charon_error(LAErrorInvalidContext, @"Authentication failure.", @"Invalid context.");
    switch ((NSInteger)policy) {
    case 1:
        return charon_error(LAErrorBiometryNotAvailable, @"Biometry is not available on this device.", nil);
    case 2:
        return charon_error(LAErrorNotInteractive, @"Authentication failure.", @"Displaying the required authentication user interface is forbidden.");
    }
    NSError *error = charon_error(-1001, @"Authentication failure.", [NSString stringWithFormat:@"Unknown policy: '%ld'", (long)policy]);
    [NSException raise:NSInvalidArgumentException format:@"%@", error];
    return nil;
}

- (BOOL)canEvaluatePolicy:(LAPolicy)policy error:(NSError *__autoreleasing *)error
{
    NSError *failure = [self charon_errorForPolicy:policy];
    if (error)
        *error = failure;
    return NO;
}

- (void)evaluatePolicy:(LAPolicy)policy localizedReason:(NSString *)localizedReason reply:(void (^)(BOOL, NSError *))reply
{
    NSError *failure = [self charon_errorForPolicy:policy];
    if (localizedReason.length == 0)
        [NSException raise:NSInvalidArgumentException format:@"Non-empty localizedReason must be provided."];
    if (!reply)
        return;
    void (^handler)(BOOL, NSError *) = [reply copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        handler(NO, failure);
    });
}

- (void)evaluateAccessControl:(SecAccessControlRef)accessControl operation:(LAAccessControlOperation)operation localizedReason:(NSString *)localizedReason reply:(void (^)(BOOL, NSError *))reply
{
    NSError *failure = _invalidated ? charon_error(LAErrorInvalidContext, @"Authentication failure.", @"Invalid context.")
                                    : charon_error(LAErrorNotInteractive, @"Authentication failure.", @"Displaying the required authentication user interface is forbidden.");
    if (localizedReason.length == 0)
        [NSException raise:NSInvalidArgumentException format:@"Non-empty localizedReason must be provided."];
    if (!reply)
        return;
    void (^handler)(BOOL, NSError *) = [reply copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        handler(NO, failure);
    });
}

- (void)invalidate
{
    _invalidated = YES;
}

- (BOOL)setCredential:(NSData *)credential type:(LACredentialType)type
{
    if (type == LACredentialTypeApplicationPassword || (NSInteger)type == -3) {
        if (credential)
            _credentials[@(type)] = [credential copy];
        else
            [_credentials removeObjectForKey:@(type)];
        return YES;
    }
    if ((NSInteger)type == -1)
        return NO;
    NSError *error = charon_error(-1001, @"Authentication failure.", [NSString stringWithFormat:@"Unknown credential type: '%ld'", (long)type]);
    [NSException raise:NSInvalidArgumentException format:@"%@", error];
    return NO;
}

- (BOOL)isCredentialSet:(LACredentialType)type
{
    return _credentials[@(type)] != nil;
}

- (NSString *)localizedFallbackTitle
{
    return _localizedFallbackTitle;
}

- (void)setLocalizedFallbackTitle:(NSString *)title
{
    _localizedFallbackTitle = [title copy];
}

- (NSNumber *)maxBiometryFailures
{
    return _maxBiometryFailures;
}

- (void)setMaxBiometryFailures:(NSNumber *)failures
{
    _maxBiometryFailures = failures;
}

- (NSString *)localizedCancelTitle
{
    return _localizedCancelTitle;
}

- (void)setLocalizedCancelTitle:(NSString *)title
{
    _localizedCancelTitle = [title copy];
}

- (NSData *)evaluatedPolicyDomainState
{
    return nil;
}

- (NSTimeInterval)touchIDAuthenticationAllowableReuseDuration
{
    return _touchIDAuthenticationAllowableReuseDuration;
}

- (void)setTouchIDAuthenticationAllowableReuseDuration:(NSTimeInterval)duration
{
    _touchIDAuthenticationAllowableReuseDuration = duration;
}

- (NSString *)localizedReason
{
    return _localizedReason;
}

- (void)setLocalizedReason:(NSString *)reason
{
    _localizedReason = [reason copy];
}

- (BOOL)interactionNotAllowed
{
    return _interactionNotAllowed;
}

- (void)setInteractionNotAllowed:(BOOL)notAllowed
{
    _interactionNotAllowed = notAllowed;
}

- (LABiometryType)biometryType
{
    return LABiometryTypeNone;
}

@end
