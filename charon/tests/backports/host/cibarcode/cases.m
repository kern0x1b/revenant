// The cases CIBarcodeDescriptor and its four subclasses have to answer, compiled twice: once against the
// host's own CoreImage and once against the port's object, so the two sets of answers are compared by run.sh
// line by line.
//
// WHAT IS BEING ASKED. The header calls the initializer's argument `errorCorrectedPayload` and gives the
// property the same name, so every case here answers one of two questions: which numbers does a descriptor
// accept, and what does it hold. A descriptor prints itself as its class, the bytes of its payload and every
// number its own header declares, so a difference in a case is a difference in the descriptor.
//
// ONE GROUP PER PROCESS. The host's own CIPDF417CodeDescriptor dies in its own dealloc: every record is
// printed and the process then exits 139 (measured 2026-10-03), and one of the QR boundary cases traps. So a
// process answers ONE group, run.sh runs every group in both builds, and a group the host does not survive is
// compared on the records it printed and its exit status is reported beside them.
//
// A GROUP NAME IS A LIST OF SECTIONS, so that a section can belong to two groups (the payload cases of all
// four classes, for instance) without duplicating the cases themselves.
#import <Foundation/Foundation.h>
// The header only: this file names the five classes and two enums and calls nothing else of CoreImage, so
// the PORT build can link Foundation alone and define the classes itself. Linking CoreImage there would put
// the host's own classes in the same process under the same names, the host's would be registered first,
// and the port build would answer with the host's code - which is exactly what it did until a binding
// record below caught it (measured 2026-10-03: both builds printed the same answers because only one of
// them was running).
#import <CoreImage/CoreImage.h>
#include <dlfcn.h>
#include <objc/runtime.h>

static NSString *hexOf(NSData *data)
{
    if (!data)
        return @"(nil)";
    const unsigned char *bytes = data.bytes;
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < data.length && i < 16; i++)
        [out appendFormat:@"%02x", bytes[i]];
    if (data.length > 16)
        [out appendFormat:@"+%lu", (unsigned long)(data.length - 16)];
    return out;
}

static NSData *payloadOf(NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithCapacity:length];
    for (NSUInteger i = 0; i < length; i++) {
        uint8_t byte = (uint8_t)('a' + (i % 26));
        [data appendBytes:&byte length:1];
    }
    return data;
}

static void record(NSString *name, NSString *answer)
{
    printf("%s\t%s\n", name.UTF8String, answer.UTF8String);
}

// CIBarcodeDescriptor.h:26 declares the base class with no member at all, so each subclass's payload is read
// through that subclass's own property, which is what the header's declaration allows a caller to do.
// The class as a caller knows it. The port build renames the five classes so both can be in one process
// (see run.sh), and the rename is a build detail: a record identifies the descriptor by the name the SDK
// gives it, so the harness's own prefix is taken off here rather than compared as a difference.
static const char *apiName(id object)
{
    const char *name = class_getName([object class]);
    return (name && !strncmp(name, "Charon", 6)) ? name + 6 : name;
}

static NSString *show(id object)
{
    if (!object)
        return @"nil";
    if ([object isKindOfClass:[CIQRCodeDescriptor class]]) {
        CIQRCodeDescriptor *qr = object;
        return [NSString stringWithFormat:@"%s payload=%@ version=%ld mask=%u level=%ld", apiName(object),
                                          hexOf(qr.errorCorrectedPayload), (long)qr.symbolVersion,
                                          (unsigned)qr.maskPattern, (long)qr.errorCorrectionLevel];
    }
    if ([object isKindOfClass:[CIAztecCodeDescriptor class]]) {
        CIAztecCodeDescriptor *aztec = object;
        return [NSString stringWithFormat:@"%s payload=%@ compact=%d layers=%ld codewords=%ld",
                                          apiName(object), hexOf(aztec.errorCorrectedPayload),
                                          aztec.isCompact, (long)aztec.layerCount, (long)aztec.dataCodewordCount];
    }
    if ([object isKindOfClass:[CIPDF417CodeDescriptor class]]) {
        CIPDF417CodeDescriptor *pdf = object;
        return [NSString stringWithFormat:@"%s payload=%@ compact=%d rows=%ld columns=%ld",
                                          apiName(object), hexOf(pdf.errorCorrectedPayload),
                                          pdf.isCompact, (long)pdf.rowCount, (long)pdf.columnCount];
    }
    if ([object isKindOfClass:[CIDataMatrixCodeDescriptor class]]) {
        CIDataMatrixCodeDescriptor *matrix = object;
        return [NSString stringWithFormat:@"%s payload=%@ rows=%ld columns=%ld ecc=%ld", apiName(object),
                                          hexOf(matrix.errorCorrectedPayload), (long)matrix.rowCount,
                                          (long)matrix.columnCount, (long)matrix.eccVersion];
    }
    return [NSString stringWithFormat:@"%s (no member of its own)", apiName(object)];
}

