#import <Foundation/Foundation.h>

typedef void (^StringDrawingRecorder)(NSString *name, NSString *value);

void stringdrawing_run(StringDrawingRecorder record);
