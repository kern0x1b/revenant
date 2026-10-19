#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import "RevenantCarPlay260.h"
#import "RevenantCarPlayTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CPMessageGridItemConfiguration {
    NSString *_conversationIdentifier;
    BOOL _unread;
}

@synthesize conversationIdentifier = _conversationIdentifier;

- (instancetype)initWithConversationIdentifier:(NSString *)conversationIdentifier
                                        unread:(BOOL)unread
{
    self = [super init];
    if (self) {
        _conversationIdentifier = [conversationIdentifier copy] ?: @"";
        _unread = unread;
    }
    return self;
}

- (BOOL)isUnread { return _unread; }

- (void)setUnread:(BOOL)unread { _unread = unread; }

@end

@implementation CPListTemplate (RevenantGrid260)

- (NSArray<CPGridButton *> *)headerGridButtons
{
    return [self revenant_headerGridButtons];
}

- (void)setHeaderGridButtons:(NSArray<CPGridButton *> *)headerGridButtons
{
    [self revenant_setHeaderGridButtons:headerGridButtons];
}

- (instancetype)initWithTitle:(NSString *)title
                     sections:(NSArray<CPListSection *> *)sections
   assistantCellConfiguration:(CPAssistantCellConfiguration *)assistantCellConfiguration
            headerGridButtons:(NSArray<CPGridButton *> *)headerGridButtons
{
    self = [self initWithTitle:title
                     sections:sections
   assistantCellConfiguration:assistantCellConfiguration];
    if (self) {
        [self revenant_setHeaderGridButtons:headerGridButtons];
    }
    return self;
}

@end

@implementation CPGridButton (RevenantGrid260)

- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                                image:(UIImage *)image
                 messageConfiguration:(CPMessageGridItemConfiguration *)messageConfiguration
                              handler:(void (^)(CPGridButton *))handler
{
    self = [self initWithTitleVariants:titleVariants image:image handler:handler];
    if (self) {
        [self revenant_setMessageConfiguration:messageConfiguration];
    }
    return self;
}

- (CPMessageGridItemConfiguration *)messageConfiguration
{
    return [self revenant_messageConfiguration];
}

- (void)updateTitleVariants:(NSArray<NSString *> *)titleVariants
{
    [self revenant_setTitleVariants:titleVariants];
}

- (void)updateImage:(UIImage *)image
{
    [self revenant_setImage:image];
}

@end

NS_ASSUME_NONNULL_END
