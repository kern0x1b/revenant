#import "CharonNEHotspot.h"

@implementation NEHotspotConfiguration {
    NSString *_SSID;
    NSString *_SSIDPrefix;
    NSString *_passphrase;
    BOOL _isWEP;
    BOOL _joinOnce;
    NSNumber *_lifeTimeInDays;
    BOOL _hidden;
    NEHotspotEAPSettings *_eapSettings;
    NEHotspotHS20Settings *_hs20Settings;
}

- (instancetype)initWithSSID:(NSString *)SSID
{
    self = [super init];
    if (self) {
        _SSID = [SSID copy];
        _SSIDPrefix = @"";
    }
    return self;
}

- (instancetype)initWithSSID:(NSString *)SSID passphrase:(NSString *)passphrase isWEP:(BOOL)isWEP
{
    self = [self initWithSSID:SSID];
    if (self) {
        _passphrase = [passphrase copy];
        _isWEP = isWEP;
    }
    return self;
}

- (instancetype)initWithSSIDPrefix:(NSString *)SSIDPrefix
{
    self = [super init];
    if (self) {
        _SSID = @"";
        _SSIDPrefix = [SSIDPrefix copy];
    }
    return self;
}

- (instancetype)initWithSSIDPrefix:(NSString *)SSIDPrefix passphrase:(NSString *)passphrase isWEP:(BOOL)isWEP
{
    self = [self initWithSSIDPrefix:SSIDPrefix];
    if (self) {
        _passphrase = [passphrase copy];
        _isWEP = isWEP;
    }
    return self;
}

- (instancetype)initWithSSID:(NSString *)SSID eapSettings:(NEHotspotEAPSettings *)eapSettings
{
    self = [super init];
    if (self) {
        _SSID = [SSID copy];
        _eapSettings = [eapSettings copy];
    }
    return self;
}

- (instancetype)initWithHS20Settings:(NEHotspotHS20Settings *)hs20Settings eapSettings:(NEHotspotEAPSettings *)eapSettings
{
    self = [super init];
    if (self) {
        _SSID = @"";
        _hs20Settings = [hs20Settings copy];
        _eapSettings = [eapSettings copy];
    }
    return self;
}

- (NSString *)SSID
{
    return _SSID;
}

- (NSString *)SSIDPrefix
{
    return _SSIDPrefix;
}

- (BOOL)joinOnce
{
    return _joinOnce;
}

- (void)setJoinOnce:(BOOL)joinOnce
{
    _joinOnce = joinOnce;
}

- (NSNumber *)lifeTimeInDays
{
    return _lifeTimeInDays;
}

- (void)setLifeTimeInDays:(NSNumber *)lifeTimeInDays
{
    _lifeTimeInDays = [lifeTimeInDays copy];
}

- (BOOL)hidden
{
    return _hidden;
}

- (void)setHidden:(BOOL)hidden
{
    _hidden = hidden;
}

- (id)copyWithZone:(NSZone *)zone
{
    NEHotspotConfiguration *copy = [[NEHotspotConfiguration allocWithZone:zone] init];
    copy->_SSID = [_SSID copy];
    copy->_SSIDPrefix = [_SSIDPrefix copy];
    copy->_passphrase = [_passphrase copy];
    copy->_isWEP = _isWEP;
    copy->_joinOnce = _joinOnce;
    copy->_lifeTimeInDays = [_lifeTimeInDays copy];
    copy->_hidden = _hidden;
    copy->_eapSettings = [_eapSettings copy];
    copy->_hs20Settings = [_hs20Settings copy];
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _SSID = [[coder decodeObjectOfClass:[NSString class] forKey:@"SSID"] copy];
        _SSIDPrefix = [[coder decodeObjectOfClass:[NSString class] forKey:@"SSIDPrefix"] copy];
        _joinOnce = [coder decodeBoolForKey:@"joinOnce"];
        _lifeTimeInDays = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"lifeTimeInDays"] copy];
        _hidden = [coder decodeBoolForKey:@"hidden"];
        _eapSettings = [coder decodeObjectOfClass:[NEHotspotEAPSettings class] forKey:@"eapSettings"];
        _hs20Settings = [coder decodeObjectOfClass:[NEHotspotHS20Settings class] forKey:@"hs20Settings"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_SSID forKey:@"SSID"];
    [coder encodeObject:_SSIDPrefix forKey:@"SSIDPrefix"];
    [coder encodeBool:_joinOnce forKey:@"joinOnce"];
    [coder encodeObject:_lifeTimeInDays forKey:@"lifeTimeInDays"];
    [coder encodeBool:_hidden forKey:@"hidden"];
    [coder encodeObject:_eapSettings forKey:@"eapSettings"];
    [coder encodeObject:_hs20Settings forKey:@"hs20Settings"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
