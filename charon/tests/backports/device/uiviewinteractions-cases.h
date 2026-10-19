#import <Foundation/Foundation.h>

typedef void (^UIViewInteractionsRecorder)(NSString *name, NSString *value);

void uiviewinteractions_run(UIViewInteractionsRecorder record);
