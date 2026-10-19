#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"


@interface MTLVertexAttribute (RevenantMetalInternal)
- (instancetype)initWithNode:(NSDictionary *)node;
@end

@interface RevenantMetalFunction (RevenantMetalInternal)
- (NSDictionary *)revenantArgumentNode;
@end

static NSArray *RevenantAttributesFromFunction(RevenantMetalFunction *function)
{
    NSDictionary *node = [function revenantArgumentNode];
    return node ? @[[[MTLVertexAttribute alloc] initWithNode:node]] : @[];
}

@implementation RevenantMetalFunction {
    NSString *_name, *_stage, *_source;
    NSDictionary *_reflection;
    MTLFunctionOptions _options;
}

- (NSDictionary *)revenantArgumentNode
{
    return _reflection;
}

@synthesize label;

- (instancetype)initWithName:(NSString *)name stage:(NSString *)stage source:(NSString *)source reflection:(NSDictionary *)reflection
{
    if ((self = [super init])) {
        _name = [name copy];
        _stage = [stage copy];
        _source = [source copy];
        _reflection = reflection;
    }
    return self;
}

- (NSString *)name
{
    return _name;
}

- (NSString *)stage
{
    return _stage;
}

- (NSString *)source
{
    return _source;
}

- (NSDictionary *)reflection
{
    return _reflection;
}

static NSString *literal(NSDictionary *entry, NSString *type)
{
    NSNumber *value = entry[@"value"];
    if ([type isEqualToString:@"float"]) {
        NSString *s = [NSString stringWithFormat:@"%.9g", value.floatValue];
        return [s rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@".eEn"]].location == NSNotFound ? [s stringByAppendingString:@".0"] : s;
    }
    return [NSString stringWithFormat:@"%d", value.intValue];
}

- (RevenantMetalFunction *)specializedWith:(MTLFunctionConstantValues *)values error:(NSError **)error
{
    return [self specializedWith:values name:_name options:_options error:error];
}

- (RevenantMetalFunction *)specializedWith:(MTLFunctionConstantValues *)values name:(NSString *)name options:(MTLFunctionOptions)options error:(NSError **)error
{
    NSMutableString *defines = [NSMutableString string];
    for (NSDictionary *constant in _reflection[@"constants"]) {
        NSUInteger index = [constant[@"index"] unsignedIntegerValue];
        NSDictionary *given = [values valueAtIndex:index name:constant[@"name"]];
        NSString *type = constant[@"type"];
        MTLDataType expected = [type isEqualToString:@"bool"] ? MTLDataTypeBool : [type isEqualToString:@"float"] ? MTLDataTypeFloat : MTLDataTypeInt;
        if (given) {
            MTLDataType data = (MTLDataType)[given[@"type"] integerValue];
            BOOL integer = expected == MTLDataTypeInt && (data == MTLDataTypeInt || data == MTLDataTypeUInt);
            if (data != expected && !integer) {
                if (error)
                    *error = RevenantMetalError(12, [NSString stringWithFormat:@"the function constant %@ is given a value of another type", constant[@"name"]]);
                return nil;
            }
        }
        NSString *value = given ? literal(given, type) : ([type isEqualToString:@"float"] ? @"0.0" : @"0");
        [defines appendFormat:@"#define revenant_fc%lu %@\n#define revenant_fc%lu_defined %d\n", (unsigned long)index, value, (unsigned long)index, given ? 1 : 0];
    }
    NSRange line = [_source rangeOfString:@"\n"];
    NSString *source = defines.length && line.location != NSNotFound ? [_source stringByReplacingCharactersInRange:NSMakeRange(line.location + 1, 0) withString:defines] : _source;
    RevenantMetalFunction *function = [[RevenantMetalFunction alloc] initWithName:name stage:_stage source:source reflection:_reflection];
    function->_options = options;
    return function;
}

- (MTLFunctionType)functionType
{
    return [_stage isEqualToString:@"vertex"] ? MTLFunctionTypeVertex : MTLFunctionTypeFragment;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}


- (id)newArgumentEncoderWithBufferIndex:(NSUInteger)index
{
    return nil;
}

