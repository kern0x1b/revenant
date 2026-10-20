#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPMediaPlaylistCreationMetadata
{
    NSString *_authorDisplayName;
}

@synthesize name = _name;
@synthesize descriptionText = _descriptionText;

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        _name = [name copy];
    }
    return self;
}

- (NSString *)name { return _name; }
- (NSString *)descriptionText { return _descriptionText; }

- (NSString *)authorDisplayName {
    if (!_authorDisplayName) {
        NSDictionary *info = [[NSBundle mainBundle] localizedInfoDictionary];
        NSString *display = info[@"CFBundleDisplayName"];
        if (![display isKindOfClass:[NSString class]] || display.length == 0) {
            display = info[@"CFBundleName"];
        }
        if (![display isKindOfClass:[NSString class]] || display.length == 0) {
            display = [[NSProcessInfo processInfo] processName];
        }
        _authorDisplayName = [display copy];
    }
    return _authorDisplayName;
}

- (void)setAuthorDisplayName:(NSString *)authorDisplayName {
    _authorDisplayName = [authorDisplayName copy];
}

@end
