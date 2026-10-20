#import "RevenantMPS.h"


@implementation MPSMatrixCopy {
    NSUInteger _copyRows, _copyColumns;
    BOOL _sourcesAreTransposed, _destinationsAreTransposed;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSMatrixCopy: -initWithDevice: names no region; use -initWithDevice:copyRows:copyColumns:sourcesAreTransposed:destinationsAreTransposed:");
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device copyRows:(NSUInteger)copyRows copyColumns:(NSUInteger)copyColumns sourcesAreTransposed:(BOOL)sourcesAreTransposed destinationsAreTransposed:(BOOL)destinationsAreTransposed
{
    if ((self = [super initWithDevice:device])) {
        _copyRows = copyRows;
        _copyColumns = copyColumns;
        _sourcesAreTransposed = sourcesAreTransposed;
        _destinationsAreTransposed = destinationsAreTransposed;
    }
    return self;
}

- (NSUInteger)copyRows
{
    return _copyRows;
}

- (NSUInteger)copyColumns
{
    return _copyColumns;
}

- (BOOL)sourcesAreTransposed
{
    return _sourcesAreTransposed;
}

- (BOOL)destinationsAreTransposed
{
    return _destinationsAreTransposed;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer copyDescriptor:(MPSMatrixCopyDescriptor *)copyDescriptor
{
    [self encodeToCommandBuffer:commandBuffer copyDescriptor:copyDescriptor rowPermuteIndices:nil rowPermuteOffset:0 columnPermuteIndices:nil columnPermuteOffset:0];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               copyDescriptor:(MPSMatrixCopyDescriptor *)copyDescriptor
            rowPermuteIndices:(MPSVector *)rowPermuteIndices
             rowPermuteOffset:(NSUInteger)rowPermuteOffset
         columnPermuteIndices:(MPSVector *)columnPermuteIndices
          columnPermuteOffset:(NSUInteger)columnPermuteOffset
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    for (NSUInteger index = 0; index < [copyDescriptor revenant_mps_count]; index++) {
        MPSMatrix *source = [copyDescriptor revenant_mps_sourceAtIndex:index];
        MPSMatrix *destination = [copyDescriptor revenant_mps_destinationAtIndex:index];
        MPSMatrixCopyOffsets offsets = [copyDescriptor revenant_mps_offsetsAtIndex:index];
        if (!source || !destination) {
            RevenantMPSRefuse(@"MPSMatrixCopy: copy operation %lu names no source or no destination", (unsigned long)index);
            continue;
        }
        RevenantMPSMatrixView from = RevenantMPSMatrixViewOf(source), to = RevenantMPSMatrixViewOf(destination);
        if (!RevenantMPSDataTypeIsElement(from.dataType) || !RevenantMPSDataTypeIsElement(to.dataType)) {
            RevenantMPSRefuse(@"MPSMatrixCopy: a matrix of a data type that is not one of the eight element types was given");
            continue;
        }
        NSUInteger sourceRows = _sourcesAreTransposed ? _copyColumns : _copyRows;
        NSUInteger sourceColumns = _sourcesAreTransposed ? _copyRows : _copyColumns;
        NSUInteger destinationRows = _destinationsAreTransposed ? _copyColumns : _copyRows;
        NSUInteger destinationColumns = _destinationsAreTransposed ? _copyRows : _copyColumns;
        if (!RevenantMPSMatrixHolds(&from, 0, offsets.sourceRowOffset, offsets.sourceColumnOffset, sourceRows, sourceColumns) ||
            !RevenantMPSMatrixHolds(&to, 0, offsets.destinationRowOffset, offsets.destinationColumnOffset, destinationRows, destinationColumns)) {
            RevenantMPSRefuse(@"MPSMatrixCopy: copy operation %lu names a %lux%lu region a matrix does not hold", (unsigned long)index, (unsigned long)_copyRows, (unsigned long)_copyColumns);
            continue;
        }
        for (NSUInteger row = 0; row < _copyRows; row++) {
            for (NSUInteger column = 0; column < _copyColumns; column++) {
                NSUInteger sourceRow = _sourcesAreTransposed ? column : row;
                NSUInteger sourceColumn = _sourcesAreTransposed ? row : column;
                NSUInteger destinationRow = _destinationsAreTransposed ? column : row;
                NSUInteger destinationColumn = _destinationsAreTransposed ? row : column;
                if (rowPermuteIndices) {
                    NSUInteger permuted = (NSUInteger)RevenantMPSLoad((const char *)[[rowPermuteIndices data] contents] + rowPermuteOffset + row * 4, MPSDataTypeUInt32, 0);
                    if (permuted >= _copyRows) {
                        RevenantMPSRefuse(@"MPSMatrixCopy: row permute index %lu names no row of %lu", (unsigned long)permuted, (unsigned long)_copyRows);
                        return;
                    }
                    sourceRow = permuted;
                }
                if (columnPermuteIndices) {
                    NSUInteger permuted = (NSUInteger)RevenantMPSLoad((const char *)[[columnPermuteIndices data] contents] + columnPermuteOffset + column * 4, MPSDataTypeUInt32, 0);
                    if (permuted >= _copyColumns) {
                        RevenantMPSRefuse(@"MPSMatrixCopy: column permute index %lu names no column of %lu", (unsigned long)permuted, (unsigned long)_copyColumns);
                        return;
                    }
                    sourceColumn = permuted;
                }
                double value = RevenantMPSLoad(RevenantMPSMatrixElement(&from, 0, offsets.sourceRowOffset + sourceRow, offsets.sourceColumnOffset + sourceColumn), from.dataType, 0);
                RevenantMPSStore(RevenantMPSMatrixElement(&to, 0, offsets.destinationRowOffset + destinationRow, offsets.destinationColumnOffset + destinationColumn), to.dataType, 0, value);
            }
        }
        RevenantMPSConsumeReadCount(source);
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _copyRows = 0;
        _copyColumns = 0;
    }
    return self;
}

@end
