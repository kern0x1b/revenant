#ifndef CHARON_SECURITYUI_H
#define CHARON_SECURITYUI_H

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

// SecurityUI arrived in iOS 18.4 and the SDK this package's build compiles against (16.4, lowered)
// has no SecurityUI.framework at all, so the class the port carries is declared here, spelled the way
// SFCertificatePresentation.h of SDK 26.2 spells it: the same superclass, the same selectors, the
// same properties and the same types, and no ivars, so an application compiled against the real
// header finds exactly the class this library exports. The only thing left out is the availability
// and unavailability annotations, which the compiler would refuse against this deployment target and
// which mean nothing in a translation unit that is not the application's.
//
// +new is not declared here: the real header marks it unavailable, and the answer the port gives for
// an unavailable +new is NSObject's own, which is alloc and -init, so the class inherits it rather
// than declaring a method nothing implements.
//
// This is the same arrangement the port already uses where the SDK it builds against has no header:
// AVFoundation/CharonAVAudioBuffer.h redeclares AVAudioPCMBuffer, and CallKit/CharonCallKit.h
// redeclares the CXCallAction family.

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
