#import <Foundation/Foundation.h>

#define REVENANT_HOMEKIT_TABLES @[@"homes", @"rooms", @"zones", @"users", @"servicegroups", @"accessories", \
                               @"services", @"characteristics", @"actionsets", @"actions", @"triggers", \
                               @"pairings", @"identities"]

@interface RevenantHomeKitStore : NSObject

+ (RevenantHomeKitStore *)shared;

- (NSMutableDictionary *)tableNamed:(NSString *)name;

- (void)flushTableNamed:(NSString *)name;

- (NSString *)root;

@end

NSString *RevenantHomeKitNewIdentifier(void);

void revenant_homekit_once(NSString *message);