- (id)newArgumentEncoderWithBufferIndex:(NSUInteger)index reflection:(RevenantMetalFunction *)reflection
{
    return nil;
}

- (NSDictionary<NSString *, MTLFunctionConstant *> *)functionConstantsDictionary
{
    return @{};
}

- (MTLFunctionOptions)options
{
    return _options;
}

- (MTLPatchType)patchType
{
    return MTLPatchTypeNone;
}

- (NSInteger)patchControlPointCount
{
    return -1;
}

- (NSArray<MTLVertexAttribute *> *)vertexAttributes
{
    return RevenantAttributesFromFunction(self);
}

- (NSArray<MTLAttribute *> *)stageInputAttributes
{
    return RevenantAttributesFromFunction(self);
}


@end



#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"



@implementation RevenantMetalLibrary {
    NSMutableDictionary *_functions;
    NSString *_installName;
}

@synthesize label;

- (instancetype)initWithFolder:(NSString *)folder error:(NSError **)error
{
    NSData *manifest = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"library.json"]];
    NSDictionary *root = manifest ? [NSJSONSerialization JSONObjectWithData:manifest options:0 error:NULL] : nil;
    if (![root isKindOfClass:[NSDictionary class]]) {
        if (error)
            *error = RevenantMetalError(4, [NSString stringWithFormat:@"%@ holds no translated library", folder]);
        return nil;
    }
    if ((self = [super init])) {
        _functions = [NSMutableDictionary dictionary];
        id installName = root[@"installName"];
        _installName = [installName isKindOfClass:[NSString class]] ? installName : nil;
        for (NSDictionary *entry in root[@"functions"]) {
            NSString *source = [NSString stringWithContentsOfFile:[folder stringByAppendingPathComponent:entry[@"source"]] encoding:NSUTF8StringEncoding error:NULL];
            NSData *reflectionData = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:entry[@"reflection"]]];
            NSDictionary *reflection = reflectionData ? [NSJSONSerialization JSONObjectWithData:reflectionData options:0 error:NULL] : nil;
            if (!source || !reflection)
                continue;
            _functions[entry[@"name"]] = [[RevenantMetalFunction alloc] initWithName:entry[@"name"] stage:entry[@"stage"] source:source reflection:reflection];
        }
    }
    return self;
}

- (NSString *)revenantInstallName
{
    return _installName;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}

- (NSArray *)functionNames
{
    return [_functions allKeys];
}

- (id<MTLFunction>)newFunctionWithName:(NSString *)functionName
{
    RevenantMetalFunction *function = _functions[functionName];
    return (id<MTLFunction>)[function specializedWith:nil error:NULL];
}

- (id<MTLFunction>)newFunctionWithName:(NSString *)name constantValues:(MTLFunctionConstantValues *)constantValues error:(NSError **)error
{
    RevenantMetalFunction *function = _functions[name];
    if (!function) {
        if (error)
            *error = RevenantMetalError(13, [NSString stringWithFormat:@"the library holds no function named %@", name]);
        return nil;
    }
    return (id<MTLFunction>)[function specializedWith:constantValues error:error];
}

- (id<MTLFunction>)revenantFunctionNamed:(NSString *)name specializedName:(NSString *)specializedName options:(MTLFunctionOptions)options constantValues:(MTLFunctionConstantValues *)constantValues error:(NSError **)error
{
    RevenantMetalFunction *function = name ? _functions[name] : nil;
    if (!function) {
        if (error)
            *error = RevenantMetalError(13, [NSString stringWithFormat:@"the library holds no function named %@", name]);
        return nil;
    }
    return (id<MTLFunction>)[function specializedWith:constantValues name:specializedName ?: name options:options error:error];
}

- (void)newFunctionWithName:(NSString *)name constantValues:(MTLFunctionConstantValues *)constantValues completionHandler:(void (^)(id<MTLFunction> function, NSError *error))completionHandler
{
    NSError *error = nil;
    id<MTLFunction> function = [self newFunctionWithName:name constantValues:constantValues error:&error];
    completionHandler(function, error);
}

@end
