// AVContentKeySpecifier145.m - AVContentKeySpecifier as of 14.5: the name of one content key, which is the key
// system, an identifier and the options of the key. It is a value. A content key request names it, and a
// content key session (not carried on 6.1.3, see facts/AVFoundation/ContentKeyValues.md) is what hands one out;
// the object here is the one an application builds for itself, and what the host builds with the same factory.
//
// Every answer below is the host's, measured by tests/backports/host/avf-contentkey-values (the same probe run
// against this Mac's framework and against this file renamed). The host checks nothing: a nil key system, a nil
// identifier, an identifier that is not a string and a key system no framework knows are all kept as given. The
// host copies the three values it stores (a mutable string or dictionary passed in changes nothing already made),
// and its -copy answers the same object, since the class is immutable.
#import <AVFoundation/AVContentKeySession.h>
#import <Foundation/Foundation.h>

@implementation AVContentKeySpecifier {
    NSString *_keySystem;
    id _identifier;
    NSDictionary<NSString *, id> *_options;
}

+ (instancetype)contentKeySpecifierForKeySystem:(NSString *)keySystem
                                     identifier:(id)identifier
                                        options:(NSDictionary<NSString *, id> *)options
{
    return [[self alloc] initForKeySystem:keySystem identifier:identifier options:options];
}

- (instancetype)initForKeySystem:(NSString *)keySystem
                      identifier:(id)identifier
                         options:(NSDictionary<NSString *, id> *)options
{
    self = [super init];
    if (self) {
        _keySystem = [keySystem copy];
        _identifier = [identifier copy];
        _options = [options copy];
    }
    return self;
}

- (NSString *)keySystem
{
    return _keySystem;
}

- (id)identifier
{
    return _identifier;
}

- (NSDictionary<NSString *, id> *)options
{
    return _options;
}

// The object is immutable, so a copy is the same object, as the host's is.
- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
