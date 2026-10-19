#import <UIKit/UIKit.h>

typedef void (^FontDescRecorder)(NSString *name, NSString *value);

void fontdesc_run(UIWindow *window, FontDescRecorder record);
