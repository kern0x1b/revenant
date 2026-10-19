// CKSyncEngineConfiguration, carried as the port's own object: the class the held iOS 16.0 cache is
// the first to export. The engine it configures, CKSyncEngine, is in CKSyncEngine134.m (iOS 13.4).
//
// The configuration holds the three properties the header declares, and it is built only through the
// initialiser the header declares, as the engine's own object would be.
#import <Foundation/Foundation.h>

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSyncEngine26.h"

@implementation CKSyncEngineConfiguration
{
    // The three properties the header declares, held here: the engine is the port's own, and so is its
    // configuration.
    CKDatabase *_database;
    CKSyncEngineStateSerialization *_stateSerialization;
    __weak id _delegate;
    NSString *_subscriptionID;
    BOOL _automaticallySync;
}

// EXPLICIT, because the library compiles with -Werror=objc-missing-property-synthesis: the three
// strong properties synthesise their own ivars, and the weak one is synthesised by the property, so
// redeclaring its ivar here is the error the flag is there to catch.
@synthesize database = _database;
@synthesize stateSerialization = _stateSerialization;
@synthesize delegate;
@synthesize subscriptionID = _subscriptionID;
@synthesize automaticallySync = _automaticallySync;

- (instancetype)initWithDatabase:(CKDatabase *)database
              stateSerialization:(nullable CKSyncEngineStateSerialization *)stateSerialization
                        delegate:(nullable id)delegate
{
    // -init is NS_UNAVAILABLE in the header, so this class is built only through the initialiser the
    // header declares - which is what the caller wrote anyway.
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
