#import <UIKit/UIKit.h>

BOOL gesture_ready(void);
void gesture_touch(int phase, CGPoint point);
void gesture_step(NSTimeInterval wait, void (^block)(void));
void gesture_run(void (^finished)(void));
void gesture_drag(CGPoint (^from)(void), CGPoint (^to)(void), int steps, NSTimeInterval settle);
void gesture_tap(CGPoint (^point)(void), NSTimeInterval settle);

typedef void (^GestureUnblocked)(BOOL blocked, BOOL cleared);
void gesture_unblock(UIWindow *window, GestureUnblocked done);
