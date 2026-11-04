#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

const CFStringRef BACKPORT_IMPL(kMIDIPropertyAssociatedEndpoint) = CFSTR("associated endpoint");

NSString *const BACKPORT_IMPL(MIDICIDeviceObjectKey) = @"MIDICIDeviceObjectKey";
NSString *const BACKPORT_IMPL(MIDICIProfileObjectKey) = @"MIDICIProfileObjectKey";
NSString *const BACKPORT_IMPL(MIDIUMPEndpointObjectKey) = @"MIDIUMPEndpointObjectKey";
NSString *const BACKPORT_IMPL(MIDIUMPFunctionBlockObjectKey) = @"MIDIUMPFunctionBlockObjectKey";

NSString *const BACKPORT_IMPL(MIDICIDeviceWasAddedNotification) = @"MIDICIDeviceWasAddedNotification";
NSString *const BACKPORT_IMPL(MIDICIDeviceWasRemovedNotification) = @"MIDICIDeviceWasRemovedNotification";
NSString *const BACKPORT_IMPL(MIDICIProfileWasRemovedNotification) = @"MIDICIProfileWasRemovedNotification";
NSString *const BACKPORT_IMPL(MIDICIProfileWasUpdatedNotification) = @"MIDICIProfileWasUpdatedNotification";
NSString *const BACKPORT_IMPL(MIDIUMPEndpointWasAddedNotification) = @"MIDIUMPEndpointWasAddedNotification";
NSString *const BACKPORT_IMPL(MIDIUMPEndpointWasRemovedNotification) = @"MIDIUMPEndpointWasRemovedNotification";
NSString *const BACKPORT_IMPL(MIDIUMPEndpointWasUpdatedNotification) = @"MIDIUMPEndpointWasUpdatedNotification";
NSString *const BACKPORT_IMPL(MIDIUMPFunctionBlockWasUpdatedNotification) = @"MIDIUMPFunctionBlockWasUpdatedNotification";
