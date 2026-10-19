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

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
