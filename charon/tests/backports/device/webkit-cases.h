#import <UIKit/UIKit.h>

typedef void (^WebKitRecorder)(NSString *name, NSString *value);

void webkit_run(UIView *container, WebKitRecorder record);
