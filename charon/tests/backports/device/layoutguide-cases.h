#import <UIKit/UIKit.h>

typedef void (^LayoutGuideRecorder)(NSString *name, NSString *value);

void layoutguide_run(UIWindow *window, LayoutGuideRecorder record);
