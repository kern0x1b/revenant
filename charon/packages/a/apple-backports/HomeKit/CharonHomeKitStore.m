#import "CharonHomeKitStore.h"
#include <stdio.h>

@implementation CharonHomeKitStore {
    NSMutableDictionary *_tables;      // name -> NSMutableDictionary
    NSMutableSet *_loaded;             // names already read from disk
    NSObject *_lock;                   // the store is touched from the main thread and from the
                                       // transport's own queues, so every access is serialised
}

+ (CharonHomeKitStore *)shared
{
    static CharonHomeKitStore *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonHomeKitStore alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _tables = [[NSMutableDictionary alloc] init];
        _loaded = [[NSMutableSet alloc] init];
        _lock = [[NSObject alloc] init];
    }
    return self;
}

- (NSString *)root
{
    NSArray<NSString *> *directories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = directories.firstObject;
    if (!base)
        base = NSTemporaryDirectory();
    return [base stringByAppendingPathComponent:@"org.charon.homekit"];
}

- (NSString *)pathForTable:(NSString *)name
{
    return [self.root stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"plist"]];
}

- (NSMutableDictionary *)tableNamed:(NSString *)name
{
    @synchronized (self) {
        if ([_loaded containsObject:name])
            return _tables[name];
        NSString *path = [self pathForTable:name];
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSMutableDictionary *table = nil;
        if (data) {
            id held = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
            if ([held isKindOfClass:[NSDictionary class]])
                table = [held mutableCopy];
        }
        if (!table)
            table = [[NSMutableDictionary alloc] init];
        _tables[name] = table;
        [_loaded addObject:name];
        return table;
    }
}

- (void)flushTableNamed:(NSString *)name
{
    @synchronized (self) {
        if (![_loaded containsObject:name])
            return;
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:self.root withIntermediateDirectories:YES attributes:nil error:&error]) {
            charon_homekit_once([NSString stringWithFormat:@"homekit store: cannot create %s: %@", self.root.UTF8String, error.localizedDescription]);
            return;
        }
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:_tables[name] format:NSPropertyListBinaryFormat_v1_0
                                                                 options:0 error:&error];
        if (!data) {
            charon_homekit_once([NSString stringWithFormat:@"homekit store: cannot serialize %@: %@", name, error.localizedDescription]);
            return;
        }
        if (![data writeToFile:[self pathForTable:name] atomically:YES]) {
            charon_homekit_once([NSString stringWithFormat:@"homekit store: cannot write the %@ table", name]);
        }
    }
}

@end

// The pair every graph edge is written with, declared in CharonHomeKitConstruction.h. The store holds
// the identifier as a string because that is what a property list holds; Apple's headers give the
// uniqueIdentifier family an NSUUID, and this is where one becomes the other.
NSUUID *CharonHomeKitUUID(NSString *identifier)
{
    return identifier ? [[NSUUID alloc] initWithUUIDString:identifier] : nil;
}

NSString *CharonHomeKitUUIDString(NSUUID *identifier)
{
    return identifier ? [identifier UUIDString] : nil;
}

NSString *CharonHomeKitNewIdentifier(void)
{
    return [[[NSUUID UUID] UUIDString] uppercaseString];
}

// A store that cannot persist must say so once, not once per write: the port's own log, at the
// level a caller can act on. Only the first failure per message is printed.
static void charon_homekit_once_impl(NSString *message)
{
    static NSMutableSet *printed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        printed = [[NSMutableSet alloc] init];
    });
    @synchronized (printed) {
        if ([printed containsObject:message])
            return;
        [printed addObject:message];
        fprintf(stderr, "[charon.homekit] %s\n", message.UTF8String);
    }
}

void charon_homekit_once(NSString *message)
{
    charon_homekit_once_impl(message);
}
