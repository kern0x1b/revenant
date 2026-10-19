#import <UIKit/UIKit.h>

typedef void (^InputViewRecorder)(NSString *name, NSString *value);

void inputview_run(UIWindow *window, InputViewRecorder record);
