#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_GammaLevel) = CFSTR("GammaLevel");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MultiPassStorage) = CFSTR("MultiPassStorage");
const CFStringRef BACKPORT_IMPL(kVTDecompressionPropertyKey_OutputPoolRequestedMinimumBufferCount) = CFSTR("OutputPoolRequestedMinimumBufferCount");
const CFStringRef BACKPORT_IMPL(kVTMultiPassStorageCreationOption_DoNotDelete) = CFSTR("DoNotDelete");
const CFStringRef BACKPORT_IMPL(kVTPixelTransferPropertyKey_RealTime) = CFSTR("RealTime");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_Baseline_4_0) = CFSTR("H264_Baseline_4_0");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_Baseline_4_2) = CFSTR("H264_Baseline_4_2");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_Baseline_5_0) = CFSTR("H264_Baseline_5_0");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_Baseline_5_1) = CFSTR("H264_Baseline_5_1");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_Baseline_5_2) = CFSTR("H264_Baseline_5_2");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_High_3_2) = CFSTR("H264_High_3_2");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_High_4_2) = CFSTR("H264_High_4_2");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_High_5_1) = CFSTR("H264_High_5_1");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_High_5_2) = CFSTR("H264_High_5_2");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_Main_4_2) = CFSTR("H264_Main_4_2");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_Main_5_1) = CFSTR("H264_Main_5_1");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_Main_5_2) = CFSTR("H264_Main_5_2");
