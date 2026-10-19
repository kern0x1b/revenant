#import <UIKit/UIKit.h>

typedef void (^Pasteboard10Recorder)(NSString *name, NSString *value);

void pasteboard10_run(Pasteboard10Recorder record);
