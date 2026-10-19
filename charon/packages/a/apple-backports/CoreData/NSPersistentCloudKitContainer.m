#import "CharonCoreData.h"
#import <objc/runtime.h>

NSString * const NSPersistentStoreRemoteChangeNotificationPostOptionKey = @"NSPersistentStoreRemoteChangeNotificationOptionKey";

static void charon_cloudkit_say_once(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"NSPersistentCloudKitContainer: this release has no CloudKit, so the container keeps its stores on the device and mirrors nothing.");
    });
}

@implementation NSPersistentCloudKitContainerOptions {
@private
    NSString *_containerIdentifier;
}

@dynamic databaseScope;

- (instancetype)initWithContainerIdentifier:(NSString *)containerIdentifier
{
    if ((self = [super init])) {
        _containerIdentifier = [containerIdentifier copy];
    }
    return self;
}

- (NSString *)containerIdentifier
{
    return _containerIdentifier;
}

@end

@implementation NSPersistentCloudKitContainer

- (instancetype)initWithName:(NSString *)name managedObjectModel:(NSManagedObjectModel *)model
{
    charon_cloudkit_say_once();
    return [super initWithName:name managedObjectModel:model];
}

@end

static const char charon_cloudkit_options_key;

@implementation NSPersistentStoreDescription (CharonCloudKit)

- (NSPersistentCloudKitContainerOptions *)cloudKitContainerOptions
{
    return objc_getAssociatedObject(self, &charon_cloudkit_options_key);
}

- (void)setCloudKitContainerOptions:(NSPersistentCloudKitContainerOptions *)cloudKitContainerOptions
{
    charon_cloudkit_say_once();
    objc_setAssociatedObject(self, &charon_cloudkit_options_key, cloudKitContainerOptions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
