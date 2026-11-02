#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

const CFStringRef BACKPORT_IMPL(kCVImageBufferTransferFunction_sRGB) = CFSTR("IEC_sRGB");
const CFStringRef BACKPORT_IMPL(kCVImageBufferTransferFunction_ITU_R_2100_HLG) = CFSTR("ITU_R_2100_HLG");
const CFStringRef BACKPORT_IMPL(kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ) = CFSTR("SMPTE_ST_2084_PQ");
const CFStringRef BACKPORT_IMPL(kCVImageBufferContentLightLevelInfoKey) = CFSTR("ContentLightLevelInfo");
const CFStringRef BACKPORT_IMPL(kCVImageBufferMasteringDisplayColorVolumeKey) = CFSTR("MasteringDisplayColorVolume");
