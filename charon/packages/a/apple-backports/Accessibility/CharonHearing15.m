//
//  CharonHearing15.m
//  Accessibility
//
//  The three hearing-device functions of 15.0, one object because one object carries the API of one
//  release. The declarations are the SDK's own - AXHearingUtilities.h is in the SDK this package compiles
//  against - so there is no Charon header for this group and nothing is transcribed here.
//
//  The device has no hearing-device hardware, which is the answer all three give. What holds that is a
//  reading of the census's own list, and the list is printed, so the reading can be checked:
//
//  * 28 of the release's Accessibility exports have "Hearing" in the name, and every one of them is a
//    preference about a hearing-aid FEATURE - compliance, ear independence, the live-listen alert, the
//    stream selection, and the two demo flags - in the VoiceOver preference surface, together with
//    four about a paired-UUIDs preference with a setter;
//  * none of the 28 is an `AXMFiHearingDevice` symbol, and that is the whole claim: the three functions
//    here are about hearing devices made as phone accessories, and the release carries no API for one
//    at all, no pairing, no streaming and no bidirectional streaming.
//
//  The first version of this comment said the surface held no pairing symbol at all. It does: the census
//  lists four of them, and the subject list that would have printed them had no word for hearing or
//  pairing in it, so the sentence was never checked by anything. Both are fixed, and what justifies the
//  three answers is the narrower claim above rather than the broader one that was false. So:
//

#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

// The pairing list. Empty is the true answer with nothing paired and not a nil standing in for it: a
// caller that iterates this gets zero devices, which is what it would get from a device with no hearing
// hardware, and a nil would make a caller treat the answer as a failure to ask.
NSArray<NSUUID *> *AXMFiHearingDevicePairedUUIDs(void)
{
    return @[];
}

// Which ear a hearing device streams to. With no device the answer is the enumeration's own no-device
// case, whose value is 0 - the header's first case, and the one a caller checks for before drawing a
// left/right indicator.
AXHearingDeviceEar AXMFiHearingDeviceStreamingEar(void)
{
    return AXHearingDeviceEarNone;
}

// Whether the device can stream in both directions at once. No, and the reason is the same one every
// other answer in this file has: there is no hearing device, so there is nothing that could stream in
// either direction.
BOOL AXSupportsBidirectionalAXMFiHearingDeviceStreaming(void)
{
    return NO;
}
