#import <Intents/Intents.h>

// 9 constants, the 14.0 names first exported in that release, and nothing else: a name
// this file does not define is a name the corpus's gate asks for and the link cannot find, so the
// list below is the whole of this file's claim and the registry names each one of them.
//
// Every value was read out of the host's own Intents at runtime - dlsym over
// /System/Library/Frameworks/Intents.framework, the NSString *const dereferenced once - and the
// differential in tests/backports/host/intents/constants reads the same table out of two builds:
// Apple's framework on its own, and this file beside it in one binary with the names renamed.
//
// The object is split by the release each name first appears in, not by a version string:
// backports.lua's band() raises on an object mixing a name a band already exports with one it
// does not, and a single-band 6.1.3 gate cannot see it.  AVFoundation's metadata key-space
// objects are split the same way.
//
// The ledger's reason for every one of these, which is what this slice answers:
// "declared extern in the lifted headers and there is no such symbol in the built libraries or
// the 6.1.3 cache -- the port has to export it".


NSString *const INCarChargingConnectorTypeCCS1 = @"com.apple.intents.CarChargingConnectorType.CCS1";
NSString *const INCarChargingConnectorTypeCCS2 = @"com.apple.intents.CarChargingConnectorType.CCS2";
NSString *const INCarChargingConnectorTypeCHAdeMO = @"com.apple.intents.CarChargingConnectorType.CHAdeMO";
NSString *const INCarChargingConnectorTypeGBTAC = @"com.apple.intents.CarChargingConnectorType.GBTAC";
NSString *const INCarChargingConnectorTypeGBTDC = @"com.apple.intents.CarChargingConnectorType.GBTDC";
NSString *const INCarChargingConnectorTypeJ1772 = @"com.apple.intents.CarChargingConnectorType.J1772";
NSString *const INCarChargingConnectorTypeMennekes = @"com.apple.intents.CarChargingConnectorType.Mennekes";
NSString *const INCarChargingConnectorTypeTesla = @"com.apple.intents.CarChargingConnectorType.Tesla";
NSString *const INPersonHandleLabelSchool = @"com.apple.intents.PersonHandleLabel.School";
