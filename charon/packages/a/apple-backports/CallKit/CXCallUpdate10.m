#import "CharonCallKit.h"

@implementation CXCallUpdate {
    CXHandle *_remoteHandle;
    NSString *_localizedCallerName;
    BOOL _supportsHolding;
    BOOL _supportsGrouping;
    BOOL _supportsUngrouping;
    BOOL _supportsDTMF;
    BOOL _hasVideo;
}

@dynamic remoteHandle, localizedCallerName, supportsHolding, supportsGrouping, supportsUngrouping, supportsDTMF, hasVideo;

- (CXHandle *)remoteHandle
{
    return _remoteHandle;
}

- (void)setRemoteHandle:(CXHandle *)remoteHandle
{
    _remoteHandle = [remoteHandle copy];
}

- (NSString *)localizedCallerName
{
    return _localizedCallerName;
}

- (void)setLocalizedCallerName:(NSString *)localizedCallerName
{
    _localizedCallerName = [localizedCallerName copy];
}

- (BOOL)supportsHolding
{
    return _supportsHolding;
}

- (void)setSupportsHolding:(BOOL)supportsHolding
{
    _supportsHolding = supportsHolding;
}

- (BOOL)supportsGrouping
{
    return _supportsGrouping;
}

- (void)setSupportsGrouping:(BOOL)supportsGrouping
{
    _supportsGrouping = supportsGrouping;
}

- (BOOL)supportsUngrouping
{
    return _supportsUngrouping;
}

- (void)setSupportsUngrouping:(BOOL)supportsUngrouping
{
    _supportsUngrouping = supportsUngrouping;
}

- (BOOL)supportsDTMF
{
    return _supportsDTMF;
}

- (void)setSupportsDTMF:(BOOL)supportsDTMF
{
    _supportsDTMF = supportsDTMF;
}

- (BOOL)hasVideo
{
    return _hasVideo;
}

- (void)setHasVideo:(BOOL)hasVideo
{
    _hasVideo = hasVideo;
}

- (id)copyWithZone:(NSZone *)zone
{
    CXCallUpdate *copy = [[CXCallUpdate allocWithZone:zone] init];
    copy->_remoteHandle = [_remoteHandle copy];
    copy->_localizedCallerName = [_localizedCallerName copy];
    copy->_supportsHolding = _supportsHolding;
    copy->_supportsGrouping = _supportsGrouping;
    copy->_supportsUngrouping = _supportsUngrouping;
    copy->_supportsDTMF = _supportsDTMF;
    copy->_hasVideo = _hasVideo;
    return copy;
}

// A field of an update that is nil leaves what the call already has, which is
// how an application changes the caller's name of a call without saying its
// handle again.
- (void)charon_applyOver:(CXCallUpdate *)previous
{
    if (!previous)
        return;
    _remoteHandle = _remoteHandle ?: previous->_remoteHandle;
    _localizedCallerName = _localizedCallerName ?: previous->_localizedCallerName;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p handle=%@ name=%@ video=%@>", NSStringFromClass([self class]), self,
                                      _remoteHandle.value, _localizedCallerName, _hasVideo ? @"YES" : @"NO"];
}

@end
