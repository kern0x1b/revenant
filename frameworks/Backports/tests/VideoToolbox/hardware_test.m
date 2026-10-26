#import "../Foundation/check.h"
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>
#import <dlfcn.h>

extern Boolean RevenantVTIsHardwareDecodeSupported(CMVideoCodecType codecType);

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_check((dlsym(RTLD_DEFAULT, "RevenantVTIsHardwareDecodeSupported") != NULL) != revenant_negative, "VTIsHardwareDecodeSupported implementation is present", @"RevenantVTIsHardwareDecodeSupported");
    if (dlsym(RTLD_DEFAULT, "RevenantVTIsHardwareDecodeSupported") == NULL)
        return revenant_finish();

    const Boolean hostH264 = VTIsHardwareDecodeSupported(kCMVideoCodecType_H264);
    const Boolean backportH264 = RevenantVTIsHardwareDecodeSupported(kCMVideoCodecType_H264);
    revenant_check(hostH264 == backportH264 && backportH264, "H.264 hardware decoding is reported as the host reports it", [NSString stringWithFormat:@"host %d backport %d", hostH264, backportH264]);

    const Boolean hostHEVC = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC);
    revenant_check(!RevenantVTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC), "HEVC is not reported as hardware decoded on the A5", [NSString stringWithFormat:@"host reports %d", hostHEVC]);

    const Boolean hostAV1 = VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1);
    revenant_check(!RevenantVTIsHardwareDecodeSupported(kCMVideoCodecType_AV1), "AV1 is not reported as hardware decoded on the A5", [NSString stringWithFormat:@"host reports %d", hostAV1]);

    return revenant_finish();
}
