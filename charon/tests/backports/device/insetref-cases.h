#import <UIKit/UIKit.h>

typedef void (^InsetRefRecorder)(NSString *name, NSString *value);

void insetref_run(UIWindow *window, InsetRefRecorder record);
