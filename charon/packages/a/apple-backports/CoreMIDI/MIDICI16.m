// MIDICIDeviceInfo, the device information a MIDI-CI device reports, of iOS 16: the release-split check dates the class to
// iOS 16.0 (the object may hold one release's API only, so it is not in MIDICI12.m beside the iOS 12 classes). The device info
// is made with a real destination and manufacturer 3, family 2, model 2 and revision 4 bytes, and is nil otherwise
// (oracle/micicapability.m, micicapability-macos.txt, 2026-10-09).
#import "CharonMIDICI.h"

@implementation MIDICIDeviceInfo {
    NSData *_manufacturerID;
    NSData *_family;
    NSData *_modelNumber;
    NSData *_revisionLevel;
    MIDIEntityRef _midiDestination;
}

- (instancetype)initWithDestination:(MIDIEntityRef)midiDestination manufacturer:(NSData *)manufacturer family:(NSData *)family
                              model:(NSData *)modelNumber revision:(NSData *)revisionLevel
{
    if (midiDestination == 0 || manufacturer.length != 3 || family.length != 2 || modelNumber.length != 2 || revisionLevel.length != 4)
        return nil;
    self = [super init];
    if (self) {
        _midiDestination = midiDestination;
        _manufacturerID = [manufacturer copy];
        _family = [family copy];
        _modelNumber = [modelNumber copy];
        _revisionLevel = [revisionLevel copy];
    }
    return self;
}

- (NSData *)manufacturerID { return _manufacturerID; }
- (NSData *)family { return _family; }
- (NSData *)modelNumber { return _modelNumber; }
- (NSData *)revisionLevel { return _revisionLevel; }
- (MIDIEntityRef)midiDestination { return _midiDestination; }

@end
