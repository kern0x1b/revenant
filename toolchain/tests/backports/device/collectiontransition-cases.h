#import <Foundation/Foundation.h>

typedef void (^CollectionTransitionRecorder)(NSString *name, NSString *value);

void collectiontransition_run(CollectionTransitionRecorder record);
