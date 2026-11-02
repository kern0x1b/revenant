#include "../revenant_impl.h"
#import "RevenantMetal.h"


MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterTimestamp);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterTimestamp) = @"GPUTimestamp";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterTessellationInputPatches);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterTessellationInputPatches) = @"TessellationInputPatches";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterVertexInvocations);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterVertexInvocations) = @"VertexInvocations";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterPostTessellationVertexInvocations);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterPostTessellationVertexInvocations) = @"PostTessellationVertexInvocations";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterClipperInvocations);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterClipperInvocations) = @"ClipperInvocations";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterClipperPrimitivesOut);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterClipperPrimitivesOut) = @"ClipperPrimitivesOut";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterFragmentInvocations);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterFragmentInvocations) = @"FragmentInvocations";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterFragmentsPassed);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterFragmentsPassed) = @"FragmentsPassed";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterComputeKernelInvocations);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterComputeKernelInvocations) = @"KernelInvocations";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterTotalCycles);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterTotalCycles) = @"TotalCycles";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterVertexCycles);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterVertexCycles) = @"VertexCycles";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterTessellationCycles);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterTessellationCycles) = @"TessellationCycles";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterPostTessellationVertexCycles);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterPostTessellationVertexCycles) = @"PostTessellationCycle";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterFragmentCycles);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterFragmentCycles) = @"FragmentCycles";

MTL_EXTERN MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterRenderTargetWriteCycles);
MTLCommonCounter const BACKPORT_IMPL(MTLCommonCounterRenderTargetWriteCycles) = @"RenderTargetWriteCycles";

MTL_EXTERN MTLCommonCounterSet const BACKPORT_IMPL(MTLCommonCounterSetTimestamp);
MTLCommonCounterSet const BACKPORT_IMPL(MTLCommonCounterSetTimestamp) = @"timestamp";

MTL_EXTERN MTLCommonCounterSet const BACKPORT_IMPL(MTLCommonCounterSetStageUtilization);
MTLCommonCounterSet const BACKPORT_IMPL(MTLCommonCounterSetStageUtilization) = @"stageutilization";

MTL_EXTERN MTLCommonCounterSet const BACKPORT_IMPL(MTLCommonCounterSetStatistic);
MTLCommonCounterSet const BACKPORT_IMPL(MTLCommonCounterSetStatistic) = @"statistic";

MTL_EXTERN NSErrorDomain const MTLCounterErrorDomain;
NSErrorDomain const MTLCounterErrorDomain = @"MTLCounterErrorDomain";

MTL_EXTERN NSErrorDomain const BACKPORT_IMPL(MTLBinaryArchiveDomain);
NSErrorDomain const BACKPORT_IMPL(MTLBinaryArchiveDomain) = @"MTLBinaryArchiveDomain";

MTL_EXTERN NSErrorDomain const BACKPORT_IMPL(MTLDynamicLibraryDomain);
NSErrorDomain const BACKPORT_IMPL(MTLDynamicLibraryDomain) = @"MTLDynamicLibraryDomain";
