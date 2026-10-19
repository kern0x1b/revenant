#import <UIKit/UIKit.h>

typedef void (^ToolbarRecorder)(NSString *name, NSString *value);

void toolbar_run(UIWindow *window, ToolbarRecorder record);
