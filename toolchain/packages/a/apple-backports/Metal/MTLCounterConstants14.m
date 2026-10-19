#import "CharonMetal.h"


MTL_EXTERN MTLCommonCounter const MTLCommonCounterTimestamp;
MTLCommonCounter const MTLCommonCounterTimestamp = @"GPUTimestamp";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterTessellationInputPatches;
MTLCommonCounter const MTLCommonCounterTessellationInputPatches = @"TessellationInputPatches";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterVertexInvocations;
MTLCommonCounter const MTLCommonCounterVertexInvocations = @"VertexInvocations";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterPostTessellationVertexInvocations;
MTLCommonCounter const MTLCommonCounterPostTessellationVertexInvocations = @"PostTessellationVertexInvocations";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterClipperInvocations;
MTLCommonCounter const MTLCommonCounterClipperInvocations = @"ClipperInvocations";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterClipperPrimitivesOut;
MTLCommonCounter const MTLCommonCounterClipperPrimitivesOut = @"ClipperPrimitivesOut";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterFragmentInvocations;
MTLCommonCounter const MTLCommonCounterFragmentInvocations = @"FragmentInvocations";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterFragmentsPassed;
MTLCommonCounter const MTLCommonCounterFragmentsPassed = @"FragmentsPassed";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterComputeKernelInvocations;
MTLCommonCounter const MTLCommonCounterComputeKernelInvocations = @"KernelInvocations";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterTotalCycles;
MTLCommonCounter const MTLCommonCounterTotalCycles = @"TotalCycles";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterVertexCycles;
MTLCommonCounter const MTLCommonCounterVertexCycles = @"VertexCycles";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterTessellationCycles;
MTLCommonCounter const MTLCommonCounterTessellationCycles = @"TessellationCycles";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterPostTessellationVertexCycles;
MTLCommonCounter const MTLCommonCounterPostTessellationVertexCycles = @"PostTessellationCycle";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterFragmentCycles;
MTLCommonCounter const MTLCommonCounterFragmentCycles = @"FragmentCycles";

MTL_EXTERN MTLCommonCounter const MTLCommonCounterRenderTargetWriteCycles;
MTLCommonCounter const MTLCommonCounterRenderTargetWriteCycles = @"RenderTargetWriteCycles";

MTL_EXTERN MTLCommonCounterSet const MTLCommonCounterSetTimestamp;
MTLCommonCounterSet const MTLCommonCounterSetTimestamp = @"timestamp";

MTL_EXTERN MTLCommonCounterSet const MTLCommonCounterSetStageUtilization;
MTLCommonCounterSet const MTLCommonCounterSetStageUtilization = @"stageutilization";

MTL_EXTERN MTLCommonCounterSet const MTLCommonCounterSetStatistic;
MTLCommonCounterSet const MTLCommonCounterSetStatistic = @"statistic";

MTL_EXTERN NSErrorDomain const MTLCounterErrorDomain;
NSErrorDomain const MTLCounterErrorDomain = @"MTLCounterErrorDomain";

MTL_EXTERN NSErrorDomain const MTLBinaryArchiveDomain;
NSErrorDomain const MTLBinaryArchiveDomain = @"MTLBinaryArchiveDomain";

MTL_EXTERN NSErrorDomain const MTLDynamicLibraryDomain;
NSErrorDomain const MTLDynamicLibraryDomain = @"MTLDynamicLibraryDomain";
