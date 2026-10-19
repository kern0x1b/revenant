#import "CharonCallKit.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation CXProviderConfiguration {
    NSString *_localizedName;
    NSString *_ringtoneSound;
    NSData *_iconTemplateImageData;
    NSUInteger _maximumCallGroups;
    NSUInteger _maximumCallsPerCallGroup;
    BOOL _includesCallsInRecents;
    BOOL _supportsVideo;
    NSSet<NSNumber *> *_supportedHandleTypes;
}

@dynamic localizedName, ringtoneSound, iconTemplateImageData, maximumCallGroups, maximumCallsPerCallGroup, includesCallsInRecents, supportsVideo, supportedHandleTypes;

- (instancetype)init
{
    if ((self = [super init])) {
        _maximumCallGroups = 2;
        _maximumCallsPerCallGroup = 5;
        _includesCallsInRecents = YES;
        _supportsVideo = NO;
        _supportedHandleTypes = [NSSet set];
    }
    return self;
}

- (instancetype)initWithLocalizedName:(NSString *)localizedName
{
    if ((self = [self init]))
        _localizedName = [localizedName copy];
    return self;
}

- (NSString *)localizedName
{
    return _localizedName;
}

- (NSString *)ringtoneSound
{
    return _ringtoneSound;
}

- (void)setRingtoneSound:(NSString *)ringtoneSound
{
    _ringtoneSound = ringtoneSound;
}

- (NSData *)iconTemplateImageData
{
    return _iconTemplateImageData;
}

- (void)setIconTemplateImageData:(NSData *)iconTemplateImageData
{
    _iconTemplateImageData = [iconTemplateImageData copy];
}

- (NSUInteger)maximumCallGroups
{
    return _maximumCallGroups;
}

- (void)setMaximumCallGroups:(NSUInteger)maximumCallGroups
{
    _maximumCallGroups = maximumCallGroups;
}

- (NSUInteger)maximumCallsPerCallGroup
{
    return _maximumCallsPerCallGroup;
}

- (void)setMaximumCallsPerCallGroup:(NSUInteger)maximumCallsPerCallGroup
{
    _maximumCallsPerCallGroup = maximumCallsPerCallGroup;
}

- (BOOL)includesCallsInRecents
{
    return _includesCallsInRecents;
}

- (void)setIncludesCallsInRecents:(BOOL)includesCallsInRecents
{
    _includesCallsInRecents = includesCallsInRecents;
}

- (BOOL)supportsVideo
{
    return _supportsVideo;
}

- (void)setSupportsVideo:(BOOL)supportsVideo
{
    _supportsVideo = supportsVideo;
}

- (NSSet<NSNumber *> *)supportedHandleTypes
{
    return _supportedHandleTypes;
}

- (void)setSupportedHandleTypes:(NSSet<NSNumber *> *)supportedHandleTypes
{
    _supportedHandleTypes = [supportedHandleTypes copy] ?: [NSSet set];
}

- (id)copyWithZone:(NSZone *)zone
{
    CXProviderConfiguration *copy = [[CXProviderConfiguration allocWithZone:zone] init];
    copy->_localizedName = [_localizedName copy];
    copy->_ringtoneSound = _ringtoneSound;
    copy->_iconTemplateImageData = [_iconTemplateImageData copy];
    copy->_maximumCallGroups = _maximumCallGroups;
    copy->_maximumCallsPerCallGroup = _maximumCallsPerCallGroup;
    copy->_includesCallsInRecents = _includesCallsInRecents;
    copy->_supportsVideo = _supportsVideo;
    copy->_supportedHandleTypes = [_supportedHandleTypes copy];
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p name=%@ groups=%lu perGroup=%lu video=%@>", NSStringFromClass([self class]), self,
                                      _localizedName, (unsigned long)_maximumCallGroups, (unsigned long)_maximumCallsPerCallGroup,
                                      _supportsVideo ? @"YES" : @"NO"];
}

@end
