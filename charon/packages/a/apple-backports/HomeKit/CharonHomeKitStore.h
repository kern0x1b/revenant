// The on-disk store the HomeKit backport keeps its home graph in, and the HAP identities and
// pairings that graph is reached with. iOS 6 runs no home hub, no homekitd and no accessories
// daemon, so there is no system service to hold this; the port holds it itself, in the
// application's own Application Support directory, where it survives a relaunch and is per
// application exactly as the framework's own data is.
//
// One directory, one property list per table, written atomically when a table changes. The tables:
//
//   homes            the HMHome records, keyed by unique identifier
//   rooms            the HMRoom records of every home
//   zones            the HMZone records, each holding its room identifiers
//   users            the HMUser records of every home
//   servicegroups    the HMServiceGroup records
//   accessories      the HMAccessory records, keyed by HAP accessory identifier
//   services         the HMService records
//   characteristics  the HMCharacteristic records
//   actionsets       the HMActionSet records, each holding its action identifiers
//   actions          the HMAction records
//   triggers         the HMTrigger records, each holding its action set identifiers
//   pairings         per accessory: the HAP long-term keys, the controller's verify keys and the
//                    current session, as HAP itself stores them
//   identities       the controller's own HAP key material, once per installation
//
// Everything here is the port's own name (`charon_` / `Charon`), so no symbol in this file is
// API and every band keeps it: the store is the substrate, not a row of the surface.
#import <Foundation/Foundation.h>

#define CHARON_HOMEKIT_TABLES @[@"homes", @"rooms", @"zones", @"users", @"servicegroups", @"accessories", \
                               @"services", @"characteristics", @"actionsets", @"actions", @"triggers", \
                               @"pairings", @"identities"]

// The store itself. Loaded once per process; every table is a mutable dictionary that is read from
// its property list on first touch and written back, atomically, when it changes.
@interface CharonHomeKitStore : NSObject

+ (CharonHomeKitStore *)shared;

// The mutable contents of one table, created empty on first use.
- (NSMutableDictionary *)tableNamed:(NSString *)name;

// Writes the table back to its property list. A write that fails is reported through the log once
// per table rather than swallowed: a store that silently stops persisting is worse than a loud one.
- (void)flushTableNamed:(NSString *)name;

- (NSString *)root;

@end

// The identifier the port hands out for an object of a class whose real identifier comes from the
// system: a fresh UUID in the same shape HomeKit's own identifiers have, so an application that
// stores one and reads it back sees what it expects.
NSString *CharonHomeKitNewIdentifier(void);

// A failure the port reports once rather than once per attempt, on stderr, prefixed with the
// library's own name. What it is for is the errors a caller cannot see an error object for -- a
// store that stopped persisting, an accessory that stopped answering -- where staying quiet would
// leave a caller believing a write happened.
void charon_homekit_once(NSString *message);
