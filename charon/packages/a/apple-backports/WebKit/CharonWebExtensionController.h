// CharonWebExtensionController.h -- the WebKit web-extension CONTROLLER family of iOS 18.4, as
// this port carries it. The 16.4 SDK this package compiles against has no WebKit web-extension API
// at all, so every declaration below is transcribed from the 26.2 SDK's WKWebExtensionController.h,
// WKWebExtensionControllerConfiguration.h, WKWebExtensionDataRecord.h and WKWebExtensionDataType.h:
// the classes, their members with their kinds and types, and API_AVAILABLE(ios(18.4)). Facts only.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
// WKWebExtension, WKWebExtensionContext and WKWebExtensionContextErrorDomain are the context family's,
// declared by CharonWebExtension.h and defined by WKWebExtensionContext.m. This header uses all three,
// so it imports that one rather than declaring the domain a second time.
#import "CharonWebExtension.h"

@class WKWebExtension;
@class WKWebExtensionContext;
@class WKWebExtensionController;
@class WKWebExtensionDataRecord;
@protocol WKWebExtensionTab;

// The host's own WebKit is newer than the 16.4 SDK this package builds against and already declares
// everything between here and the matching #endif, so a host comparison compiles with
// -DCHARON_HOST_DIFFERENTIAL and takes the HOST's declarations instead of ours, with the class names
// prefixed by renames.sh so the port's classes and Apple's live side by side in one process. This is the
// guard MetricKit's CharonMetricKit.h and VideoToolbox's CharonVideoToolbox.h use for exactly this
// reason. The Charon* categories below are the port's own and are declared either way: the port
// implements them, so a host build needs them to compile, and the differential calls them.
#ifndef CHARON_HOST_DIFFERENTIAL

typedef NSString *WKWebExtensionDataType NS_TYPED_ENUM;

// the three names, as the release's own NS_TYPED_ENUM carries them
extern WKWebExtensionDataType const WKWebExtensionDataTypeLocal;
extern WKWebExtensionDataType const WKWebExtensionDataTypeSession;
extern WKWebExtensionDataType const WKWebExtensionDataTypeSynchronized;

extern NSString *const WKWebExtensionDataRecordErrorDomain;
typedef NS_ENUM(NSInteger, WKWebExtensionDataRecordError) {
    WKWebExtensionDataRecordErrorUnknown = 1,
} API_AVAILABLE(ios(18.4));

// <NSCopying> because the 26.2 header declares it (WKWebExtensionControllerConfiguration.h:41, alongside
// NSSecureCoding) and because -[WKWebExtensionController configuration] hands back a copy, measured. The
// port declares the one protocol it implements: NSSecureCoding is not claimed, because nothing here
// encodes or decodes a configuration and claiming it would be a promise with no method behind it.
@interface WKWebExtensionControllerConfiguration : NSObject <NSCopying>
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)defaultConfiguration;
+ (instancetype)nonPersistentConfiguration;
+ (nullable instancetype)configurationWithIdentifier:(NSUUID *)identifier;
@property (nonatomic, readonly, getter=isPersistent) BOOL persistent;
@property (nonatomic, nullable, readonly, copy) NSUUID *identifier;
@property (nonatomic, null_resettable, copy) WKWebViewConfiguration *webViewConfiguration;
@property (nonatomic, null_resettable, retain) WKWebsiteDataStore *defaultWebsiteDataStore;
@end

@protocol WKWebExtensionControllerDelegate <NSObject>
@end

@interface WKWebExtensionController : NSObject
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithConfiguration:(WKWebExtensionControllerConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
@property (nonatomic, weak) id<WKWebExtensionControllerDelegate> delegate;
@property (nonatomic, readonly, copy) WKWebExtensionControllerConfiguration *configuration;
- (BOOL)loadExtensionContext:(WKWebExtensionContext *)extensionContext error:(NSError **)error;
- (BOOL)unloadExtensionContext:(WKWebExtensionContext *)extensionContext error:(NSError **)error;
- (nullable WKWebExtensionContext *)extensionContextForExtension:(WKWebExtension *)extension;
- (nullable WKWebExtensionContext *)extensionContextForURL:(NSURL *)URL;
@property (nonatomic, readonly, copy) NSSet<WKWebExtension *> *extensions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionContext *> *extensionContexts;
@property (class, nonatomic, readonly, copy) NSSet<WKWebExtensionDataType> *allExtensionDataTypes;
- (void)fetchDataRecordOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes
           forExtensionContext:(WKWebExtensionContext *)extensionContext
             completionHandler:(void (^)(WKWebExtensionDataRecord *dataRecord, NSError *error))completionHandler;
- (void)fetchDataRecordsOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes
             completionHandler:(void (^)(NSArray<WKWebExtensionDataRecord *> *dataRecords, NSError *error))completionHandler;
- (void)removeDataOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes
          fromDataRecords:(NSArray<WKWebExtensionDataRecord *> *)dataRecords
       completionHandler:(void (^)(NSError *error))completionHandler;
@end

@interface WKWebExtensionDataRecord : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nonatomic, readonly, copy) NSString *uniqueIdentifier;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionDataType> *containedDataTypes;
@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;
@property (nonatomic, readonly) NSUInteger totalSizeInBytes;
- (NSUInteger)sizeInBytesOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes;
@end

// The port's own initialisers, charon_-prefixed so they can never collide with a selector a later
// SDK grows, and in the init family because they assign to self.
#endif  // CHARON_HOST_DIFFERENTIAL

@interface WKWebExtensionControllerConfiguration (CharonInit)
- (instancetype)charon_initWithIdentifier:(NSUUID *)identifier
                                persistent:(BOOL)persistent
                     webViewConfiguration:(WKWebViewConfiguration *)webViewConfiguration
                                   store:(WKWebsiteDataStore *)store __attribute__((objc_method_family(init)));
@end

@interface WKWebExtensionDataRecord (CharonInit)
- (instancetype)charon_initWithIdentifier:(NSString *)identifier
                              displayName:(NSString *)displayName
                       containedDataTypes:(NSSet<WKWebExtensionDataType> *)containedDataTypes
                                    errors:(NSArray<NSError *> *)errors __attribute__((objc_method_family(init)));
@end
