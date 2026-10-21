#import <VideoToolbox/VideoToolbox.h>

OSStatus VTCompressionSessionPrepareToEncodeFrames(VTCompressionSessionRef session)
{
    return session ? noErr : kVTParameterErr;
}
