#import <UIKit/UIKit.h>

typedef void (^PresentationRecorder)(NSString *name, NSString *value);

void presentation_run(UIWindow *window, PresentationRecorder record);
