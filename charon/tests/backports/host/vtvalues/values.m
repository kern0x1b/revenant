#import <VideoToolbox/VideoToolbox.h>
#include <stdio.h>
int main(void) {
    { char b[128]; CFStringGetCString(kVTDecompressionPropertyKey_RealTime, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTDecompressionPropertyKey_RealTime", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Baseline_4_0, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Baseline_4_0", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Baseline_4_2, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Baseline_4_2", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Baseline_5_0, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Baseline_5_0", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Baseline_5_1, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Baseline_5_1", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Baseline_5_2, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Baseline_5_2", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_High_3_2, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_High_3_2", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_High_4_2, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_High_4_2", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_High_5_1, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_High_5_1", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_High_5_2, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_High_5_2", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Main_4_2, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Main_4_2", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Main_5_1, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Main_5_1", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Main_5_2, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Main_5_2", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_Baseline_3_0, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_Baseline_3_0", b); }
    { char b[128]; CFStringGetCString(kVTProfileLevel_H264_High_AutoLevel, b, 128, kCFStringEncodingUTF8); printf("%s=%s\n", "kVTProfileLevel_H264_High_AutoLevel", b); }
}
