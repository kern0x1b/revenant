#pragma clang diagnostic ignored "-Wnullability-completeness"
#import "CharonWebExtensionController.h"

/* WKWebExtensionController, its configuration, and the data-type names.
 *
 * Everything here is measured, and every answer is CHECKED on every run: the same questions are asked of
 * the system and of the port and the two answers are compared case by case, by
 * tests/backports/host/webkit/webextension-controller_test.m against what
 * webextension-controller_system.m recorded with no port code in the process. Each row's `source` names
 * the case that holds it, and the measurements are in facts/WebKit/WebExtensionController.md.
 *
 * Three things that shape this file, none of which is what the names suggest:
 *
 *   persistence is NOT derivable from the identifier. +nonPersistentConfiguration answers a nil
 *     identifier with persistent NO and +configurationWithIdentifier: answers that UUID with YES, but
 *     +defaultConfiguration answers a NIL identifier with YES as well -- so the two are two facts, the
 *     port carries both, and a port that derived one from the other would answer NO there.
 *
 *   loading an extension does NOT add it to extensions. The host still answered 0 after a real
 *     extension was built and handed to -extensionContextForExtension:, so a port that appended it
 *     would answer one more than the release.
 *
 *   the data types are the release's VALUES -- "local", "session", "synchronized" -- and not the
 *     symbols' own names. A WKWebExtensionDataType is a string a caller sends to the browser.
 *
 *   both context-creating methods answer nil without a web view:
 *       extensionContextForExtension:  0x0
 *       extensionContextForURL:        0x0
 *     and that is the answer to carry, with the reason written here rather than a nil that looks
 *     like a gap.
 *
 *   +allExtensionDataTypes holds all THREE -- local, session and synchronized -- and it is a CLASS
 *     property, which the compiler enforced when it was written as an instance one.
 *
 * What is NOT carried and why: webViewConfiguration and defaultWebsiteDataStore are real objects
 * the HOST hands out and this port has no web view to make one with, so they answer nil, which is
 * what the release answers for a configuration that has never been used to load anything.
 */

/* The two load methods below raise through the CONTEXT family's error domain, and that family owns
 * it: CharonWebExtension.h declares WKWebExtensionContextErrorDomain and WKWebExtensionContext.m
 * defines it. It is not defined a second time here. The three below are this family's alone. */
NSString *const WKWebExtensionDataRecordErrorDomain = @"WKWebExtensionDataRecordErrorDomain";
/* The VALUES are the release's, not the symbols' own names, and the difference is a caller's: a
 * WKWebExtensionDataType is a string a caller sends to the browser and gets back, and the release's three
 * are "local", "session" and "synchronized". Measured on this host -- reading the three out of
 * +[WKWebExtensionController allExtensionDataTypes] gives exactly those three -- and a port that answered
 * "WKWebExtensionDataTypeLocal" would be answering a name no browser has ever heard of. */
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
    return [[self alloc] charon_initWithIdentifier:nil persistent:NO webViewConfiguration:nil store:nil];
}

+ (instancetype)defaultConfiguration
{
    /* Measured on this host, and the two answers together are why this is not derived from the
     * identifier: +defaultConfiguration answers a NIL identifier and persistent == YES, while
     * +nonPersistentConfiguration answers a nil identifier and persistent == NO. So "no identifier" and
     * "not persistent" are two different facts and the port has to carry both. */
    return [[self alloc] charon_initWithIdentifier:nil persistent:YES webViewConfiguration:nil store:nil];
}

+ (instancetype)configurationWithIdentifier:(NSUUID *)identifier
{
    /* The host ASSERTS on anything that is not an NSUUID, measured: 'Invalid parameter not
     * satisfying: [identifier isKindOfClass:NSUUID.class]'. This checks rather than throws. */
    if (identifier != nil && ![identifier isKindOfClass:[NSUUID class]])
        return nil;
    return [[self alloc] charon_initWithIdentifier:identifier persistent:YES webViewConfiguration:nil store:nil];
}

- (instancetype)charon_initWithIdentifier:(NSUUID *)identifier
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
    /* What makes the release's answer to -[WKWebExtensionController configuration] possible: the host
     * answers an object that is not the one it was given, and the class is declared <NSCopying> in the
     * 26.2 header. A copy carries the same four facts and nothing else. */
    return [[WKWebExtensionControllerConfiguration alloc] charon_initWithIdentifier:_identifier
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
    /* Its own flag, and not a derivation from the identifier: the host's +defaultConfiguration answers a
     * NIL identifier and persistent == YES, so a configuration with no identifier can be persistent and a
     * port that read persistence off the identifier would answer NO there. Measured; see +defaultConfiguration. */
    return _persistent;
}

