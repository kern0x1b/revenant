#import <UIKit/UIKit.h>

typedef void (^PressesRecorder)(NSString *name, NSString *value);

void presses_run(UIWindow *window, PressesRecorder record);
