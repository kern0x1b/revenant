#import "RevenantWebKit.h"
#import <objc/runtime.h>

@implementation WKWebpagePreferences {
@private
    WKContentMode _preferredContentMode;
    BOOL _allowsContentJavaScript;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _preferredContentMode = WKContentModeRecommended;
        _allowsContentJavaScript = YES;
    }
    return self;
}

- (BOOL)allowsContentJavaScript
{
    return _allowsContentJavaScript;
}

- (void)setAllowsContentJavaScript:(BOOL)allowsContentJavaScript
{
    if (!allowsContentJavaScript) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"WKWebpagePreferences: this engine cannot switch JavaScript off for one page, so a page runs with JavaScript whatever allowsContentJavaScript says.");
        });
    }
    _allowsContentJavaScript = allowsContentJavaScript;
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

static const char revenant_default_preferences_key;

@implementation WKWebViewConfiguration (RevenantWebpagePreferences13)

- (WKWebpagePreferences *)defaultWebpagePreferences
{
    @synchronized (self) {
        WKWebpagePreferences *preferences = objc_getAssociatedObject(self, &revenant_default_preferences_key);
        if (!preferences) {
            preferences = [[WKWebpagePreferences alloc] init];
            objc_setAssociatedObject(self, &revenant_default_preferences_key, preferences, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return preferences;
    }
}

- (void)setDefaultWebpagePreferences:(WKWebpagePreferences *)defaultWebpagePreferences
{
    @synchronized (self) {
        objc_setAssociatedObject(self, &revenant_default_preferences_key, defaultWebpagePreferences ?: [[WKWebpagePreferences alloc] init], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@end
