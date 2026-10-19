#import <UIKit/UIKit.h>

typedef void (^ShowRecorder)(NSString *name, NSString *value);

void show_run(UIWindow *window, ShowRecorder record);
