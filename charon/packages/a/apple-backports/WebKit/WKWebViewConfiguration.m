#import "CharonWebKit.h"

NSString *const WKErrorDomain = @"WKErrorDomain";

@implementation WKProcessPool

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end

@implementation WKPreferences {
    CGFloat _minimumFontSize;
    BOOL _javaScriptCanOpenWindowsAutomatically;
    BOOL _javaScriptEnabled;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _javaScriptEnabled = YES;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (CGFloat)minimumFontSize
{
    return _minimumFontSize;
}

- (void)setMinimumFontSize:(CGFloat)size
{
    _minimumFontSize = size;
}

- (BOOL)javaScriptCanOpenWindowsAutomatically
{
    return _javaScriptCanOpenWindowsAutomatically;
}

- (void)setJavaScriptCanOpenWindowsAutomatically:(BOOL)allowed
{
    _javaScriptCanOpenWindowsAutomatically = allowed;
}

- (BOOL)javaScriptEnabled
{
    return _javaScriptEnabled;
}

- (void)setJavaScriptEnabled:(BOOL)enabled
{
    _javaScriptEnabled = enabled;
}

@end

@implementation WKWebViewConfiguration {
    WKProcessPool *_processPool;
    WKPreferences *_preferences;
    WKUserContentController *_userContentController;
    WKWebsiteDataStore *_websiteDataStore;
    BOOL _suppressesIncrementalRendering;
    NSString *_applicationNameForUserAgent;
    BOOL _allowsAirPlayForMediaPlayback;
    BOOL _allowsInlineMediaPlayback;
    WKAudiovisualMediaTypes _mediaTypesRequiringUserActionForPlayback;
    WKDataDetectorTypes _dataDetectorTypes;
    BOOL _allowsPictureInPictureMediaPlayback;
    WKSelectionGranularity _selectionGranularity;
    BOOL _ignoresViewportScaleLimits;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _processPool = [WKProcessPool alloc];
        _preferences = [[WKPreferences alloc] init];
        _userContentController = [[WKUserContentController alloc] init];
        _websiteDataStore = [WKWebsiteDataStore defaultDataStore];
        _allowsAirPlayForMediaPlayback = YES;
        _allowsInlineMediaPlayback = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
        _mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
        _allowsPictureInPictureMediaPlayback = YES;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (id)copyWithZone:(NSZone *)zone
{
    WKWebViewConfiguration *copy = [[[self class] alloc] init];
    copy->_processPool = _processPool;
    copy->_preferences = _preferences;
    copy->_userContentController = _userContentController;
    copy->_websiteDataStore = _websiteDataStore;
    copy->_suppressesIncrementalRendering = _suppressesIncrementalRendering;
    copy->_applicationNameForUserAgent = [_applicationNameForUserAgent copy];
    copy->_allowsAirPlayForMediaPlayback = _allowsAirPlayForMediaPlayback;
    copy->_allowsInlineMediaPlayback = _allowsInlineMediaPlayback;
    copy->_mediaTypesRequiringUserActionForPlayback = _mediaTypesRequiringUserActionForPlayback;
    copy->_dataDetectorTypes = _dataDetectorTypes;
    copy->_allowsPictureInPictureMediaPlayback = _allowsPictureInPictureMediaPlayback;
    copy->_selectionGranularity = _selectionGranularity;
    copy->_ignoresViewportScaleLimits = _ignoresViewportScaleLimits;
    return copy;
}

- (WKProcessPool *)processPool
{
    return _processPool;
}

- (void)setProcessPool:(WKProcessPool *)pool
{
    _processPool = pool;
}

- (WKPreferences *)preferences
{
    return _preferences;
}

- (void)setPreferences:(WKPreferences *)preferences
{
    _preferences = preferences;
}

- (WKUserContentController *)userContentController
{
    return _userContentController;
}

- (void)setUserContentController:(WKUserContentController *)controller
{
    _userContentController = controller;
}

- (WKWebsiteDataStore *)websiteDataStore
{
    return _websiteDataStore;
}

- (void)setWebsiteDataStore:(WKWebsiteDataStore *)store
{
    _websiteDataStore = store;
}

- (BOOL)suppressesIncrementalRendering
{
    return _suppressesIncrementalRendering;
}

- (void)setSuppressesIncrementalRendering:(BOOL)suppresses
{
    _suppressesIncrementalRendering = suppresses;
}

- (NSString *)applicationNameForUserAgent
{
    return _applicationNameForUserAgent;
}

- (void)setApplicationNameForUserAgent:(NSString *)name
{
    _applicationNameForUserAgent = [name copy];
}

- (BOOL)allowsAirPlayForMediaPlayback
{
    return _allowsAirPlayForMediaPlayback;
}

- (void)setAllowsAirPlayForMediaPlayback:(BOOL)allows
{
    _allowsAirPlayForMediaPlayback = allows;
}

- (BOOL)allowsInlineMediaPlayback
{
    return _allowsInlineMediaPlayback;
}

- (void)setAllowsInlineMediaPlayback:(BOOL)allows
{
    _allowsInlineMediaPlayback = allows;
}

- (WKAudiovisualMediaTypes)mediaTypesRequiringUserActionForPlayback
{
    return _mediaTypesRequiringUserActionForPlayback;
}

- (void)setMediaTypesRequiringUserActionForPlayback:(WKAudiovisualMediaTypes)types
{
    _mediaTypesRequiringUserActionForPlayback = types;
}

- (WKDataDetectorTypes)dataDetectorTypes
{
    return _dataDetectorTypes;
}

- (void)setDataDetectorTypes:(WKDataDetectorTypes)types
{
    _dataDetectorTypes = types;
}

- (BOOL)allowsPictureInPictureMediaPlayback
{
    return _allowsPictureInPictureMediaPlayback;
}

- (void)setAllowsPictureInPictureMediaPlayback:(BOOL)allows
{
    _allowsPictureInPictureMediaPlayback = allows;
}

- (WKSelectionGranularity)selectionGranularity
{
    return _selectionGranularity;
}

- (void)setSelectionGranularity:(WKSelectionGranularity)granularity
{
    _selectionGranularity = granularity;
}

- (BOOL)ignoresViewportScaleLimits
{
    return _ignoresViewportScaleLimits;
}

- (void)setIgnoresViewportScaleLimits:(BOOL)ignores
{
    _ignoresViewportScaleLimits = ignores;
}

@end
