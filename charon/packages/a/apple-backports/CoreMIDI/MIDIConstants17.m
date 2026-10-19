// kMIDIPropertyUMPActiveGroupBitmap and kMIDIPropertyUMPCanTransmitGroupless, of iOS 17: the two UMP properties of an
// endpoint, the groups it has active and whether it can send without a group. The strings are the keys macOS CoreMIDI
// holds once a client exists (oracle/constants.m reads them after MIDIClientCreate, measured 2026-10-10; before that
// the framework's linked symbols read NULL). The key of kMIDIPropertyUMPCanTransmitGroupless is the string "ump endpoint"
// as the framework has it: a property set with the constant reads back through that string, and not through
// "UMPCanTransmitGroupless" (facts/CoreMIDI/Constants.md). The release has no UMP endpoint, so no endpoint of this port
// carries these properties from the release's side; the constants exist for the application that names them.
#import <CoreMIDI/CoreMIDI.h>

const CFStringRef kMIDIPropertyUMPActiveGroupBitmap = CFSTR("active group bitmap");
const CFStringRef kMIDIPropertyUMPCanTransmitGroupless = CFSTR("ump endpoint");
