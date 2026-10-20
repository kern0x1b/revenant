#import <CoreData/CoreData.h>

@interface NSConstraintConflict () <NSSecureCoding>
@end

@implementation NSConstraintConflict {
    NSArray *_constraint;
    NSManagedObject *_databaseObject;
    NSDictionary *_databaseSnapshot;
    NSDictionary *_conflictedValues;
    NSArray *_conflictingObjects;
    NSArray *_conflictingSnapshots;
}

- (instancetype)initWithConstraint:(NSArray<NSString *> *)constraint databaseObject:(NSManagedObject *)databaseObject databaseSnapshot:(NSDictionary *)databaseSnapshot conflictingObjects:(NSArray<NSManagedObject *> *)conflictingObjects conflictingSnapshots:(NSArray *)conflictingSnapshots
{
    self = [super init];
    if (self) {
        _constraint = [constraint copy];
        _databaseObject = databaseObject;
        _databaseSnapshot = databaseSnapshot;
        _conflictingObjects = [conflictingObjects copy];
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        NSManagedObject *last = conflictingObjects.lastObject;
        for (NSString *key in constraint)
            values[key] = [last valueForKey:key] ?: [NSNull null];
        _conflictedValues = values;
        _conflictingSnapshots = [conflictingSnapshots copy];
    }
    return self;
}

- (NSArray<NSString *> *)constraint
{
    return _constraint;
}

- (NSDictionary *)constraintValues
{
    return _conflictedValues;
}

- (NSManagedObject *)databaseObject
{
    return _databaseObject;
}

- (NSDictionary *)databaseSnapshot
{
    return _databaseSnapshot;
}

- (NSArray<NSManagedObject *> *)conflictingObjects
{
    return _conflictingObjects;
}

- (NSArray *)conflictingSnapshots
{
    return _conflictingSnapshots;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ (%p) for constraint %@: database: %@, conflictedObjects: %@", [self class], self, _constraint, _databaseObject.objectID, [(_conflictingObjects ?: @[]) valueForKey:@"objectID"]];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [NSException raise:NSInvalidArgumentException format:@"CoreData does not support encoding of conflict objects. Conflicts need to be resolved within the scope of a valid managed object context and should not be archived or serialized: %@", self];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    [NSException raise:NSInvalidArgumentException format:@"CoreData does not support decoding of conflict objects. Conflicts need to be resolved within the scope of a valid managed object context and should not be archived or serialized."];
    return nil;
}

@end
