#import "CharonCoreData.h"

@implementation NSPersistentContainer {
@private
    NSString *_name;
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
    NSManagedObjectContext *_viewContext;
    NSArray *_persistentStoreDescriptions;
}

+ (instancetype)persistentContainerWithName:(NSString *)name
{
    return [[self alloc] initWithName:name];
}

+ (instancetype)persistentContainerWithName:(NSString *)name managedObjectModel:(NSManagedObjectModel *)model
{
    return [[self alloc] initWithName:name managedObjectModel:model];
}

+ (NSURL *)defaultDirectoryURL
{
    static NSURL *directory;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSFileManager *files = [NSFileManager defaultManager];
        NSArray *found = [files URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
        if (!found.count) {
            NSLog(@"CoreData: error:  Found no possible URLs for directory type %lu", (unsigned long)NSApplicationSupportDirectory);
            return;
        }
        directory = found[0];
        BOOL folder = NO;
        if ([files fileExistsAtPath:directory.path isDirectory:&folder]) {
            if (!folder)
                NSLog(@"CoreData: error:  File %@ already exists and is not a directory!", directory);
            return;
        }
        NSError *error = nil;
        if (![files createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error])
            NSLog(@"CoreData: error:  Failed to create directory %@: %@", directory, error);
    });
    return directory;
}

+ (NSManagedObjectModel *)charon_modelNamed:(NSString *)name
{
    for (NSBundle *bundle in @[[NSBundle mainBundle], [NSBundle bundleForClass:self]]) {
        NSURL *found = [bundle URLForResource:name withExtension:@"momd"] ?: [bundle URLForResource:name withExtension:@"mom"];
        NSManagedObjectModel *model = found ? [[NSManagedObjectModel alloc] initWithContentsOfURL:found] : nil;
        if (model)
            return model;
    }
    NSLog(@"CoreData: error:  Failed to load model named %@", name);
    return nil;
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:NSGenericException
                                   reason:[NSString stringWithFormat:@"Failed to call designated initializer on '%@' \n",
                                                                     NSStringFromClass([self class])]
                                 userInfo:nil];
}

- (instancetype)initWithName:(NSString *)name
{
    return [self initWithName:name managedObjectModel:[[self class] charon_modelNamed:name] ?: [[NSManagedObjectModel alloc] init]];
}

- (instancetype)initWithName:(NSString *)name managedObjectModel:(NSManagedObjectModel *)model
{
    if ((self = [super init])) {
        _name = [name copy];
        _managedObjectModel = model;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        _viewContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _viewContext.persistentStoreCoordinator = _persistentStoreCoordinator;
        NSURL *store = [[[self class] defaultDirectoryURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", name]];
        _persistentStoreDescriptions = @[[NSPersistentStoreDescription persistentStoreDescriptionWithURL:store]];
    }
    return self;
}

- (NSString *)name
{
    return _name;
}

- (NSManagedObjectModel *)managedObjectModel
{
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *)viewContext
{
    return _viewContext;
}

- (NSArray *)persistentStoreDescriptions
{
    return _persistentStoreDescriptions;
}

- (void)setPersistentStoreDescriptions:(NSArray *)descriptions
{
    _persistentStoreDescriptions = [descriptions copy];
}

- (void)loadPersistentStoresWithCompletionHandler:(void (^)(NSPersistentStoreDescription *, NSError *))block
{
    for (NSPersistentStoreDescription *description in [_persistentStoreDescriptions copy])
        [_persistentStoreCoordinator addPersistentStoreWithDescription:description completionHandler:block];
}

- (NSManagedObjectContext *)newBackgroundContext
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    context.persistentStoreCoordinator = _persistentStoreCoordinator;
    return context;
}

- (void)performBackgroundTask:(void (^)(NSManagedObjectContext *))block
{
    NSManagedObjectContext *context = [self newBackgroundContext];
    [context performBlock:^{
        block(context);
    }];
}

@end
