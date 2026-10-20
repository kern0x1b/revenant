#import "MTLFunctionLogInternal.h"

@interface RevenantMetalFunctionLogDebugLocation : NSObject <MTLFunctionLogDebugLocation>
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

@interface RevenantMetalFunctionLog : NSObject <MTLFunctionLog>
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

@implementation RevenantMetalFunctionLogDebugLocation

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

@implementation RevenantMetalFunctionLog

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

@implementation RevenantMetalLogContainer

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

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])buffer
                                    count:(NSUInteger)length
{
    (void)state; (void)buffer; (void)length;
    return 0;
}

@end

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