// The four error-correction levels, named by index because their values are the CHARACTERS 'L', 'M', 'Q'
// and 'H' and not 0-3. An earlier sweep of these very questions passed the enum straight into a 0..3 loop and
// asked nothing at all, which is why this table exists and why the QR group has its own process.
static const CIQRCodeErrorCorrectionLevel kLevels[4] = { CIQRCodeErrorCorrectionLevelL, CIQRCodeErrorCorrectionLevelM,
                                                          CIQRCodeErrorCorrectionLevelQ, CIQRCodeErrorCorrectionLevelH };
static const char *kLevelNames[4] = { "L", "M", "Q", "H" };

static NSData *eight;
static NSData *one;
static NSData *empty;

// MARK: - the sweeps, one per class, each counting the whole of the header's range

static void sweepQR(void)
{
    NSUInteger answered = 0, total = 0;
    for (NSInteger version = 1; version <= 40; version++)
        for (uint8_t mask = 0; mask < 8; mask++)
            for (NSInteger level = 0; level < 4; level++) {
                total++;
                if ([CIQRCodeDescriptor descriptorWithPayload:eight symbolVersion:version maskPattern:mask
                                           errorCorrectionLevel:kLevels[level]])
                    answered++;
            }
    record(@"qr ranges answered", [NSString stringWithFormat:@"%lu of %lu", (unsigned long)answered,
                                                              (unsigned long)total]);
}

static void sweepAztec(void)
{
    NSUInteger answered = 0, total = 0;
    for (NSInteger layers = 1; layers <= 32; layers++)
        for (NSInteger codewords = 1; codewords <= 2048; codewords++)
            for (int compact = 0; compact < 2; compact++) {
                total++;
                if ([CIAztecCodeDescriptor descriptorWithPayload:one isCompact:compact layerCount:layers
                                                  dataCodewordCount:codewords])
                    answered++;
            }
    record(@"aztec ranges answered", [NSString stringWithFormat:@"%lu of %lu", (unsigned long)answered,
                                                                (unsigned long)total]);
}

static void sweepPDF417(void)
{
    NSUInteger answered = 0, total = 0;
    for (NSInteger rows = 3; rows <= 90; rows++)
        for (NSInteger columns = 1; columns <= 30; columns++)
            for (int compact = 0; compact < 2; compact++) {
                total++;
                if ([CIPDF417CodeDescriptor descriptorWithPayload:one isCompact:compact rowCount:rows
                                                   columnCount:columns])
                    answered++;
            }
    record(@"pdf417 ranges answered", [NSString stringWithFormat:@"%lu of %lu", (unsigned long)answered,
                                                                 (unsigned long)total]);
}

static void sweepMatrix(void)
{
    NSUInteger answered = 0, total = 0;
    for (NSInteger rows = 1; rows <= 40; rows++)
        for (NSInteger columns = 1; columns <= 40; columns++)
            for (int ecc = 0; ecc < 4; ecc++) {
                total++;
                if ([CIDataMatrixCodeDescriptor descriptorWithPayload:one rowCount:rows columnCount:columns
                                                     eccVersion:(CIDataMatrixCodeECCVersion)ecc])
                    answered++;
            }
    record(@"matrix ranges answered", [NSString stringWithFormat:@"%lu of %lu", (unsigned long)answered,
                                                                  (unsigned long)total]);
}

