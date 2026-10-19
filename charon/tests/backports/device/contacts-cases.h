#import <Foundation/Foundation.h>

typedef void (^ContactsRecorder)(NSString *name, NSString *value);

void contacts_run(ContactsRecorder record);
