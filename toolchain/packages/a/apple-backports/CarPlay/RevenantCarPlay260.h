#ifndef REVENANT_CARPLAY_260_H
#define REVENANT_CARPLAY_260_H

#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>

#if __has_include(<CarPlay/CPLane.h>)

#import <CarPlay/CPGridButton.h>

#else

NS_ASSUME_NONNULL_BEGIN

@interface CPMessageGridItemConfiguration : NSObject

- (instancetype)initWithConversationIdentifier:(NSString *)conversationIdentifier
                                        unread:(BOOL)unread;

@property (nonatomic, getter=isUnread) BOOL unread;

@property (nonatomic, readonly) NSString *conversationIdentifier;

@end

NS_ASSUME_NONNULL_END

#endif

#endif
