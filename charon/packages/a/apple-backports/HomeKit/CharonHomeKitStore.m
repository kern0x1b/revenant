#import "CharonHomeKitStore.h"
#include <stdio.h>

@implementation CharonHomeKitStore {
    NSMutableDictionary *_tables;
    NSMutableSet *_loaded;
    NSObject *_lock;
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
