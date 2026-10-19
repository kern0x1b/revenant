#import <UIKit/UIKit.h>

typedef void (^SafeGuideRecorder)(NSString *name, NSString *value);

void safeguide_run(UIWindow *window, SafeGuideRecorder record);
