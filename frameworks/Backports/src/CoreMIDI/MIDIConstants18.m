#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

const CFStringRef BACKPORT_IMPL(kMIDIPropertyAssociatedEndpoint) = CFSTR("associated endpoint");

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
