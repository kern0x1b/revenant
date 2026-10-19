// The MIDI-CI and MIDI-UMP keys and notifications of iOS 18, and kMIDIPropertyAssociatedEndpoint. The notification
// and key strings are the names themselves, as macOS CoreMIDI gives them (oracle/constants.m); kMIDIPropertyAssociatedEndpoint
// is the key "associated endpoint" that macOS holds once a client exists (the same probe, after MIDIClientCreate).
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

const CFStringRef kMIDIPropertyAssociatedEndpoint = CFSTR("associated endpoint");

NSString *const MIDICIDeviceObjectKey = @"MIDICIDeviceObjectKey";
NSString *const MIDICIProfileObjectKey = @"MIDICIProfileObjectKey";
NSString *const MIDIUMPEndpointObjectKey = @"MIDIUMPEndpointObjectKey";
NSString *const MIDIUMPFunctionBlockObjectKey = @"MIDIUMPFunctionBlockObjectKey";

NSString *const MIDICIDeviceWasAddedNotification = @"MIDICIDeviceWasAddedNotification";
NSString *const MIDICIDeviceWasRemovedNotification = @"MIDICIDeviceWasRemovedNotification";
NSString *const MIDICIProfileWasRemovedNotification = @"MIDICIProfileWasRemovedNotification";
NSString *const MIDICIProfileWasUpdatedNotification = @"MIDICIProfileWasUpdatedNotification";
NSString *const MIDIUMPEndpointWasAddedNotification = @"MIDIUMPEndpointWasAddedNotification";
NSString *const MIDIUMPEndpointWasRemovedNotification = @"MIDIUMPEndpointWasRemovedNotification";
NSString *const MIDIUMPEndpointWasUpdatedNotification = @"MIDIUMPEndpointWasUpdatedNotification";
NSString *const MIDIUMPFunctionBlockWasUpdatedNotification = @"MIDIUMPFunctionBlockWasUpdatedNotification";