// MARK: - the boundaries, one case each, with the numbers the caller passed beside them

static void qrBounds(NSInteger version, uint8_t mask, CIQRCodeErrorCorrectionLevel level, NSString *label)
{
    record([NSString stringWithFormat:@"qr %@", label],
           show([CIQRCodeDescriptor descriptorWithPayload:eight symbolVersion:version maskPattern:mask
                                       errorCorrectionLevel:level]));
}

static void qrBoundsGroup(void)
{
    for (NSInteger version = 0; version <= 41; version++) {
        if (version != 0 && version != 1 && version != 2 && version != 40 && version != 41)
            continue;
        qrBounds(version, 3, CIQRCodeErrorCorrectionLevelQ, [NSString stringWithFormat:@"version %ld", (long)version]);
    }
    // every mask the argument can hold: the header says 0 to 7 and the host answers 8 and 255 as well, so
    // the mask is the one parameter with no upper bound of its own (a uint8_t cannot hold more)
    const NSInteger masks[] = { 0, 7, 8, 255 };
    for (size_t i = 0; i < sizeof masks / sizeof masks[0]; i++)
        qrBounds(5, (uint8_t)masks[i], CIQRCodeErrorCorrectionLevelM,
                 [NSString stringWithFormat:@"mask %ld", (long)masks[i]]);
    for (NSInteger level = 0; level < 4; level++)
        qrBounds(7, 5, kLevels[level], [NSString stringWithFormat:@"level %s", kLevelNames[level]]);
}

static void aztecBoundsGroup(void)
{
    for (NSInteger layers = 0; layers <= 33; layers++) {
        if (layers != 0 && layers != 1 && layers != 32 && layers != 33)
            continue;
        record([NSString stringWithFormat:@"aztec layers %ld", (long)layers],
               show([CIAztecCodeDescriptor descriptorWithPayload:eight isCompact:NO layerCount:layers
                                                dataCodewordCount:8]));
    }
    for (NSInteger codewords = 0; codewords <= 2049; codewords++) {
        if (codewords != 0 && codewords != 1 && codewords != 2048 && codewords != 2049)
            continue;
        record([NSString stringWithFormat:@"aztec codewords %ld", (long)codewords],
               show([CIAztecCodeDescriptor descriptorWithPayload:eight isCompact:NO layerCount:2
                                                dataCodewordCount:codewords]));
    }
}

static void pdf417RowsGroup(void)
{
    for (NSInteger rows = 1; rows <= 4; rows++)
        record([NSString stringWithFormat:@"pdf417 rows %ld", (long)rows],
               show([CIPDF417CodeDescriptor descriptorWithPayload:eight isCompact:NO rowCount:rows columnCount:4]));
    for (NSInteger rows = 89; rows <= 91; rows++)
        record([NSString stringWithFormat:@"pdf417 rows %ld", (long)rows],
               show([CIPDF417CodeDescriptor descriptorWithPayload:eight isCompact:NO rowCount:rows columnCount:4]));
}

static void pdf417ColumnsGroup(void)
{
    for (NSInteger columns = 0; columns <= 31; columns++) {
        if (columns != 0 && columns != 1 && columns != 30 && columns != 31)
            continue;
        record([NSString stringWithFormat:@"pdf417 columns %ld", (long)columns],
               show([CIPDF417CodeDescriptor descriptorWithPayload:eight isCompact:NO rowCount:6
                                                    columnCount:columns]));
    }
}

static void matrixBoundsGroup(void)
{
    for (NSInteger ecc = -1; ecc <= 4; ecc++) {
        if (ecc != -1 && ecc != 0 && ecc != 3 && ecc != 4)
            continue;
        record([NSString stringWithFormat:@"matrix ecc %ld", (long)ecc],
               show([CIDataMatrixCodeDescriptor descriptorWithPayload:eight rowCount:12 columnCount:12
                                                     eccVersion:(CIDataMatrixCodeECCVersion)ecc]));
    }
    for (NSInteger rows = 0; rows <= 1; rows++)
        for (NSInteger columns = 0; columns <= 1; columns++)
            record([NSString stringWithFormat:@"matrix %ldx%ld", (long)rows, (long)columns],
                   show([CIDataMatrixCodeDescriptor descriptorWithPayload:eight rowCount:rows columnCount:columns
                                                         eccVersion:CIDataMatrixCodeECCVersion000]));
}

