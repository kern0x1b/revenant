#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

@implementation CIBarcodeDescriptor

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@implementation CIQRCodeDescriptor {
@private
    NSInteger _symbolVersion;
    uint8_t _maskPattern;
    CIQRCodeErrorCorrectionLevel _errorCorrectionLevel;
}
@synthesize errorCorrectedPayload = _errorCorrectedPayload;

- (instancetype)initWithPayload:(NSData *)errorCorrectedPayload
                  symbolVersion:(NSInteger)symbolVersion
                    maskPattern:(uint8_t)maskPattern
           errorCorrectionLevel:(CIQRCodeErrorCorrectionLevel)errorCorrectionLevel
{
    if ((self = [super init])) {
        if (symbolVersion < 1 || symbolVersion > 40)
            return nil;
        _errorCorrectedPayload = errorCorrectedPayload;
        _symbolVersion = symbolVersion;
        _maskPattern = maskPattern;
        _errorCorrectionLevel = errorCorrectionLevel;
    }
    return self;
}

+ (instancetype)descriptorWithPayload:(NSData *)errorCorrectedPayload
                        symbolVersion:(NSInteger)symbolVersion
                          maskPattern:(uint8_t)maskPattern
                 errorCorrectionLevel:(CIQRCodeErrorCorrectionLevel)errorCorrectionLevel
{
    return [[self alloc] initWithPayload:errorCorrectedPayload
                           symbolVersion:symbolVersion
                             maskPattern:maskPattern
                    errorCorrectionLevel:errorCorrectionLevel];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithPayload:self.errorCorrectedPayload
                                                symbolVersion:_symbolVersion
                                                  maskPattern:_maskPattern
                                         errorCorrectionLevel:_errorCorrectionLevel];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_errorCorrectedPayload forKey:@"errorCorrectedPayload"];
    [coder encodeInteger:_symbolVersion forKey:@"symbolVersion"];
    [coder encodeInteger:_maskPattern forKey:@"maskPattern"];
    [coder encodeInteger:_errorCorrectionLevel forKey:@"errorCorrectionLevel"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSData *payload = [coder decodeObjectOfClass:[NSData class] forKey:@"errorCorrectedPayload"];
    return [self initWithPayload:payload
                  symbolVersion:[coder decodeIntegerForKey:@"symbolVersion"]
                    maskPattern:(uint8_t)[coder decodeIntegerForKey:@"maskPattern"]
           errorCorrectionLevel:(CIQRCodeErrorCorrectionLevel)[coder decodeIntegerForKey:@"errorCorrectionLevel"]];
}

@end

@implementation CIAztecCodeDescriptor {
@private
    BOOL _isCompact;
    NSInteger _layerCount;
    NSInteger _dataCodewordCount;
}
@synthesize errorCorrectedPayload = _errorCorrectedPayload;

- (instancetype)initWithPayload:(NSData *)errorCorrectedPayload
                     isCompact:(BOOL)isCompact
                    layerCount:(NSInteger)layerCount
             dataCodewordCount:(NSInteger)dataCodewordCount
{
    if ((self = [super init])) {
        if (layerCount < 1 || layerCount > 32 || dataCodewordCount < 1 || dataCodewordCount > 2048)
            return nil;
        _errorCorrectedPayload = errorCorrectedPayload;
        _isCompact = isCompact;
        _layerCount = layerCount;
        _dataCodewordCount = dataCodewordCount;
    }
    return self;
}

+ (instancetype)descriptorWithPayload:(NSData *)errorCorrectedPayload
                          isCompact:(BOOL)isCompact
                         layerCount:(NSInteger)layerCount
                  dataCodewordCount:(NSInteger)dataCodewordCount
{
    return [[self alloc] initWithPayload:errorCorrectedPayload
                              isCompact:isCompact
                             layerCount:layerCount
                      dataCodewordCount:dataCodewordCount];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithPayload:self.errorCorrectedPayload
                                                    isCompact:_isCompact
                                                   layerCount:_layerCount
                                            dataCodewordCount:_dataCodewordCount];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_errorCorrectedPayload forKey:@"errorCorrectedPayload"];
    [coder encodeBool:_isCompact forKey:@"isCompact"];
    [coder encodeInteger:_layerCount forKey:@"layerCount"];
    [coder encodeInteger:_dataCodewordCount forKey:@"dataCodewordCount"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSData *payload = [coder decodeObjectOfClass:[NSData class] forKey:@"errorCorrectedPayload"];
    return [self initWithPayload:payload
                     isCompact:[coder decodeBoolForKey:@"isCompact"]
                    layerCount:[coder decodeIntegerForKey:@"layerCount"]
             dataCodewordCount:[coder decodeIntegerForKey:@"dataCodewordCount"]];
}

