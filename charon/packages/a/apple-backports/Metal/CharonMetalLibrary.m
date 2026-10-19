#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"


// The port's own initializer for the class MTLReflection8.m implements, declared here because the two
// attribute getters below are the only thing outside that file that builds one, and that file's own
// header declares the type initializers rather than this one (MTLTypeReflectionInternal.h).
@interface MTLVertexAttribute (CharonMetalInternal)
- (instancetype)initWithNode:(NSDictionary *)node;
@end

// The plist node a function's attributes are built from, which the function below reads and which is
// implemented in this file's own @implementation further down. A C function of this file sits above
// that, so the method is declared here the way the tree declares a port method it reaches from another
// file's helper (HMAccessoryHome10_0.m names the same shape).
@interface CharonMetalFunction (CharonMetalInternal)
- (NSDictionary *)charonArgumentNode;
@end

// The one place that turns a function's argument list into attributes, so a vertex attribute and a
// stage input are built by the same code from the same plist and cannot drift apart. It is a static of
// this file, which is where its only two callers are, and it used to be an external function DEFINED in
// MTLReflection8.m beside the class whose object it builds. That was the rule "a C function has to be
// defined in the translation unit that can see what it builds", and the cost of following it was that
// MTLReflection8.m is one band's API - MTLVertexAttribute and the two pipeline reflection classes are
// all of iOS 8.0 - so a band from 8.0 does not link it and this file, which defines no class and is in
// every band, reached a definition no band above 7.x had:
//
//   Undefined symbols for architecture armv7:
//     "_CharonAttributesFromFunction", referenced from CharonMetalLibrary.o
//
// Nothing is lost by the body living here: it builds an MTLVertexAttribute through the class symbol,
// which the release exports from 8.0 and this library defines below it, and through -initWithNode:,
// which only the bands below 8.0 ever send - the two callers are members of the port's own
// CharonMetalFunction, and the members of this class that the release's MTLFunction already answers
// are never installed on it (see facts/Metal/Reflection.md on how a category method is attached).
static NSArray *CharonAttributesFromFunction(CharonMetalFunction *function)
{
    NSDictionary *node = [function charonArgumentNode];
    return node ? @[[[MTLVertexAttribute alloc] initWithNode:node]] : @[];
}

// The plist node this function was built from, which is the argument list its attributes come from.
// It is the ivar the initializer already stores, named for what it is: -charonArgumentNode was lost
// with a duplicate @implementation an earlier edit left behind, and the helper below needs it.
@implementation CharonMetalFunction {
    NSString *_name, *_stage, *_source;
    NSDictionary *_reflection;
    MTLFunctionOptions _options;
}

- (NSDictionary *)charonArgumentNode
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

- (CharonMetalFunction *)specializedWith:(MTLFunctionConstantValues *)values error:(NSError **)error
{
    return [self specializedWith:values name:_name options:_options error:error];
}

// The function under a name and with the options a descriptor gave it. The name is the specialized name when
// the descriptor has one, because that is the name Metal gives the function it returns (measured on the host:
// facts/Metal/LibraryDescriptors.md).
- (CharonMetalFunction *)specializedWith:(MTLFunctionConstantValues *)values name:(NSString *)name options:(MTLFunctionOptions)options error:(NSError **)error
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
                    *error = CharonMetalError(12, [NSString stringWithFormat:@"the function constant %@ is given a value of another type", constant[@"name"]]);
                return nil;
            }
        }
        NSString *value = given ? literal(given, type) : ([type isEqualToString:@"float"] ? @"0.0" : @"0");
        [defines appendFormat:@"#define charon_fc%lu %@\n#define charon_fc%lu_defined %d\n", (unsigned long)index, value, (unsigned long)index, given ? 1 : 0];
    }
    NSRange line = [_source rangeOfString:@"\n"];
    NSString *source = defines.length && line.location != NSNotFound ? [_source stringByReplacingCharactersInRange:NSMakeRange(line.location + 1, 0) withString:defines] : _source;
    CharonMetalFunction *function = [[CharonMetalFunction alloc] initWithName:name stage:_stage source:source reflection:_reflection];
    function->_options = options;
    return function;
}

- (MTLFunctionType)functionType
{
    return [_stage isEqualToString:@"vertex"] ? MTLFunctionTypeVertex : MTLFunctionTypeFragment;
}

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
}


// MTLFunction's two argument-encoder forms. An argument encoder is a Metal 3 ARGUMENT BUFFER: a view
// over a buffer holding argument buffers, bound by index. This port dispatches a kernel with a
// device pointer and the three thread identifiers and has no argument buffers to view, so there is
// nothing honest to return and these two answer nil. The header makes the return nullable, and the
// row names them as the selectors owed.
//
// They are answered HERE rather than left unimplemented because a missing method is a selector that
// RAISES on call, and a method that answers nil is a call that returns: the first is a crash for a
// caller that probes, the second is a value.
- (id)newArgumentEncoderWithBufferIndex:(NSUInteger)index
{
    return nil;
}

- (id)newArgumentEncoderWithBufferIndex:(NSUInteger)index reflection:(CharonMetalFunction *)reflection
{
    return nil;
}

// MTLLibrary.h:156 - functionConstantsDictionary. EMPTY, and the absence is the plist's: air2cpu
// writes a function's arguments, not its constants.
- (NSDictionary<NSString *, MTLFunctionConstant *> *)functionConstantsDictionary
{
    return @{};
}

