#import <UIKit/UIKit.h>

typedef void (^TextAlignRecorder)(NSString *name, NSString *value);

void textalign_run(UIWindow *window, TextAlignRecorder record);
