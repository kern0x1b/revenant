#import <UIKit/UIKit.h>

typedef void (^SearchCaseRecorder)(NSString *name, NSString *value);

void searchcontroller_run(UIWindow *window, SearchCaseRecorder record);
