// kMIDIPropertyNameConfigurationDictionary, of iOS 13: the property under which a device keeps the name
// configuration the naming of its entities and endpoints reads. The string is the one macOS CoreMIDI gives it
// (tests/backports/host/coremidi/oracle/constants.m reads it from the host's own framework).
#import <CoreMIDI/CoreMIDI.h>

const CFStringRef kMIDIPropertyNameConfigurationDictionary = CFSTR("nameConfigurationDictionary");