@end

@implementation CIPDF417CodeDescriptor {
@private
    BOOL _isCompact;
    NSInteger _rowCount;
    NSInteger _columnCount;
}
@synthesize errorCorrectedPayload = _errorCorrectedPayload;

- (instancetype)initWithPayload:(NSData *)errorCorrectedPayload
                     isCompact:(BOOL)isCompact
                      rowCount:(NSInteger)rowCount
                   columnCount:(NSInteger)columnCount
{
    if ((self = [super init])) {
        if (rowCount < 3 || rowCount > 90 || columnCount < 1 || columnCount > 30)
            return nil;
        _errorCorrectedPayload = errorCorrectedPayload;
        _isCompact = isCompact;
        _rowCount = rowCount;
        _columnCount = columnCount;
    }
    return self;
}

+ (instancetype)descriptorWithPayload:(NSData *)errorCorrectedPayload
                          isCompact:(BOOL)isCompact
                           rowCount:(NSInteger)rowCount
                        columnCount:(NSInteger)columnCount
{
    return [[self alloc] initWithPayload:errorCorrectedPayload
                              isCompact:isCompact
                               rowCount:rowCount
                            columnCount:columnCount];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithPayload:self.errorCorrectedPayload
                                                    isCompact:_isCompact
                                                     rowCount:_rowCount
                                                  columnCount:_columnCount];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_errorCorrectedPayload forKey:@"errorCorrectedPayload"];
    [coder encodeBool:_isCompact forKey:@"isCompact"];
    [coder encodeInteger:_rowCount forKey:@"rowCount"];
    [coder encodeInteger:_columnCount forKey:@"columnCount"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSData *payload = [coder decodeObjectOfClass:[NSData class] forKey:@"errorCorrectedPayload"];
    return [self initWithPayload:payload
                     isCompact:[coder decodeBoolForKey:@"isCompact"]
                      rowCount:[coder decodeIntegerForKey:@"rowCount"]
                   columnCount:[coder decodeIntegerForKey:@"columnCount"]];
}

@end

@implementation CIDataMatrixCodeDescriptor {
@private
    NSInteger _rowCount;
    NSInteger _columnCount;
    CIDataMatrixCodeECCVersion _eccVersion;
}
@synthesize errorCorrectedPayload = _errorCorrectedPayload;

- (instancetype)initWithPayload:(NSData *)errorCorrectedPayload
                      rowCount:(NSInteger)rowCount
                   columnCount:(NSInteger)columnCount
                    eccVersion:(CIDataMatrixCodeECCVersion)eccVersion
{
    if ((self = [super init])) {
        _errorCorrectedPayload = errorCorrectedPayload;
        _rowCount = rowCount;
        _columnCount = columnCount;
        _eccVersion = eccVersion;
    }
    return self;
}

+ (instancetype)descriptorWithPayload:(NSData *)errorCorrectedPayload
                            rowCount:(NSInteger)rowCount
                         columnCount:(NSInteger)columnCount
                          eccVersion:(CIDataMatrixCodeECCVersion)eccVersion
{
    return [[self alloc] initWithPayload:errorCorrectedPayload
                                rowCount:rowCount
                             columnCount:columnCount
                              eccVersion:eccVersion];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithPayload:self.errorCorrectedPayload
                                                    rowCount:_rowCount
                                                 columnCount:_columnCount
                                                  eccVersion:_eccVersion];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_errorCorrectedPayload forKey:@"errorCorrectedPayload"];
    [coder encodeInteger:_rowCount forKey:@"rowCount"];
    [coder encodeInteger:_columnCount forKey:@"columnCount"];
    [coder encodeInteger:_eccVersion forKey:@"eccVersion"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSData *payload = [coder decodeObjectOfClass:[NSData class] forKey:@"errorCorrectedPayload"];
    return [self initWithPayload:payload
                      rowCount:[coder decodeIntegerForKey:@"rowCount"]
                   columnCount:[coder decodeIntegerForKey:@"columnCount"]
                    eccVersion:(CIDataMatrixCodeECCVersion)[coder decodeIntegerForKey:@"eccVersion"]];
}

@end
