#import "CharonMetal.h"

// THE 21 STRING CONSTANTS OF THE 14.0 BAND: fifteen MTLCommonCounter, three MTLCommonCounterSet,
// and three NSErrorDomain. Every one of them is an NSString* the header DECLARES and never spells -
// the SDK's apinotes say which error class each domain belongs to, not what the string is - so every
// value below is APPLE'S OWN, MEASURED, and
// tests/backports/host/metal-census/counters.m repeats that measurement on every run by dlsym'ing
// Apple's own Metal and comparing the bytes.
//
// A NAME IS NOT A VALUE. MTLCommonCounterSetTimestamp is "timestamp" - nine bytes, all lower case -
// and MTLCommonCounterSetStageUtilization is "stageutilization", and neither is what its name
// suggests. Guessing from the name would have been wrong in four places and no compiler would have
// said so.


// MTLCommonCounterTimestamp: SDK 16.4 MTLCounters.h:43.// The header declares the name; the string is Apple's own, measured with dlsym on Apple's
// Metal rather than written from the name.
MTL_EXTERN MTLCommonCounter const MTLCommonCounterTimestamp;
MTLCommonCounter const MTLCommonCounterTimestamp = @"GPUTimestamp";

// MTLCommonCounterTessellationInputPatches: SDK 16.4 MTLCounters.h:44. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterTessellationInputPatches;
MTLCommonCounter const MTLCommonCounterTessellationInputPatches = @"TessellationInputPatches";

// MTLCommonCounterVertexInvocations: SDK 16.4 MTLCounters.h:45. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterVertexInvocations;
MTLCommonCounter const MTLCommonCounterVertexInvocations = @"VertexInvocations";

// MTLCommonCounterPostTessellationVertexInvocations: SDK 16.4 MTLCounters.h:46. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterPostTessellationVertexInvocations;
MTLCommonCounter const MTLCommonCounterPostTessellationVertexInvocations = @"PostTessellationVertexInvocations";

// MTLCommonCounterClipperInvocations: SDK 16.4 MTLCounters.h:47. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterClipperInvocations;
MTLCommonCounter const MTLCommonCounterClipperInvocations = @"ClipperInvocations";

// MTLCommonCounterClipperPrimitivesOut: SDK 16.4 MTLCounters.h:48. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterClipperPrimitivesOut;
MTLCommonCounter const MTLCommonCounterClipperPrimitivesOut = @"ClipperPrimitivesOut";

// MTLCommonCounterFragmentInvocations: SDK 16.4 MTLCounters.h:49. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterFragmentInvocations;
MTLCommonCounter const MTLCommonCounterFragmentInvocations = @"FragmentInvocations";

// MTLCommonCounterFragmentsPassed: SDK 16.4 MTLCounters.h:50. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterFragmentsPassed;
MTLCommonCounter const MTLCommonCounterFragmentsPassed = @"FragmentsPassed";

// MTLCommonCounterComputeKernelInvocations: SDK 16.4 MTLCounters.h:51. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterComputeKernelInvocations;
MTLCommonCounter const MTLCommonCounterComputeKernelInvocations = @"KernelInvocations";

// MTLCommonCounterTotalCycles: SDK 16.4 MTLCounters.h:52. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterTotalCycles;
MTLCommonCounter const MTLCommonCounterTotalCycles = @"TotalCycles";

// MTLCommonCounterVertexCycles: SDK 16.4 MTLCounters.h:53. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterVertexCycles;
MTLCommonCounter const MTLCommonCounterVertexCycles = @"VertexCycles";

// MTLCommonCounterTessellationCycles: SDK 16.4 MTLCounters.h:54. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterTessellationCycles;
MTLCommonCounter const MTLCommonCounterTessellationCycles = @"TessellationCycles";

// MTLCommonCounterPostTessellationVertexCycles: SDK 16.4 MTLCounters.h:55. The value is
// "PostTessellationCycle" and NOT "PostTessellationVertexCycles", which is the string the
// INVOCATIONS constant carries: the first version of this file wrote it from the name, the case
// caught it by length, and the name is not the value.
// The header declares the name; the string is Apple's own, measured with dlsym on
// Apple's Metal rather than written from the name.
MTL_EXTERN MTLCommonCounter const MTLCommonCounterPostTessellationVertexCycles;
MTLCommonCounter const MTLCommonCounterPostTessellationVertexCycles = @"PostTessellationCycle";

// MTLCommonCounterFragmentCycles: SDK 16.4 MTLCounters.h:56. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterFragmentCycles;
MTLCommonCounter const MTLCommonCounterFragmentCycles = @"FragmentCycles";

// MTLCommonCounterRenderTargetWriteCycles: SDK 16.4 MTLCounters.h:57. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounter const MTLCommonCounterRenderTargetWriteCycles;
MTLCommonCounter const MTLCommonCounterRenderTargetWriteCycles = @"RenderTargetWriteCycles";

// MTLCommonCounterSetTimestamp: SDK 16.4 MTLCounters.h:69. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounterSet const MTLCommonCounterSetTimestamp;
MTLCommonCounterSet const MTLCommonCounterSetTimestamp = @"timestamp";

// MTLCommonCounterSetStageUtilization: SDK 16.4 MTLCounters.h:70. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounterSet const MTLCommonCounterSetStageUtilization;
MTLCommonCounterSet const MTLCommonCounterSetStageUtilization = @"stageutilization";

// MTLCommonCounterSetStatistic: SDK 16.4 MTLCounters.h:71. The header declares the name; the string is Apple's own,
MTL_EXTERN MTLCommonCounterSet const MTLCommonCounterSetStatistic;
MTLCommonCounterSet const MTLCommonCounterSetStatistic = @"statistic";

// MTLCounterErrorDomain: SDK 16.4 MTLCounters.h:202. The header declares the name; the string is Apple's own,
MTL_EXTERN NSErrorDomain const MTLCounterErrorDomain;
NSErrorDomain const MTLCounterErrorDomain = @"MTLCounterErrorDomain";

// MTLBinaryArchiveDomain: SDK 16.4 MTLBinaryArchive.h:17. The header declares the name; the string is Apple's own,
MTL_EXTERN NSErrorDomain const MTLBinaryArchiveDomain;
NSErrorDomain const MTLBinaryArchiveDomain = @"MTLBinaryArchiveDomain";

// MTLDynamicLibraryDomain: SDK 16.4 MTLDynamicLibrary.h:14. The header declares the name; the string is Apple's own,
MTL_EXTERN NSErrorDomain const MTLDynamicLibraryDomain;
NSErrorDomain const MTLDynamicLibraryDomain = @"MTLDynamicLibraryDomain";
