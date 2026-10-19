#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

// The string constants VideoToolbox's first held export of which is iOS 8.0. Where the values
// come from, and why a value is not the constant's own name: the head of
// VideoToolboxConstants7_0.m. An object carries the API of one release.

// This file holds the constants of iOS 7.0; every other release's are in
// VideoToolboxConstants<release>.m, because an object carries the API of one release: the
// release the cache ladder measures for the symbol (place-by-ladder.py), and the registry's
// where no held cache exports it.

const CFStringRef kVTCompressionPropertyKey_GammaLevel = CFSTR("GammaLevel");
const CFStringRef kVTCompressionPropertyKey_MultiPassStorage = CFSTR("MultiPassStorage");
const CFStringRef kVTDecompressionPropertyKey_OutputPoolRequestedMinimumBufferCount = CFSTR("OutputPoolRequestedMinimumBufferCount");
const CFStringRef kVTMultiPassStorageCreationOption_DoNotDelete = CFSTR("DoNotDelete");
const CFStringRef kVTPixelTransferPropertyKey_RealTime = CFSTR("RealTime");
const CFStringRef kVTProfileLevel_H264_Baseline_4_0 = CFSTR("H264_Baseline_4_0");
const CFStringRef kVTProfileLevel_H264_Baseline_4_2 = CFSTR("H264_Baseline_4_2");
const CFStringRef kVTProfileLevel_H264_Baseline_5_0 = CFSTR("H264_Baseline_5_0");
const CFStringRef kVTProfileLevel_H264_Baseline_5_1 = CFSTR("H264_Baseline_5_1");
const CFStringRef kVTProfileLevel_H264_Baseline_5_2 = CFSTR("H264_Baseline_5_2");
const CFStringRef kVTProfileLevel_H264_High_3_2 = CFSTR("H264_High_3_2");
const CFStringRef kVTProfileLevel_H264_High_4_2 = CFSTR("H264_High_4_2");
const CFStringRef kVTProfileLevel_H264_High_5_1 = CFSTR("H264_High_5_1");
const CFStringRef kVTProfileLevel_H264_High_5_2 = CFSTR("H264_High_5_2");
const CFStringRef kVTProfileLevel_H264_Main_4_2 = CFSTR("H264_Main_4_2");
const CFStringRef kVTProfileLevel_H264_Main_5_1 = CFSTR("H264_Main_5_1");
const CFStringRef kVTProfileLevel_H264_Main_5_2 = CFSTR("H264_Main_5_2");
