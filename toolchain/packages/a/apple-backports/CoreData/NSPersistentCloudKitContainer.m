#import "RevenantCoreData.h"
#import <objc/runtime.h>

NSString * const NSPersistentStoreRemoteChangeNotificationPostOptionKey = @"NSPersistentStoreRemoteChangeNotificationOptionKey";

static void revenant_cloudkit_say_once(void)
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
    revenant_cloudkit_say_once();
    return [super initWithName:name managedObjectModel:model];
}

@end

static const char revenant_cloudkit_options_key;

@implementation NSPersistentStoreDescription (RevenantCloudKit)

- (NSPersistentCloudKitContainerOptions *)cloudKitContainerOptions
{
    return objc_getAssociatedObject(self, &revenant_cloudkit_options_key);
}

- (void)setCloudKitContainerOptions:(NSPersistentCloudKitContainerOptions *)cloudKitContainerOptions
{
    revenant_cloudkit_say_once();
    objc_setAssociatedObject(self, &revenant_cloudkit_options_key, cloudKitContainerOptions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
