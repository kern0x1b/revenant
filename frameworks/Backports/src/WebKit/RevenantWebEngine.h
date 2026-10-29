#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *const RevenantWebEngineErrorDomain;
extern NSString *const RevenantWebActionNavigationTypeKey;

NSString *RevenantWebEngineRoot(void);
BOOL RevenantWebEngineLoad(NSError **error);
void *RevenantWebEngineSymbol(const char *name);
Class RevenantWebEngineClass(NSString *name);

@protocol RevenantEngineDataSource <NSObject>
@property (nonatomic, readonly) NSURLRequest *request;
@end

@protocol RevenantEngineFrame <NSObject>
@property (nonatomic, readonly) id<RevenantEngineDataSource> dataSource;
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)encodingName baseURL:(NSURL *)baseURL;
- (void)stopLoading;
- (void)reload;
@end

@protocol RevenantEnginePreferences <NSObject>
- (void)setJavaScriptEnabled:(BOOL)enabled;
- (void)setDatabasesEnabled:(BOOL)enabled;
- (void)setLocalStorageEnabled:(BOOL)enabled;
- (void)setAcceleratedCompositingEnabled:(BOOL)enabled;
- (void)setVideoPlaybackRequiresUserGesture:(BOOL)required;
- (void)setAudioPlaybackRequiresUserGesture:(BOOL)required;
- (void)_setTextAutosizingEnabled:(BOOL)enabled;
@end

@protocol RevenantEngineView <NSObject>
- (instancetype)initWithFrame:(CGRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName;
@property (nonatomic, readonly) id<RevenantEngineFrame> mainFrame;
- (BOOL)goBack;
- (BOOL)goForward;
- (void)reload:(id)sender;
- (void)stopLoading:(id)sender;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
- (void)setFrameLoadDelegate:(id)delegate;
- (void)setPolicyDelegate:(id)delegate;
- (void)setUIDelegate:(id)delegate;
- (void)_setFormDelegate:(id)delegate;
- (void)_setUIKitDelegate:(id)delegate;
- (void)setCustomUserAgent:(NSString *)agent;
- (id<RevenantEnginePreferences>)preferences;
@end

@protocol RevenantPolicyListener <NSObject>
- (void)use;
- (void)ignore;
@end

@protocol RevenantEngineWindow <NSObject>
- (instancetype)initWithLayer:(CALayer *)hostLayer;
- (void)setScreenSize:(CGSize)size;
- (void)setAvailableScreenSize:(CGSize)size;
- (void)setScreenScale:(CGFloat)scale;
- (void)setVisible:(BOOL)visible;
- (void)setTilesOpaque:(BOOL)opaque;
- (void)setTilingMode:(NSInteger)mode;
- (void)setContentView:(id)view;
- (void)setExposedScrollViewRect:(CGRect)rect;
@end
