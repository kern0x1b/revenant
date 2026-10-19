#import <CoreData/CoreData.h>

static NSQueryGenerationToken *charon_current_token;

@implementation NSQueryGenerationToken {
    BOOL _current;
}

+ (NSQueryGenerationToken *)currentQueryGenerationToken
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_current_token = [[NSQueryGenerationToken alloc] init];
        charon_current_token->_current = YES;
    });
    return charon_current_token;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (!_current)
        [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_current) {
        [coder encodeBool:YES forKey:@"NSQueryTokenIsSingleton"];
        [coder encodeInteger:2 forKey:@"NSQueryTokenWhichSingleton"];
    }
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ([coder decodeBoolForKey:@"NSQueryTokenIsSingleton"] && [coder decodeIntegerForKey:@"NSQueryTokenWhichSingleton"] == 2)
        return [NSQueryGenerationToken currentQueryGenerationToken];
    return [super init];
}

- (NSString *)description
{
    return _current ? @"<NSQueryGenerationToken : (null)/current>" : [super description];
}

@end
