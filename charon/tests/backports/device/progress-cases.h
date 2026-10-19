#import <Foundation/Foundation.h>

typedef void (^ProgressRecorder)(NSString *name, NSString *value);

void progress_run(ProgressRecorder record);
