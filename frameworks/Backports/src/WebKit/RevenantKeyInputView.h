#import <UIKit/UIKit.h>

@protocol RevenantKeyInputConsumer <NSObject>
- (void)typeCharacters:(NSString *)text;
- (void)typeBackspace;
- (void)typeReturn;
@end

@interface RevenantKeyInputView : UIView <UIKeyInput>
@property (nonatomic, weak) id<RevenantKeyInputConsumer> consumer;
- (void)configureForType:(NSString *)inputType;
@end
