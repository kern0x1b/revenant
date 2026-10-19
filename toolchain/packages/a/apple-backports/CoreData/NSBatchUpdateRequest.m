#import <CoreData/CoreData.h>
#import "CharonStoreCoordinator.h"

@implementation NSBatchUpdateResult {
    id _result;
    NSBatchUpdateRequestResultType _resultType;
}

- (instancetype)initWithResult:(id)result type:(NSBatchUpdateRequestResultType)type
{
    self = [super init];
    if (self) {
        _result = result;
        _resultType = type;
    }
    return self;
}

- (id)result
{
    return _result;
}

- (NSBatchUpdateRequestResultType)resultType
{
    return _resultType;
}

@end

static void charon_reject(NSString *format, id argument)
{
    [NSException raise:NSInvalidArgumentException format:format, argument];
}

static NSDictionary *charon_validated_properties(NSDictionary *properties, NSEntityDescription *entity)
{
    NSMutableDictionary *validated = [[NSMutableDictionary alloc] init];
    for (id key in [properties allKeys]) {
        id value = properties[key];
        NSPropertyDescription *property = nil;
        if ([key isKindOfClass:[NSString class]]) {
            if ([(NSString *)key rangeOfString:@"."].location != NSNotFound)
                charon_reject(@"Invalid string keypath %@ passed to propertiesToUpdate:", key);
            property = entity.propertiesByName[key];
            if (!property)
                charon_reject(@"Invalid string key %@ passed to propertiesToUpdate:", property);
        } else {
            property = entity.propertiesByName[[key name]];
            if (!property)
                charon_reject(@"Attribute/relationship description names passed to propertiesToUpdate must match name on fetch entity (%@)", property);
            if ([key isKindOfClass:[NSExpressionDescription class]])
                charon_reject(@"Invalid expressionDescription %@ passed as key to propertiesToUpdate:", key);
        }
        if ([property isKindOfClass:[NSRelationshipDescription class]])
            charon_reject(@"Invalid relationship (%@) passed to propertiesToUpdate:", property);
        if (![property isKindOfClass:[NSAttributeDescription class]])
            charon_reject(@"Invalid property %@ passed as key to propertiesToUpdate:", property);
        validated[property] = [value isKindOfClass:[NSExpression class]] ? value : [NSExpression expressionForConstantValue:value];
    }
    return validated;
}