// MARK: - the payload itself

static void payloadCases(BOOL withPDF417)
{
    NSData *payloads[4] = { nil, empty, one, eight };
    const char *labels[4] = { "nil", "empty", "one", "eight" };
    for (int which = 0; which < 4; which++) {
        NSData *payload = payloads[which];
        NSString *label = @(labels[which]);
        record([NSString stringWithFormat:@"payload %@ qr", label],
               show([CIQRCodeDescriptor descriptorWithPayload:payload symbolVersion:4 maskPattern:2
                                           errorCorrectionLevel:CIQRCodeErrorCorrectionLevelL]));
        record([NSString stringWithFormat:@"payload %@ aztec", label],
               show([CIAztecCodeDescriptor descriptorWithPayload:payload isCompact:YES layerCount:3
                                                dataCodewordCount:16]));
        record([NSString stringWithFormat:@"payload %@ matrix", label],
               show([CIDataMatrixCodeDescriptor descriptorWithPayload:payload rowCount:10 columnCount:10
                                                     eccVersion:CIDataMatrixCodeECCVersion100]));
        if (withPDF417)
            record([NSString stringWithFormat:@"payload %@ pdf417", label],
                   show([CIPDF417CodeDescriptor descriptorWithPayload:payload isCompact:NO rowCount:8 columnCount:8]));
    }
}

static void payloadCopied(void)
{
    NSMutableData *mutable = [eight mutableCopy];
    CIAztecCodeDescriptor *held = [CIAztecCodeDescriptor descriptorWithPayload:mutable
                                                                     isCompact:NO
                                                                    layerCount:2
                                                             dataCodewordCount:8];
    [mutable appendBytes:"ZZ" length:2];
    record(@"payload copied from the caller",
           held ? [NSString stringWithFormat:@"%@ len=%lu", hexOf(held.errorCorrectedPayload),
                                         (unsigned long)held.errorCorrectedPayload.length]
                : @"nil");
}

static void factoryIsInit(void)
{
    CIQRCodeDescriptor *made = [CIQRCodeDescriptor descriptorWithPayload:eight
                                                          symbolVersion:11
                                                            maskPattern:6
                                                   errorCorrectionLevel:CIQRCodeErrorCorrectionLevelH];
    CIQRCodeDescriptor *begun = [[CIQRCodeDescriptor alloc] initWithPayload:eight
                                                               symbolVersion:11
                                                                 maskPattern:6
                                                        errorCorrectionLevel:CIQRCodeErrorCorrectionLevelH];
    record(@"qr factory is init", made && begun && [made isEqual:begun] ? @"same" : @"different");
}

// MARK: - NSCopying and NSSecureCoding, which the header declares the classes as

static void copyAndArchive(BOOL withPDF417)
{
    CIAztecCodeDescriptor *aztec = [CIAztecCodeDescriptor descriptorWithPayload:eight
                                                                     isCompact:YES
                                                                    layerCount:7
                                                             dataCodewordCount:64];
    CIAztecCodeDescriptor *copied = [aztec copy];
    record(@"aztec copy", show(copied));
    record(@"aztec copy is another object", copied && copied != aztec ? @"yes" : @"no");
    record(@"aztec archive round trip",
           show([NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:aztec]]));
    CIDataMatrixCodeDescriptor *matrix = [CIDataMatrixCodeDescriptor descriptorWithPayload:eight
                                                                                  rowCount:26
                                                                               columnCount:14
                                                                                eccVersion:CIDataMatrixCodeECCVersion140];
    record(@"matrix copy", show([matrix copy]));
    record(@"matrix archive round trip",
           show([NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:matrix]]));
    CIQRCodeDescriptor *qr = [CIQRCodeDescriptor descriptorWithPayload:eight
                                                         symbolVersion:9
                                                           maskPattern:4
                                                  errorCorrectionLevel:CIQRCodeErrorCorrectionLevelQ];
    record(@"qr copy", show([qr copy]));
    record(@"qr archive round trip",
           show([NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:qr]]));
    record(@"secure coding", [NSString stringWithFormat:@"%d/%d/%d", (int)[(id<NSSecureCoding>)aztec supportsSecureCoding],
                                                           (int)[(id<NSSecureCoding>)matrix supportsSecureCoding],
                                                           (int)[(id<NSSecureCoding>)qr supportsSecureCoding]]);
    if (withPDF417) {
        CIPDF417CodeDescriptor *pdf = [CIPDF417CodeDescriptor descriptorWithPayload:eight
                                                                         isCompact:YES
                                                                          rowCount:20
                                                                       columnCount:12];
        record(@"pdf417 copy", show([pdf copy]));
        record(@"pdf417 archive round trip",
               show([NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:pdf]]));
    }
}

