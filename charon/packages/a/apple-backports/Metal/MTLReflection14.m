#import "MTLFunctionLogInternal.h"

// The 14.0 half of the reflection classes, and the port's own declarations of the three types the
// SDK it builds against does not have.
//
// MTLFunctionLog, MTLFunctionLogDebugLocation and MTLLogContainer arrived in iOS 14.0. The 16.4 SDK
// forward-declares the first two (MTLCommandBuffer.h:22) and defines none of them, so the port declares
// them in MTLFunctionLogInternal.h, transcribed from 26.2's MTLFunctionLog.h as facts and with no
// Apple bodies - the same thing CharonMetalProtocols.h does for the protocols the SDK lacks. A class
// the release lacks is CARRIED, not omitted.
//
// WHAT THESE ANSWER, and why, is the whole of the file. A function log is the GPU's own record of
// what a kernel did while it ran: a validation fault, or the values it returned. This port dispatches
// through its own translation of the AIR to OpenGL ES 2.0, on a device whose GLES driver records
// nothing per invocation, so there IS no log to report. The header's own answer for a function with
// no logs is what these return, and every member below says which of its members that is:
//
//   type          MTLFunctionLogTypeValidation, the enumeration's own zero
//   encoderLabel  nil - there is no encoder that produced a log
//   function      nil - and the function a log names is nil rather than a guess at which kernel ran
//   debugLocation nil - no source location, because no log carries one
//   the container  EMPTY, and an empty container is a container with no logs in it
//
// None of that is a stub in the sense of "returns zero because the author was tired": each is the
// documented answer for the case this port is in, and the rows say so in as many words.

// The two classes behind the port's own protocols, declared here because the @implementation is what
// makes them a class: a protocol takes no storage, and the ivars ARE the implementation.
@interface CharonMetalFunctionLogDebugLocation : NSObject <MTLFunctionLogDebugLocation>
{
    NSString *_functionName;
    NSURL *_URL;
    NSUInteger _line, _column;
}
- (instancetype)initWithFunctionName:(NSString *)functionName
                                 URL:(NSURL *)URL
                               line:(NSUInteger)line
                             column:(NSUInteger)column;
@end

@interface CharonMetalFunctionLog : NSObject <MTLFunctionLog>
{
    MTLFunctionLogType _type;
    NSString *_encoderLabel;
    id<MTLFunction> _function;
    id<MTLFunctionLogDebugLocation> _debugLocation;
}
- (instancetype)initWithType:(MTLFunctionLogType)type
               encoderLabel:(NSString *)encoderLabel
                    function:(id<MTLFunction>)function
               debugLocation:(id<MTLFunctionLogDebugLocation>)debugLocation;
@end

@implementation CharonMetalFunctionLogDebugLocation

- (instancetype)initWithFunctionName:(NSString *)functionName
                                 URL:(NSURL *)URL
                               line:(NSUInteger)line
                             column:(NSUInteger)column
{
    if ((self = [super init])) {
        _functionName = [functionName copy];
        _URL = URL;
        _line = line;
        _column = column;
    }
    return self;
}

- (NSString *)functionName
{
    return _functionName;
}

- (NSURL *)URL
{
    return _URL;
}

- (NSUInteger)line
{
    return _line;
}

- (NSUInteger)column
{
    return _column;
}

@end

@implementation CharonMetalFunctionLog

- (instancetype)initWithType:(MTLFunctionLogType)type
               encoderLabel:(NSString *)encoderLabel
                    function:(id<MTLFunction>)function
               debugLocation:(id<MTLFunctionLogDebugLocation>)debugLocation
{
    if ((self = [super init])) {
        _type = type;
        _encoderLabel = [encoderLabel copy];
        _function = function;
        _debugLocation = debugLocation;
    }
    return self;
}

- (MTLFunctionLogType)type
{
    return _type;
}

- (NSString *)encoderLabel
{
    return _encoderLabel;
}

- (id<MTLFunction>)function
{
    return _function;
}

- (id<MTLFunctionLogDebugLocation>)debugLocation
{
    return _debugLocation;
}

@end

// The container: a command buffer's logs. There are none - see the header comment - so this holds an
// array, it is empty, and every accessor reads through it. An empty container is what a function with
// no logs has, and that is what the header documents for the case this port is in. It CONFORMS to
// MTLLogContainer, which 26.2 declares as <NSObject, NSFastEnumeration>, so the two enumeration
// methods are here because the header asks for them and not because anything calls them.
@implementation CharonMetalLogContainer

- (instancetype)init
{
    if ((self = [super init]))
        _logs = [NSMutableArray array];
    return self;
}

- (NSArray<id<MTLFunctionLog>> *)logs
{
    return _logs;
}

- (void)addLog:(id<MTLFunctionLog>)log
{
    if (log)
        [_logs addObject:log];
}

// NSFastEnumeration, which 26.2's MTLLogContainer inherits: an empty container enumerates nothing,
// and this says so through the two methods the protocol names.
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])buffer
                                    count:(NSUInteger)length
{
    (void)state; (void)buffer; (void)length;
    return 0;
}

@end

// MTLFunctionDescriptor, which the 16.4 SDK DOES declare: the four members it carries are a name, a
// specialized name, constant values and options - and a descriptor is a way to ASK for a function with
// them, so the empty constants dictionary and the option set are the header's own defaults.
@implementation MTLFunctionDescriptor

{
    NSString *_name, *_specializedName;
    MTLFunctionConstantValues *_constantValues;
    MTLFunctionOptions _options;
    NSArray<id<MTLBinaryArchive>> *_binaryArchives;
}

- (instancetype)init
{
    if ((self = [super init]))
        _options = MTLFunctionOptionNone;
    return self;
}

- (NSString *)name
{
    return _name;
}

- (void)setName:(NSString *)name
{
    _name = [name copy];
}

- (NSString *)specializedName
{
    return _specializedName;
}

- (void)setSpecializedName:(NSString *)specializedName
{
    _specializedName = [specializedName copy];
}

- (MTLFunctionConstantValues *)constantValues
{
    return _constantValues;
}

- (void)setConstantValues:(MTLFunctionConstantValues *)constantValues
{
    _constantValues = constantValues;
}

- (MTLFunctionOptions)options
{
    return _options;
}

- (void)setOptions:(MTLFunctionOptions)options
{
    _options = options;
}

- (NSArray<id<MTLBinaryArchive>> *)binaryArchives
{
    return _binaryArchives;
}

- (void)setBinaryArchives:(NSArray<id<MTLBinaryArchive>> *)binaryArchives
{
    _binaryArchives = binaryArchives;
}

@end
