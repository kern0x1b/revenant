#ifndef REVENANT_SECURITYUI_H
#define REVENANT_SECURITYUI_H

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SFCertificatePresentation : NSObject

- (instancetype)initWithTrust:(SecTrustRef)trust;
- (instancetype)init;

- (void)presentSheetInViewController:(UIViewController *)viewController dismissHandler:(nullable void (^)(void))dismissHandler;
- (void)dismissSheet;

@property (nonatomic, assign, readonly) SecTrustRef trust;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSURL *helpURL;

@end

NS_ASSUME_NONNULL_END

#endif
