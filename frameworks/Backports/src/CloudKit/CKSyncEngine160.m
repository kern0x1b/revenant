#import <Foundation/Foundation.h>

#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKSyncEngine26.h"

@implementation CKSyncEngineConfiguration
{
    CKDatabase *_database;
    CKSyncEngineStateSerialization *_stateSerialization;
    __weak id _delegate;
    NSString *_subscriptionID;
    BOOL _automaticallySync;
}

@synthesize database = _database;
@synthesize stateSerialization = _stateSerialization;
@synthesize delegate;
@synthesize subscriptionID = _subscriptionID;
@synthesize automaticallySync = _automaticallySync;

- (instancetype)initWithDatabase:(CKDatabase *)database
              stateSerialization:(nullable CKSyncEngineStateSerialization *)stateSerialization
                        delegate:(id<CKSyncEngineDelegate>)delegate
{
    CKDatabase *held = database;
    CKSyncEngineStateSerialization *heldState = stateSerialization;
    __weak id heldDelegate = delegate;
    self = [CKSyncEngineConfiguration alloc];
    if (!self) {
        return nil;
    }
    ((CKSyncEngineConfiguration *)self).database = held;
    ((CKSyncEngineConfiguration *)self).stateSerialization = heldState;
    ((CKSyncEngineConfiguration *)self).delegate = heldDelegate;
    return self;
}

@end
