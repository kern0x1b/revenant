#pragma clang diagnostic ignored "-Wnullability-completeness"
#import "RevenantWebExtensionController.h"

NSString *const WKWebExtensionDataRecordErrorDomain = @"WKWebExtensionDataRecordErrorDomain";
NSString *const WKWebExtensionDataTypeLocal = @"local";
NSString *const WKWebExtensionDataTypeSession = @"session";
NSString *const WKWebExtensionDataTypeSynchronized = @"synchronized";

@implementation WKWebExtensionControllerConfiguration {
    NSUUID *_identifier;
    BOOL _persistent;
    WKWebViewConfiguration *_webViewConfiguration;
    WKWebsiteDataStore *_websiteDataStore;
}

+ (instancetype)nonPersistentConfiguration
{
    return [[self alloc] revenant_initWithIdentifier:nil persistent:NO webViewConfiguration:nil store:nil];
}

+ (instancetype)defaultConfiguration
{
    return [[self alloc] revenant_initWithIdentifier:nil persistent:YES webViewConfiguration:nil store:nil];
}

+ (instancetype)configurationWithIdentifier:(NSUUID *)identifier
{
    if (identifier != nil && ![identifier isKindOfClass:[NSUUID class]])
        return nil;
    return [[self alloc] revenant_initWithIdentifier:identifier persistent:YES webViewConfiguration:nil store:nil];
}

- (instancetype)revenant_initWithIdentifier:(NSUUID *)identifier
                                persistent:(BOOL)persistent
                     webViewConfiguration:(WKWebViewConfiguration *)webViewConfiguration
                                   store:(WKWebsiteDataStore *)store
{
    if ((self = [super init])) {
        _identifier = identifier;
        _persistent = persistent;
        _webViewConfiguration = webViewConfiguration;
        _websiteDataStore = store;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[WKWebExtensionControllerConfiguration alloc] revenant_initWithIdentifier:_identifier
                                                                       persistent:_persistent
                                                            webViewConfiguration:_webViewConfiguration
                                                                          store:_websiteDataStore];
}

- (NSUUID *)identifier
{
    return _identifier;
}

- (BOOL)isPersistent
{
    return _persistent;
}

- (WKWebViewConfiguration *)webViewConfiguration
{
    return _webViewConfiguration;
}

- (WKWebsiteDataStore *)defaultWebsiteDataStore
{
    return _websiteDataStore;
}

- (void)setDefaultWebsiteDataStore:(WKWebsiteDataStore *)defaultWebsiteDataStore
{
    _websiteDataStore = defaultWebsiteDataStore;
}

- (void)setWebViewConfiguration:(WKWebViewConfiguration *)webViewConfiguration
{
    _webViewConfiguration = [webViewConfiguration copy];
}

@end

@implementation WKWebExtensionController {
    WKWebExtensionControllerConfiguration *_configuration;
    __weak id<WKWebExtensionControllerDelegate> _delegate;
    NSSet<WKWebExtensionContext *> *_contexts;
}

+ (NSSet<WKWebExtensionDataType> *)allExtensionDataTypes
{
    static NSSet *types;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        types = [NSSet setWithObjects:WKWebExtensionDataTypeLocal, WKWebExtensionDataTypeSession,
                                       WKWebExtensionDataTypeSynchronized, nil];
    });
    return types;
}

- (instancetype)initWithConfiguration:(WKWebExtensionControllerConfiguration *)configuration
{
    if ((self = [super init])) {
        _configuration = configuration;
        _contexts = [NSSet set];
    }
    return self;
}

- (WKWebExtensionControllerConfiguration *)configuration
{
    return [_configuration copy];
}

- (id<WKWebExtensionControllerDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<WKWebExtensionControllerDelegate>)delegate
{
    _delegate = delegate;
}

- (NSSet<WKWebExtension *> *)extensions
{
    return [NSSet set];
}

- (NSSet<WKWebExtensionContext *> *)extensionContexts
{
    return _contexts;
}

- (WKWebExtensionContext *)extensionContextForExtension:(WKWebExtension *)extension
{
    return nil;
}

- (WKWebExtensionContext *)extensionContextForURL:(NSURL *)url
{
    return nil;
}

- (BOOL)loadExtensionContext:(WKWebExtensionContext *)extensionContext error:(NSError **)error
{
    if (error)
        *error = [NSError errorWithDomain:WKWebExtensionContextErrorDomain
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: @"a context cannot be loaded: this port carries no web view to load it into"}];
    return NO;
}

- (BOOL)unloadExtensionContext:(WKWebExtensionContext *)extensionContext error:(NSError **)error
{
    if (error)
        *error = [NSError errorWithDomain:WKWebExtensionContextErrorDomain
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: @"a context cannot be unloaded: none was ever loaded"}];
    return NO;
}

- (void)fetchDataRecordOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes
           forExtensionContext:(WKWebExtensionContext *)extensionContext
             completionHandler:(void (^)(WKWebExtensionDataRecord *dataRecord, NSError *error))completionHandler
{
    if (completionHandler)
        completionHandler(nil, [NSError errorWithDomain:WKWebExtensionDataRecordErrorDomain
                                                   code:1
                                               userInfo:@{NSLocalizedDescriptionKey: @"no context, so no data record"}]);
}

