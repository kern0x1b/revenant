#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

// AudioToolbox functions of iOS 7, which the release this port runs on does not export. Each is written from the
// host's answer for the same input (tests/backports/host/audiotoolbox-functions measures every case below against the
// host's own symbol, and facts/AVFAudio/AudioToolboxFunctions.md has the figures).

// AudioComponentGetLastActiveTime. The host answers 0 for a component it has not been asked to use and still answers 0
// after the component is instantiated and initialized, which is every case measured. This port keeps no record of
// use, so the answer is the one the host gives, for every component.
CFAbsoluteTime AudioComponentGetLastActiveTime(AudioComponent comp)
{
    return 0;
}

// AudioOutputUnitGetHostIcon. The icon is the host application's, the application that hosts the unit out of process.
// The host answers nil for a unit it has in this process (the generic output, instantiated), and this port hosts every
// unit in its own process, so there is no host application icon to return: nil, for every unit. The function's return type
// is UIImage, which only iOS has, so this definition is compiled for iOS only; the host test prints the host's answer for the
// record and does not compile this definition (facts/AVFAudio/AudioToolboxFunctions.md).
#if TARGET_OS_IPHONE
UIImage *AudioOutputUnitGetHostIcon(AudioUnit au, float desiredPointSize)
{
    return nil;
}
#endif
