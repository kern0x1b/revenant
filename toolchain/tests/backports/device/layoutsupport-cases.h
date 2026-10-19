#import <UIKit/UIKit.h>

typedef void (^LayoutSupportRecorder)(NSString *name, NSString *value);

void layoutsupport_run(UIWindow *window, LayoutSupportRecorder record);
