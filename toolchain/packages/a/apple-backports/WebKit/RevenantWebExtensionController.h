#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "CharonWebExtension.h"

@class WKWebExtension;
@class WKWebExtensionContext;
@class WKWebExtensionController;
@class WKWebExtensionDataRecord;
@protocol WKWebExtensionTab;

#ifndef CHARON_HOST_DIFFERENTIAL

typedef NSString *WKWebExtensionDataType NS_TYPED_ENUM;

extern WKWebExtensionDataType const WKWebExtensionDataTypeLocal;
extern WKWebExtensionDataType const WKWebExtensionDataTypeSession;
extern WKWebExtensionDataType const WKWebExtensionDataTypeSynchronized;

extern NSString *const WKWebExtensionDataRecordErrorDomain;
typedef NS_ENUM(NSInteger, WKWebExtensionDataRecordError) {
    WKWebExtensionDataRecordErrorUnknown = 1,
} API_AVAILABLE(ios(18.4));

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

#endif

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
