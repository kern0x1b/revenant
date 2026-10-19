#import <Foundation/Foundation.h>

typedef void (^UiKitScrollRecorder)(NSString *name, NSString *value);

void uikitscroll_run(UiKitScrollRecorder record);
