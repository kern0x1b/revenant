#include "../revenant_impl.h"
#import <Photos/Photos.h>

@implementation PHLivePhotoRequestOptions {
    PHImageRequestOptionsVersion _version;
    PHImageRequestOptionsDeliveryMode _deliveryMode;
    BOOL _networkAccessAllowed;
    PHAssetImageProgressHandler _progressHandler;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _version = PHImageRequestOptionsVersionCurrent;
        _deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
        _networkAccessAllowed = NO;
        _progressHandler = nil;
    }
    return self;
}

- (PHImageRequestOptionsVersion)version
{
    return _version;
}

- (void)setVersion:(PHImageRequestOptionsVersion)version
{
    _version = version;
}

- (PHImageRequestOptionsDeliveryMode)deliveryMode
{
    return _deliveryMode;
}

- (void)setDeliveryMode:(PHImageRequestOptionsDeliveryMode)deliveryMode
{
    _deliveryMode = deliveryMode;
}

- (BOOL)isNetworkAccessAllowed
{
    return _networkAccessAllowed;
}

- (void)setNetworkAccessAllowed:(BOOL)networkAccessAllowed
{
    _networkAccessAllowed = networkAccessAllowed;
}

- (PHAssetImageProgressHandler)progressHandler
{
    return _progressHandler;
}

- (void)setProgressHandler:(PHAssetImageProgressHandler)progressHandler
{
    _progressHandler = [progressHandler copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    PHLivePhotoRequestOptions *copy = [[[self class] allocWithZone:zone] init];
    copy->_version = _version;
    copy->_deliveryMode = _deliveryMode;
    copy->_networkAccessAllowed = _networkAccessAllowed;
    copy->_progressHandler = _progressHandler;
    return copy;
}

@end