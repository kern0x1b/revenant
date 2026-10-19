#import <Foundation/Foundation.h>

typedef void (^FontKeysRecorder)(NSString *name, NSString *value);

void fontkeys_run(FontKeysRecorder record);
