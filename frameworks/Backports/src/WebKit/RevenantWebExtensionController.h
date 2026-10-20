#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "RevenantWebExtension.h"

@class WKWebExtension;
@class WKWebExtensionContext;
@class WKWebExtensionController;
@class WKWebExtensionDataRecord;
@protocol WKWebExtensionTab;

#ifndef REVENANT_HOST_DIFFERENTIAL

typedef NSString *WKWebExtensionDataType NS_TYPED_ENUM;

extern WKWebExtensionDataType const WKWebExtensionDataTypeLocal;
extern WKWebExtensionDataType const WKWebExtensionDataTypeSession;
extern WKWebExtensionDataType const WKWebExtensionDataTypeSynchronized;

extern NSString *const WKWebExtensionDataRecordErrorDomain;


@protocol WKWebExtensionControllerDelegate <NSObject>
@end

#endif

@interface WKWebExtensionControllerConfiguration (RevenantInit)
- (instancetype)revenant_initWithIdentifier:(NSUUID *)identifier
                                persistent:(BOOL)persistent
                     webViewConfiguration:(WKWebViewConfiguration *)webViewConfiguration
                                   store:(WKWebsiteDataStore *)store __attribute__((objc_method_family(init)));
@end

@interface WKWebExtensionDataRecord (RevenantInit)
- (instancetype)revenant_initWithIdentifier:(NSString *)identifier
                              displayName:(NSString *)displayName
                       containedDataTypes:(NSSet<WKWebExtensionDataType> *)containedDataTypes
                                    errors:(NSArray<NSError *> *)errors __attribute__((objc_method_family(init)));
@end
