#import <UIKit/UIKit.h>

typedef void (^CustomTransitionRecorder)(NSString *name, NSString *value);

void customtransition_run(UIWindow *window, CustomTransitionRecorder record, void (^done)(void));
