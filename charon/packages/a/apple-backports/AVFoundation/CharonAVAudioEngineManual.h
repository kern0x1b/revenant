#import <AVFAudio/AVAudioTypes.h>
#import <AudioToolbox/AudioToolbox.h>

// The three manual-rendering types of AVAudioEngine.h, transcribed rather than imported, and why.
//
// This file already includes CharonAVAudioBuffer.h, which imports <AVFAudio/AVAudioFormat.h> and
// <AVFAudio/AVAudioTypes.h>. The umbrella that carries <AVFAudio/AVAudioEngine.h> imports those two
// again, and the SDK's AVFAudio headers cannot be entered twice - the result is
//
//   AVAudioNode.h:52: error: duplicate interface definition for class 'AVAudioNode'
//   AVAudioIONode.h:58: error: duplicate interface definition for class 'AVAudioIONode'
//
// with a property-has-a-previous-declaration for each of the node's. So the three declarations manual
// rendering needs are here instead, spelled and valued exactly as AVAudioEngine.h declares them:
// the status enum at :76-81, the mode enum at :83-86, and the block typedef at :138, whose shape is
// (frame count, out buffer, out error) returning the status - not the four-argument AURenderBlock shape,
// which is a different typedef for a different class.
//
// The members themselves - enableManualRenderingMode:format:maximumFrameCount:error:,
// disableManualRenderingMode, renderOffline:toBuffer:error:, manualRenderingBlock, manualRenderingMode,
// manualRenderingFormat, manualRenderingMaximumFrameCount and manualRenderingSampleTime - are declared
// by the SDK and implemented in AVAudioEngine.m; the types here are what that implementation needs in
// order to be written at all.

typedef NS_ENUM(NSInteger, AVAudioEngineManualRenderingStatus) {
    AVAudioEngineManualRenderingStatusError = -1,
    AVAudioEngineManualRenderingStatusSuccess = 0,
    AVAudioEngineManualRenderingStatusInsufficientDataFromInputNode = 1,
    AVAudioEngineManualRenderingStatusCannotDoInCurrentContext = 2,
};

typedef NS_ENUM(NSInteger, AVAudioEngineManualRenderingMode) {
    AVAudioEngineManualRenderingModeOffline = 0,
    AVAudioEngineManualRenderingModeRealtime = 1,
};

typedef AVAudioEngineManualRenderingStatus (^AVAudioEngineManualRenderingBlock)(AVAudioFrameCount numberOfFrames,
                                                                                AudioBufferList *outBuffer,
                                                                                OSStatus * _Nullable outError);