- (void)fetchDataRecordsOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes
             completionHandler:(void (^)(NSArray<WKWebExtensionDataRecord *> *dataRecords, NSError *error))completionHandler
{
    if (completionHandler)
        completionHandler(@[], nil);
}

- (void)removeDataOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes
          fromDataRecords:(NSArray<WKWebExtensionDataRecord *> *)dataRecords
       completionHandler:(void (^)(NSError *error))completionHandler
{
    if (completionHandler)
        completionHandler(nil);
}

@end

@implementation WKWebExtensionDataRecord {
    NSString *_uniqueIdentifier;
    NSString *_displayName;
    NSSet<WKWebExtensionDataType> *_containedDataTypes;
    NSArray<NSError *> *_errors;
    NSUInteger _totalSizeInBytes;
}

- (instancetype)revenant_initWithIdentifier:(NSString *)identifier
                              displayName:(NSString *)displayName
                       containedDataTypes:(NSSet<WKWebExtensionDataType> *)containedDataTypes
                                    errors:(NSArray<NSError *> *)errors
{
    if ((self = [super init])) {
        _uniqueIdentifier = identifier;
        _displayName = [displayName copy];
        _containedDataTypes = [containedDataTypes copy] ?: [NSSet set];
        _errors = [errors copy] ?: @[];
        _totalSizeInBytes = 0;
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    return _uniqueIdentifier;
}

- (NSString *)displayName
{
    return _displayName;
}

- (NSSet<WKWebExtensionDataType> *)containedDataTypes
{
    return _containedDataTypes;
}

- (NSArray<NSError *> *)errors
{
    return _errors;
}

- (NSUInteger)totalSizeInBytes
{
    return _totalSizeInBytes;
}

- (NSUInteger)sizeInBytesOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes
{
    return 0;
}

@end

@implementation WKWebExtensionTabConfiguration {
    __weak id<WKWebExtensionWindow> _window;
    __weak id<WKWebExtensionTab> _parentTab;
    NSUInteger _index;
    NSURL *_url;
    BOOL _shouldBeActive;
    BOOL _shouldAddToSelection;
    BOOL _shouldBePinned;
    BOOL _shouldBeMuted;
    BOOL _shouldReaderModeBeActive;
}

- (id<WKWebExtensionWindow>)window
{
    return _window;
}

- (NSUInteger)index
{
    return _index;
}

- (id<WKWebExtensionTab>)parentTab
{
    return _parentTab;
}

- (NSURL *)url
{
    return _url;
}

- (BOOL)shouldBeActive
{
    return _shouldBeActive;
}

- (BOOL)shouldAddToSelection
{
    return _shouldAddToSelection;
}

- (BOOL)shouldBePinned
{
    return _shouldBePinned;
}

- (BOOL)shouldBeMuted
{
    return _shouldBeMuted;
}

- (BOOL)shouldReaderModeBeActive
{
    return _shouldReaderModeBeActive;
}

@end

@implementation WKWebExtensionWindowConfiguration {
    WKWebExtensionWindowType _windowType;
    WKWebExtensionWindowState _windowState;
    CGRect _frame;
    NSArray<NSURL *> *_tabURLs;
    NSArray<id<WKWebExtensionTab>> *_tabs;
    BOOL _shouldBeFocused;
    BOOL _shouldBePrivate;
}

- (WKWebExtensionWindowType)windowType
{
    return _windowType;
}

- (WKWebExtensionWindowState)windowState
{
    return _windowState;
}

- (CGRect)frame
{
    return _frame;
}

- (NSArray<NSURL *> *)tabURLs
{
    return _tabURLs;
}

- (NSArray<id<WKWebExtensionTab>> *)tabs
{
    return _tabs;
}

- (BOOL)shouldBeFocused
{
    return _shouldBeFocused;
}

- (BOOL)shouldBePrivate
{
    return _shouldBePrivate;
}

@end

NSString *const WKWebExtensionMessagePortErrorDomain = @"WKWebExtensionMessagePortErrorDomain";

@implementation WKWebExtensionMessagePort {
    NSString *_applicationIdentifier;
    void (^_messageHandler)(id, NSError *);
    void (^_disconnectHandler)(NSError *);
}

- (NSString *)applicationIdentifier
{
    return _applicationIdentifier;
}

- (void (^)(id, NSError *))messageHandler
{
    return _messageHandler;
}

- (void)setMessageHandler:(void (^)(id, NSError *))messageHandler
{
    _messageHandler = [messageHandler copy];
}

- (void (^)(NSError *))disconnectHandler
{
    return _disconnectHandler;
}

- (void)setDisconnectHandler:(void (^)(NSError *))disconnectHandler
{
    _disconnectHandler = [disconnectHandler copy];
}

- (BOOL)isDisconnected
{
    return YES;
}

@end
