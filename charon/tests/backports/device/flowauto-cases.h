#import <UIKit/UIKit.h>

typedef void (^FlowAutoRecorder)(NSString *name, NSString *value);

void flowauto_run(UIWindow *window, FlowAutoRecorder record);
