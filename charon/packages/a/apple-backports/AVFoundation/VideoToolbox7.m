#import <VideoToolbox/VideoToolbox.h>

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

// The release's encoder sets itself up on the first frame, which is what this lets it do. The host
// answers kVTParameterErr for NULL and noErr for anything else, an invalidated session included.
OSStatus VTCompressionSessionPrepareToEncodeFrames(VTCompressionSessionRef session)
{
    return session ? noErr : kVTParameterErr;
}
