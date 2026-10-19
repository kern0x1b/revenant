#import "CharonWebKit.h"
#import <objc/runtime.h>

@implementation WKWebpagePreferences {
@private
    WKContentMode _preferredContentMode;
}

- (instancetype)init
{
    if ((self = [super init]))
        _preferredContentMode = WKContentModeRecommended;
    return self;
}

- (WKContentMode)preferredContentMode
{
    return _preferredContentMode;
}

- (void)setPreferredContentMode:(WKContentMode)preferredContentMode
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"WKWebpagePreferences: this release renders every page with its own mobile WebKit, so a preferred content mode is kept and changes nothing.");
    });
    _preferredContentMode = preferredContentMode;
}

@end

static const char charon_default_preferences_key;

@implementation WKWebViewConfiguration (CharonWebpagePreferences13)

- (WKWebpagePreferences *)defaultWebpagePreferences
{
    @synchronized (self) {
        WKWebpagePreferences *preferences = objc_getAssociatedObject(self, &charon_default_preferences_key);
        if (!preferences) {
            preferences = [[WKWebpagePreferences alloc] init];
            objc_setAssociatedObject(self, &charon_default_preferences_key, preferences, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return preferences;
    }
}

- (void)setDefaultWebpagePreferences:(WKWebpagePreferences *)defaultWebpagePreferences
{
    @synchronized (self) {
        objc_setAssociatedObject(self, &charon_default_preferences_key, defaultWebpagePreferences ?: [[WKWebpagePreferences alloc] init], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@end