// MTLLibrary.h:178 - options. A function answers the options it was made with: none for a function the
// library names, and the descriptor's for one a descriptor names. This port never compiles a function to a
// binary (it translates the AIR to C and ES at build time), so the options change nothing else.
- (MTLFunctionOptions)options
{
    return _options;
}

// MTLLibrary.h:129 - patchType. "MTLPatchTypeNone if it is not a post tessellation function"
// (MTLLibrary.h:127), and no kernel this port dispatches is one.
- (MTLPatchType)patchType
{
    return MTLPatchTypeNone;
}

// MTLLibrary.h:136 - patchControlPointCount. The header: the count "if it was specified in the
// shader", and -1 when it was not (MTLLibrary.h:132-134). It was not.
- (NSInteger)patchControlPointCount
{
    return -1;
}

// MTLLibrary.h:144 - stageInputAttributes, and :141 - vertexAttributes. Both are the kernel's
// ARGUMENT list, which IS in the plist, so these are real rather than empty: one MTLVertexAttribute
// per argument, each carrying the argument's own name, index and data type. They come from the
// reflection reader rather than being re-read here, so there is one place that turns a plist node
// into a vertex attribute.
- (NSArray<MTLVertexAttribute *> *)vertexAttributes
{
    return CharonAttributesFromFunction(self);
}

- (NSArray<MTLAttribute *> *)stageInputAttributes
{
    // The header says stageInputAttributes is nullable, and the same argument list is its source -
    // so this is the same attributes under a second name rather than a second reading of the file.
    return CharonAttributesFromFunction(self);
}


@end



// The MTLFunction members the protocol requires and this class did not carry. Each answers with the
// value the HEADER documents for the case this port is in, and each says which case that is - these
// are the port's documented answers and not a guess, and the row says so in as many words.
//
// The plist carries each function's ARGUMENTS and nothing else: no function constants, no patch
// data, no stage inputs. So what the AIR cannot say, the header's own default is used, and the
// difference between an empty answer and a fabricated one is the difference between the two cases.

#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"



@implementation CharonMetalLibrary {
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
            *error = CharonMetalError(4, [NSString stringWithFormat:@"%@ holds no translated library", folder]);
        return nil;
    }
    if ((self = [super init])) {
        _functions = [NSMutableDictionary dictionary];
        // The translator writes the install name the metallib holds, and leaves the key out when it holds none.
        id installName = root[@"installName"];
        _installName = [installName isKindOfClass:[NSString class]] ? installName : nil;
        for (NSDictionary *entry in root[@"functions"]) {
            NSString *source = [NSString stringWithContentsOfFile:[folder stringByAppendingPathComponent:entry[@"source"]] encoding:NSUTF8StringEncoding error:NULL];
            NSData *reflectionData = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:entry[@"reflection"]]];
            NSDictionary *reflection = reflectionData ? [NSJSONSerialization JSONObjectWithData:reflectionData options:0 error:NULL] : nil;
            if (!source || !reflection)
                continue;
            _functions[entry[@"name"]] = [[CharonMetalFunction alloc] initWithName:entry[@"name"] stage:entry[@"stage"] source:source reflection:reflection];
        }
    }
    return self;
}

- (NSString *)charonInstallName
{
    return _installName;
}

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
}

- (NSArray *)functionNames
{
    return [_functions allKeys];
}

- (id<MTLFunction>)newFunctionWithName:(NSString *)functionName
{
    CharonMetalFunction *function = _functions[functionName];
    return (id<MTLFunction>)[function specializedWith:nil error:NULL];
}

- (id<MTLFunction>)newFunctionWithName:(NSString *)name constantValues:(MTLFunctionConstantValues *)constantValues error:(NSError **)error
{
    CharonMetalFunction *function = _functions[name];
    if (!function) {
        if (error)
            *error = CharonMetalError(13, [NSString stringWithFormat:@"the library holds no function named %@", name]);
        return nil;
    }
    return (id<MTLFunction>)[function specializedWith:constantValues error:error];
}

// The function a descriptor names: the library's function under the descriptor's name, specialized with its
// constant values, named by its specialized name when it has one, and with its options.
- (id<MTLFunction>)charonFunctionNamed:(NSString *)name specializedName:(NSString *)specializedName options:(MTLFunctionOptions)options constantValues:(MTLFunctionConstantValues *)constantValues error:(NSError **)error
{
    CharonMetalFunction *function = name ? _functions[name] : nil;
    if (!function) {
        if (error)
            *error = CharonMetalError(13, [NSString stringWithFormat:@"the library holds no function named %@", name]);
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

// The MTLFunction members the protocol requires and this class did not carry. Each answers with the
// value the HEADER documents for the case this port is in, and each says which case that is - these
// are the port's documented answers and not a guess, and the row says so in as many words.
//
// The plist carries each function's ARGUMENTS and nothing else: no function constants, no patch
// data, no stage inputs. So what the AIR cannot say, the header's own default is used, and the
// difference between an empty answer and a fabricated one is the difference between the two cases.

// MTLLibrary.h:156 - functionConstantsDictionary. EMPTY, and the absence is the plist's: air2cpu
// writes a function's arguments, not its constants.