- (WKWebViewConfiguration *)webViewConfiguration
{
    /* The host hands out a real one here even for a non-persistent configuration, and this port has
     * no web view to make one with; nil is what the release answers for a configuration that has
     * never been used. */
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
    /* Measured: the host's set holds all three. */
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
    /* Measured: the host answers an object that is NOT the one the controller was built with --
     * -[WKWebExtensionController configuration] isEqual: the argument is NO -- and the property is
     * declared copy, so the release hands back a copy. Answering the very object it was given would be
     * the one answer a caller cannot detect, because a configuration that cannot change hands is
     * indistinguishable from one that has. */
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
    /* Measured: 0, and STILL 0 after a real extension was built and handed over. A context is what
     * puts an extension in this list, and a context needs a web view. */
    return [NSSet set];
}

- (NSSet<WKWebExtensionContext *> *)extensionContexts
{
    return _contexts;
}

- (WKWebExtensionContext *)extensionContextForExtension:(WKWebExtension *)extension
{
    /* Measured nil on the host with a real extension in hand. A context is made when an extension is
     * LOADED into a web view, and this port has none to load it into. */
    return nil;
}

- (WKWebExtensionContext *)extensionContextForURL:(NSURL *)url
{
    /* Measured nil on the host, the same reason as the form above. */
    return nil;
}

- (BOOL)loadExtensionContext:(WKWebExtensionContext *)extensionContext error:(NSError **)error
{
    /* The host CONSUMES a context here and raises on anything else, measured:
     *   NSInternalInconsistencyException, reason: 'Invalid parameter not satisfying:
     *   [extensionContext isKindOfClass:WKWebExtensionContext.class]'
     * There is no port-side context class for it to be, so this is false with the release's own
     * reason rather than an invented one. */
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
    /* No record, because there is no context: the release's own answer needs a loaded one. */
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

- (instancetype)charon_initWithIdentifier:(NSString *)identifier
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
    /* A record is made of what it was built from, and the port's has nothing in it, so the answer
     * for any set of types is the zero it was built with. */
    return 0;
}

@end

/* WKWebExtensionTabConfiguration, WKWebExtensionWindowConfiguration and WKWebExtensionMessagePort: what
 * an extension's request for a tab or a window arrives as, and the connection an extension opens to an
 * application. Three value holders, and they are in this file because this is where they arrive: the tab
 * and the window configurations are ARGUMENTS of the two delegate methods that ask for a tab and for a
 * window (WKWebExtensionControllerDelegate.h:84 and :97) and the message port arrives inside the third
 * (:203). All three are of 18.4, which is what this object already is.
 *
 * WHO BUILDS ONE, and why that decides what a member answers. Nothing in the 26.2 SDK returns any of
 * the three -- they are handed to the application, never back -- so +new and -init are NS_UNAVAILABLE in
 * the port's header as they are in the SDK's, and nothing here defines them. What the members answer is
 * therefore the release's answer for the only object a program can have: one WebKit made and a program
 * initialised, which on the host is NSObject's own -init, because the release's designated initialiser
 * is private (_init) and -init is not among the fifteen methods the host's message port declares. Every
 * answer below was measured on the host by asking it, and the differential in
 * tests/backports/host/webkit/webextension-configuration_scenario.h asks this port the same questions.
 *
 *   the two configurations: nothing was asked for, so nothing is there. No window, no parent tab and no
 *   url, the index 0, and every "should" a tab or a window is not asked to be is NO. A window's frame is
 *   {0, 0, 0, 0} and NOT the NaN the header promises of a component that was not specified (measured:
 *   the header says each component "will be NaN if not specified" and a program-made one answers
 *   zeros), and tabURLs and tabs are nil rather than empty arrays.
 *
 *   the message port: a port that was never connected is DISCONNECTED. That is what the host answers
 *   (isDisconnected is 1 for a port a program made) and it is the only answer this port can give
 *   honestly, because the extension's own JavaScript -- what opens one with
 *   browser.runtime.connectNative -- is not run here, so there is nothing for a port to be connected to.
 *
 * WHAT IS NOT HERE, and why: -sendMessage:completionHandler:, -disconnect and -disconnectWithError:
 * are absent because the release's own three raise SIGTRAP on the only port a program can make, which is
 * a port with no extension behind it. facts/WebKit/WebExtensionConfiguration.md has the measurements.
 */

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

/* Readwrite in the release's header, so the port carries the setters rather than narrowing the two
 * properties: a caller that sets a handler expects the getter to answer it. */
- (BOOL)isDisconnected
{
    return YES;
}

@end
