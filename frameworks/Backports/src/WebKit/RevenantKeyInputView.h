#import <UIKit/UIKit.h>

// What the key input view types into: the page's focused field.
@protocol RevenantKeyInputConsumer <NSObject>
- (void)typeCharacters:(NSString *)text;
- (void)typeBackspace;
- (void)typeReturn;
@end

// The view that takes the software keyboard for the page's focused field. It is never shown: it sits
// off screen, in the scroll view, and becomes first responder when the page focuses a field.
@interface RevenantKeyInputView : UIView <UIKeyInput>
@property (nonatomic, weak) id<RevenantKeyInputConsumer> consumer;
- (void)configureForType:(NSString *)inputType;
@end
