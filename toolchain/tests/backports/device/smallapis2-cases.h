#import <UIKit/UIKit.h>

typedef void (^SmallApis2Recorder)(NSString *name, NSString *value);

void smallapis2_run(UIWindow *window, SmallApis2Recorder record);
