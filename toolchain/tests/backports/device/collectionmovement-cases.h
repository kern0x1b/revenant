#import <Foundation/Foundation.h>

typedef void (^CollectionMovementRecorder)(NSString *name, NSString *value);

void collectionmovement_run(CollectionMovementRecorder record);
