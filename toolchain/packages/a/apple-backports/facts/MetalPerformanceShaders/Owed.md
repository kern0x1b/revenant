# What MetalPerformanceShaders still owes, per class family

This page was written by the MPS owed count (removed). Every number is
produced by that script and every rule below is implemented in it.

## The counting rule

A **family** is the SDK's own header file name minus `.h`. MPSImageReduce.h declares the
reductions, so those are one family because the SDK puts them in one file. Membership is
read off the headers - the script finds which header declares each API - and is never a
name list written by hand, which is what rots. An API no header declares is reported
separately instead of being guessed into a neighbouring family.

**owed** is rows in `absent_MetalPerformanceShaders.json` whose api a header of that family declares.
**26.2 headers** is the MPS types the iPhoneOS 26.2 surface declares there. **introduced**
is the registry row's own field, never guessed from header text.

Demand is not the ranking, and that is measured: MPS has no rows in the corpus hint ledger
and none in any crash-demand file, because a compute framework is not in a crash top-list.
So the ranking is owed surface, which is what the registry and the headers can count.

## Owed per family, biggest first

| family | owed | 26.2 headers | introduced |
| --- | ---: | ---: | --- |
| MPSNNGraphNodes | 115 | 121 | 11.0:42 11.3:38 12.1:22 13.0:13 |
| MPSNNReduce | 19 | 19 | 11.3:16 12.0:2 13.0:1 |
| MPSCNNNeuron | 17 | 17 | 10.0:6 11.0:6 11.3:5 |
| MPSCNNConvolution | 13 | 16 | 10.0:1 11.0:5 11.3:3 13.0:4 |
| MPSImageConvolution | 12 | 12 | 10.0:6 14.0:1 9.0:5 |
| MPSCNNMath | 11 | 11 | 11.3:10 12.1:1 |
| MPSRNNLayer | 10 | 10 | 11.0:8 12.0:2 |
| MPSCNNLoss | 9 | 9 | 11.3:4 12:1 12.0:1 13.0:3 |
| MPSImageReduce | 9 | 9 | 11.3:9 |
| MPSNDArrayKernel | 8 | 8 | 13:2 13.0:6 |
| MPSCNNPooling | 7 | 10 | 11.0:2 11.3:5 |
| MPSCNNNormalization | 6 | 6 | 10.0:3 11.3:3 |
| MPSCNNUpsampling | 6 | 6 | 11.0:3 11.3:3 |
| MPSCNNBatchNormalization | 5 | 6 | 11.3:4 12.0:1 |
| MPSImage | 5 | 4 | 10.0:1 11.3:2 12.0:1 13.0:1 |
| MPSNNOptimizers | 5 | 5 | 12.0:5 |
| MPSCNNSoftMax | 4 | 4 | 10.0:2 11.3:2 |
| MPSImageHistogram | 4 | 4 | 9.0:4 |
| MPSImageMorphology | 4 | 4 | 9.0:4 |
| MPSNNReshape | 4 | 4 | 11.3:1 12.1:3 |
| MPSSVGF | 4 | 4 | 13.0:4 |
| MPSCNNDropout | 3 | 3 | 11.3:3 |
| MPSCNNGroupNormalization | 3 | 3 | 13.0:3 |
| MPSCNNInstanceNormalization | 3 | 3 | 11.3:3 |
| MPSCNNKernel | 3 | 4 | 11.0:1 11.3:1 13.0:1 |
| MPSImageResampling | 3 | 3 | 11.0:2 9.0:1 |
| MPSImageStatistics | 3 | 3 | 11.0:3 |
| MPSMatrixSolve | 3 | 3 | 11.0:3 |
| MPSNDArray | 3 | 4 | 13.0:3 |
| MPSNDArrayGather | 3 | 3 | 13:2 13.0:1 |
| MPSNNGradientState | 3 | 3 | 11.3:2 13.0:1 |
| MPSImageIntegral | 2 | 2 | 9.0:2 |
| MPSMatrixDecomposition | 2 | 2 | 11.0:2 |
| MPSNDArrayStridedSlice | 2 | 2 | 13:2 |
| MPSNNResize | 2 | 2 | 12.0:2 |
| MPSAccelerationStructure | 1 | 1 | 12.0:1 |
| MPSAccelerationStructureGroup | 1 | 1 | 12.0:1 |
| MPSCNNNormalizationWeights | 1 | 1 | 11.3:1 |
| MPSImageConversion | 1 | 1 | 10.0:1 |
| MPSImageCopy | 1 | 2 | 12.0:1 |
| MPSImageDistanceTransform | 1 | 1 | 11.3:1 |
| MPSImageEDLines | 1 | 1 | 13.4:1 |
| MPSImageGuidedFilter | 1 | 1 | 11.3:1 |
| MPSImageKeypoint | 1 | 1 | 11.0:1 |
| MPSImageMedian | 1 | 1 | 9.0:1 |
| MPSInstanceAccelerationStructure | 1 | 1 | 12.0:1 |
| MPSKeyedUnarchiver | 1 | 1 | 11.3:1 |
| MPSNDArrayGradientState | 1 | 1 | 13.0:1 |
| MPSNDArrayMatrixMultiplication | 1 | 1 | 13:1 |
| MPSNNGraph | 1 | 1 | 11.0:1 |
| MPSNNGridSample | 1 | 1 | 13.0:1 |
| MPSNNSlice | 1 | 1 | 11.3:1 |
| MPSNeuralNetworkTypes | 1 | 3 | 11.0:1 |
| MPSPolygonAccelerationStructure | 1 | 1 | 13.0:1 |
| MPSPolygonBuffer | 1 | 1 | 13.0:1 |
| MPSQuadrilateralAccelerationStructure | 1 | 1 | 13.0:1 |
| MPSRayIntersector | 1 | 1 | 12.0:1 |
| MPSTemporalAA | 1 | 1 | 13.0:1 |
| MPSTriangleAccelerationStructure | 1 | 1 | 12.0:1 |
| **total** | **339** | **412** | |

## Attributable to no 26.2 header

6 rows, listed rather than guessed into a neighbour:

- `-[MPSCNNConvolutionDataSource copyWithZone:device:]`
- `-[MPSCNNConvolutionDataSource kernelWeightsDataType]`
- `-[MPSCNNConvolutionDataSource updateWithCommandBuffer:gradientState:sourceState:]`
- `-[MPSCNNConvolutionDataSource updateWithGradientState:sourceState:]`
- `-[MPSCNNConvolutionDataSource weightsLayout]`
- `-[MPSNNPadding inverse]`

## Read from

- SDK: `$HOME/Git/projects/ios/revenant/.agent-work/sdk-26.2/iPhoneOS26.2.sdk`
- registry: `packages/a/apple-backports/registry/MetalPerformanceShaders/absent_MetalPerformanceShaders.json`
- headers: 95 under `System/Library/Frameworks/MetalPerformanceShaders.framework`, declaring 412 MPS types

