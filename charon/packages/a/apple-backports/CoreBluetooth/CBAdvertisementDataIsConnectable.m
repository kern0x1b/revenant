#import <Foundation/Foundation.h>

// CBAdvertisementDataIsConnectable, declared by CoreBluetooth of iOS 7.0 on. iOS 6.1.3's CoreBluetooth does not export
// it: the armv7 shared cache of that release has no kCBAdvDataIsConnectable string and no symbol of that name
// (facts/CoreBluetooth/CBAdvertisementDataIsConnectable.md). An application that names it on 6.1.3 would have a strong or
// weak reference to a symbol nothing provides, so the port carries the constant itself, with the text the host's own
// CoreBluetooth gives it. The CoreBluetooth framework is not linked: the constant is a string, and the Bluetooth
// central stays dlopen'd (see the note on CoreMIDIBackports in modules/apple/backports.lua).
//
// It is declared HERE, with the plain extern, and CoreBluetooth.h is deliberately NOT imported: the SDK's
// API_AVAILABLE(ios(7.0)) would mark a definition for a deployment target of 6.1.3 as unavailable.

extern NSString *const CBAdvertisementDataIsConnectable;

NSString *const CBAdvertisementDataIsConnectable = @"kCBAdvDataIsConnectable";