static void whatADescriptorIs(void)
{
    CIQRCodeDescriptor *qr = [CIQRCodeDescriptor descriptorWithPayload:eight
                                                         symbolVersion:3
                                                           maskPattern:1
                                                  errorCorrectionLevel:CIQRCodeErrorCorrectionLevelL];
    CIDataMatrixCodeDescriptor *matrix = [CIDataMatrixCodeDescriptor descriptorWithPayload:eight
                                                                                  rowCount:4
                                                                               columnCount:4
                                                                                eccVersion:CIDataMatrixCodeECCVersion000];
    record(@"descriptor is an NSObject", [qr isKindOfClass:[NSObject class]] ? @"yes" : @"no");
    record(@"qr is a barcode descriptor", [qr isKindOfClass:[CIBarcodeDescriptor class]] ? @"yes" : @"no");
    record(@"matrix is a qr descriptor", [matrix isKindOfClass:[CIQRCodeDescriptor class]] ? @"yes" : @"no");
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        NSString *group = argc > 1 ? @(argv[1]) : @"";

        // The port's own answer has to come from the port's own class. dladdr on a method IMP says which
        // image it is in, and the host's CoreImage is the other one.
#ifdef CHARON_PORT
        {
            IMP imp = [CIPDF417CodeDescriptor instanceMethodForSelector:@selector(rowCount)];
            Dl_info info;
            const char *where = (dladdr((const void *)imp, &info) && info.dli_fname) ? info.dli_fname : "(unknown)";
            printf("PORTONLY binding\t%s\n", strstr(where, "CoreImage") ? "host" : "port");
            const char *aztec = class_getName([CIAztecCodeDescriptor class]);
            printf("PORTONLY aztec-class\t%s\n", aztec);
        }
#endif
        eight = payloadOf(8);
        one = payloadOf(1);
        empty = payloadOf(0);

        if ([group isEqualToString:@"sweep-qr"]) { sweepQR(); return 0; }
        if ([group isEqualToString:@"sweep-aztec"]) { sweepAztec(); return 0; }
        if ([group isEqualToString:@"sweep-pdf417"]) { sweepPDF417(); return 0; }
        if ([group isEqualToString:@"sweep-matrix"]) { sweepMatrix(); return 0; }
        if ([group isEqualToString:@"qr"]) { qrBoundsGroup(); return 0; }
        if ([group isEqualToString:@"aztec"]) { aztecBoundsGroup(); return 0; }
        if ([group isEqualToString:@"pdf417-rows"]) { pdf417RowsGroup(); return 0; }
        if ([group isEqualToString:@"pdf417-columns"]) { pdf417ColumnsGroup(); return 0; }
        if ([group isEqualToString:@"matrix"]) { matrixBoundsGroup(); return 0; }
        if ([group isEqualToString:@"payload"]) { payloadCases(YES); payloadCopied(); factoryIsInit(); return 0; }
        if ([group isEqualToString:@"payload-no-pdf417"]) { payloadCases(NO); payloadCopied(); factoryIsInit(); return 0; }
        if ([group isEqualToString:@"copy"]) { copyAndArchive(YES); whatADescriptorIs(); return 0; }
        if ([group isEqualToString:@"copy-no-pdf417"]) { copyAndArchive(NO); whatADescriptorIs(); return 0; }
        printf("FAIL  unknown group %s\n", group.UTF8String);
        return 2;
    }
}