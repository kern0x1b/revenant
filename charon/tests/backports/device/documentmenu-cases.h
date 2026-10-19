#import <UIKit/UIKit.h>

typedef void (^DocumentMenuRecorder)(NSString *name, NSString *value);

void documentmenu_run(UIWindow *window, DocumentMenuRecorder record);
