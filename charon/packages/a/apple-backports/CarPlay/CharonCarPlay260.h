// CharonCarPlay260.h - the one type of CarPlay's 26.0 surface the port must name and the build SDK does
// not declare.
//
// THE BUILD SDK IS 16.4, as CharonCarPlay174.h says in its own first paragraph, and
// CPGridButton.h:16 declares
//     @interface CPMessageGridItemConfiguration : NSObject
// with :27 `-initWithConversationIdentifier:unread:`, :30 `unread` (getter=isUnread) and :32
// `conversationIdentifier` - none of which the 16.4 CarPlay.framework/Headers has, because that header
// stops at the 12.0 initialiser at :55. The shape below is Apple's own declaration, declarations only:
// no method body comes from here and no Apple's byte is copied. The behaviour is in CarPlayGrid260.m.
//
// WHY IT IS GUARDED BY CPLane.h, which is what CharonCarPlay174.h already uses. The Mac Catalyst
// differential (tests/backports/host/carplay/run.sh) compiles these same sources against the iOSSupport
// SDK, which DOES declare the class, and a `@interface CPMessageGridItemConfiguration` here beside the
// SDK's own would be a duplicate interface. There is no header of its own to test for - CPGridButton.h
// exists in both SDKs - so the test is the same one CharonCarPlay174.h uses, and it is a correct one for
// the SDKs in scope: CPLane is 17.4 and so is CPMessageGridItemConfiguration's 26.0, and there are exactly
// two SDKs this package compiles against. Against 16.4 the include is false and the declarations below
// are the ones in scope; against the iOSSupport SDK the include is true and the SDK's own declarations
// are.
#ifndef CHARON_CARPLAY_260_H
#define CHARON_CARPLAY_260_H

#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>

#if __has_include(<CarPlay/CPLane.h>)

// The SDK in scope declares the 26.0 CarPlay surface itself. Nothing to stand in for, and declaring any
// of it again here would be a duplicate interface.
#import <CarPlay/CPGridButton.h>

#else

NS_ASSUME_NONNULL_BEGIN

// CPGridButton.h:15-34.
@interface CPMessageGridItemConfiguration : NSObject

- (instancetype)initWithConversationIdentifier:(NSString *)conversationIdentifier
                                        unread:(BOOL)unread;

@property (nonatomic, getter=isUnread) BOOL unread;

@property (nonatomic, readonly) NSString *conversationIdentifier;

@end

NS_ASSUME_NONNULL_END

#endif

#endif