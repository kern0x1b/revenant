#import <UIKit/UIKit.h>

typedef void (^Traits11Recorder)(NSString *name, NSString *value);

void traits11_run(UIWindow *window, Traits11Recorder record);
