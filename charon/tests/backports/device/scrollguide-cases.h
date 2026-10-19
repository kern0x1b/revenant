#import <UIKit/UIKit.h>

typedef void (^ScrollGuideRecorder)(NSString *name, NSString *value);

void scrollguide_run(UIWindow *window, ScrollGuideRecorder record);
