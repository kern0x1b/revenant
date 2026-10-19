#import <UIKit/UIKit.h>

typedef void (^Tail2Recorder)(NSString *name, NSString *value);

void tail2_run(Tail2Recorder record);
