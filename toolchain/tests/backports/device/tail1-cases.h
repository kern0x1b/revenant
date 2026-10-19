#import <UIKit/UIKit.h>

typedef void (^Tail1Recorder)(NSString *name, NSString *value);

void tail1_run(Tail1Recorder record);
