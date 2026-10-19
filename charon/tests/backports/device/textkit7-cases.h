#import <Foundation/Foundation.h>

typedef void (^TextKit7Recorder)(NSString *name, NSString *value);

void textkit7_run(TextKit7Recorder record);
