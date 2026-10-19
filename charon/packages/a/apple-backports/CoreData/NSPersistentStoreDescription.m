#import "CharonCoreData.h"

static NSString *const CharonAddStoreAsynchronouslyOption = @"NSAddStoreAsynchronouslyOption";

@implementation NSPersistentStoreDescription {
@private
    NSString *_type;
    NSString *_configuration;
    NSURL *_URL;
    NSMutableDictionary *_options;
}

+ (instancetype)persistentStoreDescriptionWithURL:(NSURL *)URL
{
    return [[self alloc] initWithURL:URL];
}

- (instancetype)init
{
    return [self initWithURL:[NSURL fileURLWithPath:@"/dev/null"]];
}

- (instancetype)initWithURL:(NSURL *)URL
{
    if ((self = [super init])) {
        _URL = [URL copy];
        _type = NSSQLiteStoreType;
        _options = [@{NSInferMappingModelAutomaticallyOption: @YES, NSMigratePersistentStoresAutomaticallyOption: @YES} mutableCopy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSPersistentStoreDescription *copy = [[[self class] allocWithZone:zone] initWithURL:_URL];
    copy.type = _type;
    copy.configuration = _configuration;
    copy->_options = [_options mutableCopy];
    return copy;
}

- (NSString *)type
{
    return _type;
}

- (void)setType:(NSString *)type
{
    _type = [type copy];
}

- (NSString *)configuration
{
    return _configuration;
}

- (void)setConfiguration:(NSString *)configuration
{
    _configuration = [configuration copy];
}

- (NSURL *)URL
{
    return _URL;
}

- (void)setURL:(NSURL *)URL
{
    _URL = [URL copy];
}

- (NSDictionary *)options
{
    return [_options copy];
}

- (void)setOption:(NSObject *)option forKey:(NSString *)key
{
    if (option)
        _options[key] = option;
    else
        [_options removeObjectForKey:key];
}

- (BOOL)isReadOnly
{
    return [_options[NSReadOnlyPersistentStoreOption] boolValue];
}

- (void)setReadOnly:(BOOL)readOnly
{
    _options[NSReadOnlyPersistentStoreOption] = @(readOnly);
}

- (NSTimeInterval)timeout
{
    NSNumber *timeout = _options[NSPersistentStoreTimeoutOption];
    return timeout ? timeout.doubleValue : 240;
}

- (void)setTimeout:(NSTimeInterval)timeout
{
    _options[NSPersistentStoreTimeoutOption] = @(timeout);
}

- (NSDictionary *)sqlitePragmas
{
    return _options[NSSQLitePragmasOption] ?: @{};
}

- (void)setValue:(NSObject *)value forPragmaNamed:(NSString *)name
{
    NSMutableDictionary *pragmas = [self.sqlitePragmas mutableCopy];
    if (value)
        pragmas[name] = value;
    else
        [pragmas removeObjectForKey:name];
    _options[NSSQLitePragmasOption] = [pragmas copy];
}

- (BOOL)shouldAddStoreAsynchronously
{
    return [_options[CharonAddStoreAsynchronouslyOption] boolValue];
}

- (void)setShouldAddStoreAsynchronously:(BOOL)asynchronously
{
    _options[CharonAddStoreAsynchronouslyOption] = @(asynchronously);
}

- (BOOL)shouldMigrateStoreAutomatically
{
    return [_options[NSMigratePersistentStoresAutomaticallyOption] boolValue];
}

- (void)setShouldMigrateStoreAutomatically:(BOOL)migrate
{
    _options[NSMigratePersistentStoresAutomaticallyOption] = @(migrate);
}

- (BOOL)shouldInferMappingModelAutomatically
{
    return [_options[NSInferMappingModelAutomaticallyOption] boolValue];
}

- (void)setShouldInferMappingModelAutomatically:(BOOL)infer
{
    _options[NSInferMappingModelAutomaticallyOption] = @(infer);
}

static BOOL charon_same(id a, id b)
{
    return a == b || [a isEqual:b];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    NSPersistentStoreDescription *other = object;
    return charon_same(_URL, other.URL) && charon_same(_type, other.type) && charon_same(_configuration, other.configuration)
        && charon_same(_options, other->_options);
}

- (NSUInteger)hash
{
    return _URL.hash ^ _type.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ (type: %@, url: %@)", [super description], _type, _URL];
}

@end