static void charon_check_expression(NSExpression *expression, NSAttributeDescription *attribute, NSEntityDescription *entity)
{
    switch (expression.expressionType) {
    case NSConstantValueExpressionType: {
        id constant = expression.constantValue;
        if ((!constant || constant == [NSNull null]) && !attribute.optional && !attribute.transient) {
            NSDictionary *userInfo = @{NSValidationKeyErrorKey: attribute.name, NSValidationObjectErrorKey: entity, NSValidationValueErrorKey: [NSNull null]};
            [[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Invalid NULL value for key (%@) passed to propertiesToUpdate:", attribute.name] userInfo:userInfo] raise];
        }
        return;
    }
    case NSFunctionExpressionType:
        for (NSExpression *argument in expression.arguments)
            charon_check_expression(argument, nil, entity);
        return;
    case NSKeyPathExpressionType:
        if ([expression.keyPath rangeOfString:@"."].location != NSNotFound || ![entity.propertiesByName[expression.keyPath] isKindOfClass:[NSAttributeDescription class]])
            charon_reject(@"Can't generate SQL for keypath %@ : invalid keypath", expression.keyPath);
        return;
    case NSSubqueryExpressionType:
        charon_reject(@"Unsupported subquery (non-aggregate not allowed in select or update column): %@", expression);
        return;
    default:
        charon_reject(@"Invalid expression (%@) in propertiesToUpdate", expression);
    }
}

static id charon_execute_batch_update(NSManagedObjectContext *context, NSBatchUpdateRequest *request, NSError **error);

@implementation NSBatchUpdateRequest {
@public
    id _entity;
    NSPredicate *_predicate;
    BOOL _includesSubentities;
    NSBatchUpdateRequestResultType _resultType;
    BOOL _entityIsName;
    NSDictionary *_columnsToUpdate;
}

+ (instancetype)batchUpdateRequestWithEntityName:(NSString *)entityName
{
    return [[self alloc] initWithEntityName:entityName];
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _includesSubentities = YES;
    return self;
}

- (instancetype)initWithEntityName:(NSString *)entityName
{
    self = [self init];
    if (self) {
        _entity = entityName;
        _entityIsName = YES;
    }
    return self;
}

- (instancetype)initWithEntity:(NSEntityDescription *)entity
{
    self = [self init];
    if (self)
        _entity = entity;
    return self;
}

- (NSString *)entityName
{
    return _entityIsName ? _entity : [_entity name];
}

- (NSEntityDescription *)entity
{
    if (_entityIsName)
        [NSException raise:NSObjectInaccessibleException format:@"This batch update request (%p) was created with a string name (%@), and cannot respond to -entity until used by an NSManagedObjectContext", self, _entity];
    return _entity;
}

- (NSPredicate *)predicate
{
    @synchronized(self) {
        return _predicate;
    }
}

- (void)setPredicate:(NSPredicate *)predicate
{
    @synchronized(self) {
        _predicate = predicate;
    }
}

- (BOOL)includesSubentities
{
    return _includesSubentities;
}

- (void)setIncludesSubentities:(BOOL)includesSubentities
{
    _includesSubentities = includesSubentities;
}

- (NSBatchUpdateRequestResultType)resultType
{
    return _resultType;
}

- (void)setResultType:(NSBatchUpdateRequestResultType)resultType
{
    _resultType = resultType & 3;
}

- (NSDictionary *)propertiesToUpdate
{
    return _columnsToUpdate;
}

- (void)setPropertiesToUpdate:(NSDictionary *)propertiesToUpdate
{
    if (_columnsToUpdate == propertiesToUpdate)
        return;
    _columnsToUpdate = _entityIsName ? [propertiesToUpdate copy] : charon_validated_properties(propertiesToUpdate, _entity);
}

- (NSPersistentStoreRequestType)requestType
{
    return (NSPersistentStoreRequestType)6;
}

- (id)charonExecuteInContext:(NSManagedObjectContext *)context error:(NSError **)error
{
    return charon_execute_batch_update(context, self, error);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<NSBatchUpdateRequest : entity = %@, properties = %@, subentities = %d", [self entityName], _columnsToUpdate, _includesSubentities ? 1 : 0];
}

@end

static id charon_execute_batch_update(NSManagedObjectContext *context, NSBatchUpdateRequest *request, NSError **error)
{
    NSPersistentStoreCoordinator *coordinator = charon_store_coordinator(context);
    NSEntityDescription *entity = request->_entityIsName ? coordinator.managedObjectModel.entitiesByName[request->_entity] : request->_entity;
    if (!entity)
        [NSException raise:NSInternalInconsistencyException format:@"Can't find entity for batch update (%@)", request.entityName];
    NSDictionary *properties = request->_columnsToUpdate;
    if (request->_entityIsName && properties.count)
        properties = charon_validated_properties(properties, entity);
    if (!properties.count) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:134030 userInfo:@{@"Reason": @"Empty or Null Dictionary passed to propertiesToUpdate:"}];
        return nil;
    }
    for (NSAttributeDescription *attribute in properties)
        charon_check_expression(properties[attribute], attribute, entity);
    NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
    fetch.entity = entity;
    fetch.predicate = request.predicate;
    fetch.includesSubentities = request.includesSubentities;
    fetch.resultType = NSManagedObjectResultType;
    fetch.includesPendingChanges = NO;
    if (request.affectedStores)
        fetch.affectedStores = request.affectedStores;
    NSManagedObjectContext *worker = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    worker.persistentStoreCoordinator = coordinator;
    __block id outcome = nil;
    __block NSError *failure = nil;
    [worker performBlockAndWait:^{
        NSArray *objects = [worker executeFetchRequest:fetch error:&failure];
        if (!objects)
            return;
        NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity:objects.count];
        for (NSManagedObject *object in objects) {
            NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity:properties.count];
            for (NSAttributeDescription *attribute in properties) {
                id value = [properties[attribute] expressionValueWithObject:object context:nil];
                values[attribute.name] = value ?: [NSNull null];
            }
            for (NSString *name in values)
                [object setValue:values[name] == [NSNull null] ? nil : values[name] forKey:name];
            [identifiers addObject:object.objectID];
        }
        if (objects.count && ![worker save:&failure])
            return;
        if (request.resultType == NSUpdatedObjectIDsResultType)
            outcome = [identifiers copy];
        else if (request.resultType == NSUpdatedObjectsCountResultType)
            outcome = @(identifiers.count);
        else
            outcome = @YES;
    }];
    if (!outcome) {
        if (error)
            *error = failure;
        return nil;
    }
    return [[NSBatchUpdateResult alloc] initWithResult:outcome type:request.resultType];
}
