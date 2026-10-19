#import <UIKit/UIKit.h>

typedef void (^PreviewingRecorder)(NSString *name, NSString *value);

void previewing_run(UIWindow *window, PreviewingRecorder record);
