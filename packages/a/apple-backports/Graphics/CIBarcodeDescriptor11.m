// CIBarcodeDescriptor and its four subclasses, as CIBarcodeDescriptor.h declares them.
//
// WHAT A BARCODE DESCRIPTOR IS, and it is the whole of this family: the header calls the base class
// an abstract base class that stands for a machine readable code's symbol attributes, and gives each subclass
// the formal specification of its symbology. The initializer's
// argument is `errorCorrectedPayload` and the property has the same name, and the header says what those
// bytes are, per the header, the codewords after error correction, in the state that follows bitstream-to-codeword
// conversion; errorCorrectedPayload holds the 8-bit codewords of that sequence.
//
// So the payload is the CODEWORD SEQUENCE - bytes the caller has already encoded - and a descriptor holds
// them as they are. Measured on the host's own CoreImage, 2026-10-03: a descriptor made from "abcdefgh" hands
// exactly those eight bytes back, in all four subclasses, through the property and through an archive. A
// payload of NIL and a payload of NO BYTES are both ACCEPTED as well, and the descriptor then answers an
// empty payload: measured for all four classes, and the harness has a case for each. So nothing here refuses
// an empty payload, and the only thing any of these initializers refuses is a parameter outside the range its
// own header states.
//
// There is no Reed-Solomon here, no mask to choose and no codeword to lay down, and this file does not
// pretend otherwise: the encoding is the generator filter's work (CIBarcodeGenerator, which a release this
// port deploys does not have), so carrying these classes does not make any filter render. That is named in
// facts/CoreImage/BarcodeDescriptor.md, and it is a different row set.
//
// WHICH RELEASE: 11.0. tools/cache-index/first-rung.lua over the 50 held rungs puts all five classes at 11.0
// and on no rung below it, which is what the SDK's own NS_CLASS_AVAILABLE(10_13, 11_0) says. This is a new
// object of a family GraphicsBackports already carries and not a split.
//
// WHAT EACH INITIALIZER REFUSES, measured over the whole of its header's ranges rather than sampled, and
// every one of those measurements is a case in tests/backports/host/cibarcode:
//
//   QR              symbolVersion 1-40, maskPattern 0-7, L/M/Q/H: every one of the 1280 combinations answers.
//   Aztec           layerCount 1-32, dataCodewordCount 1-2048: every one of the 4096 combinations answers.
//   PDF417          rowCount 3-90, columnCount 1-30: the header's floor of 3 rows is the host's too - rows 1
//                   and 2 answer nil - and the ceiling of 90 rows and 30 columns is inside as well.
//   Data Matrix     the header states no ranges for the counts and the host has none either: 1x1 answers and
//                   so does 1x40, so there is no range check here to write and inventing one would refuse
//                   inputs the host accepts.
//
// The header's ivars are used as it declares them - each subclass carries its own `errorCorrectedPayload` -
// so the port's object has the same storage the header describes and a subclass reads its own payload
// through its own property, which is what the header's declaration says a caller may do.

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

// CIBarcodeDescriptor is abstract and declares no member of its own (CIBarcodeDescriptor.h:26), so there is
// nothing to implement here but the two protocols it names - NSCopying and NSSecureCoding - and every
// subclass answers them with its own numbers. A caller cannot make one: the header gives the base class no
// initializer, and neither this file nor the host offers a way to.
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
// The payload ivar is the one CIBarcodeDescriptor.h declares for this subclass, under synthesis, so the
// property is answered from the storage the header describes and the initializer writes that ivar.
@synthesize errorCorrectedPayload = _errorCorrectedPayload;

- (instancetype)initWithPayload:(NSData *)errorCorrectedPayload
                  symbolVersion:(NSInteger)symbolVersion
                    maskPattern:(uint8_t)maskPattern
           errorCorrectionLevel:(CIQRCodeErrorCorrectionLevel)errorCorrectionLevel
{
    if ((self = [super init])) {
        // "or nil if the parameters are invalid", and the ranges are the header's: symbolVersion 1-40 and
        // maskPattern 0-7. The version IS bounded and measured so: 0 and 41 answer nil, 1 and 40 answer. The
        // MASK IS NOT: the host answers 7, 8 and 255 and echoes the number back, so a bound here would
        // refuse what the host accepts. The argument is a uint8_t, so 255 is the most it can carry.
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

// An independent copy, which is what NSCopying means and what the host answers (measured: the copy is
// another object and carries the same numbers).
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
// The payload ivar is the one CIBarcodeDescriptor.h declares for this subclass, under synthesis, so the
// property is answered from the storage the header describes and the initializer writes that ivar.
@synthesize errorCorrectedPayload = _errorCorrectedPayload;

- (instancetype)initWithPayload:(NSData *)errorCorrectedPayload
                     isCompact:(BOOL)isCompact
                    layerCount:(NSInteger)layerCount
             dataCodewordCount:(NSInteger)dataCodewordCount
{
    if ((self = [super init])) {
        // "layerCount, from 1 to 32" and "dataCodewordCount, from 1 to 2048" are the header's own ranges, and
        // both ends of both are the host's (measured: layerCount 0, 33 and dataCodewordCount 0, 2049 answer
        // nil, and every value inside answers).
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
// The payload ivar is the one CIBarcodeDescriptor.h declares for this subclass, under synthesis, so the
// property is answered from the storage the header describes and the initializer writes that ivar.
@synthesize errorCorrectedPayload = _errorCorrectedPayload;

- (instancetype)initWithPayload:(NSData *)errorCorrectedPayload
                     isCompact:(BOOL)isCompact
                      rowCount:(NSInteger)rowCount
                   columnCount:(NSInteger)columnCount
{
    if ((self = [super init])) {
        // "rowCount, from 3 to 90" and "columnCount, from 1 to 30", and the floor of 3 is measured rather
        // than read off the header: rows 1 and 2 answer nil on the host, which is what the header says and
        // is why this check starts at 3 (the harness asks rows 1, 2, 3 and 4 so a floor of 2 would show).
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
// The payload ivar is the one CIBarcodeDescriptor.h declares for this subclass, under synthesis, so the
// property is answered from the storage the header describes and the initializer writes that ivar.
@synthesize errorCorrectedPayload = _errorCorrectedPayload;

// The header gives no ranges for the counts: it describes only the rows of the Data Matrix symbol, and
// nothing else - and the host agrees with having no floor: measured over rows 1-40 x columns 1-40 x the four
// eccVersion values, all 6400 answer, 1x1 and 1x40 among them, and so does an eccVersion of 4. So nothing is
// refused here except a payload of no bytes, and writing a range check would refuse what the host accepts.
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