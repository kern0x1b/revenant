#import <Foundation/Foundation.h>

#define CHARON_HOMEKIT_TABLES @[@"homes", @"rooms", @"zones", @"users", @"servicegroups", @"accessories", \
                               @"services", @"characteristics", @"actionsets", @"actions", @"triggers", \
                               @"pairings", @"identities"]

@interface CharonHomeKitStore : NSObject

+ (CharonHomeKitStore *)shared;

- (NSMutableDictionary *)tableNamed:(NSString *)name;

- (void)flushTableNamed:(NSString *)name;

- (NSString *)root;

@end

NSString *CharonHomeKitNewIdentifier(void);

void charon_homekit_once(NSString *message);
