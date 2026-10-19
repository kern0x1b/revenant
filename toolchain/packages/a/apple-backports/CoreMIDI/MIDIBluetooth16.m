#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreMIDI/CoreMIDI.h>

#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdlib.h>

#import "CharonCoreMIDI.h"

static Class charon_cb_class(const char *name)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (!dlopen("/System/Library/Frameworks/CoreBluetooth.framework/CoreBluetooth", RTLD_LAZY))
            NSLog(@"charon: CoreBluetooth would not open (%s); the Bluetooth MIDI central has no framework", dlerror());
    });
    return objc_getClass(name);
}

static CBUUID *charon_uuid(NSString *string)
{
    return [(id)charon_cb_class("CBUUID") UUIDWithString:string];
}

static NSString *const charon_service = @"03B80E5A-EDE8-4B33-A751-6CE34EC4C700";
static NSString *const charon_characteristic = @"7772E5DB-3868-4112-A1A9-F2669D106BF3";

@interface CBPeripheral (CharonUUID)
- (CFUUIDRef)UUID;
@end

static NSString *charon_peripheral_key(CBPeripheral *peripheral)
{
    if ([peripheral respondsToSelector:@selector(identifier)])
        return peripheral.identifier.UUIDString;
    return (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, [peripheral UUID]);
}

@interface CharonBLEDevice : NSObject <CBPeripheralDelegate> {
    CharonBLEParser _parser;
}
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, assign) MIDIEndpointRef source;
@property (nonatomic, assign) BOOL refusedOnce;
@end

@implementation CharonBLEDevice

@synthesize peripheral = _peripheral;
@synthesize source = _source;
@synthesize refusedOnce = _refusedOnce;

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:charon_uuid(charon_service)])
            [peripheral discoverCharacteristics:@[charon_uuid(charon_characteristic)] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:charon_uuid(charon_characteristic)])
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSData *value = characteristic.value;
    if (value.length == 0 || self.source == 0)
        return;
    uint8_t stackMidi[1024] __attribute__((aligned(4)));
    uint8_t *midi = stackMidi;
    if (2 * value.length > sizeof(stackMidi)) {
        midi = malloc(2 * value.length);
        if (!midi) {
            NSLog(@"charon: a Bluetooth MIDI notification of %lu bytes could not be given memory and is dropped", (unsigned long)value.length);
            return;
        }
    }
    size_t count = CharonBLEMIDIParse(&_parser, value.bytes, value.length, midi);
    if (count > 0) {
        size_t listSize = sizeof(MIDIPacketList) + count + 4;
        Byte stackList[1024 + sizeof(MIDIPacketList) + 4] __attribute__((aligned(4)));
        Byte *buffer = stackList;
        if (listSize > sizeof(stackList))
            buffer = malloc(listSize);
        if (!buffer) {
            NSLog(@"charon: a Bluetooth MIDI notification of %lu bytes could not be given memory and is dropped", (unsigned long)count);
        } else {
            MIDIPacketList *list = (MIDIPacketList *)buffer;
            if (MIDIPacketListAdd(list, listSize, MIDIPacketListInit(list), 0, count, midi) == NULL) {
                NSLog(@"charon: a Bluetooth MIDI notification of %lu bytes did not fit its packet list and is dropped", (unsigned long)count);
            } else {
                OSStatus status = MIDIReceived(self.source, list);
                if (status != noErr && !self.refusedOnce) {
                    self.refusedOnce = YES;
                    NSLog(@"charon: a Bluetooth MIDI device's bytes were not received by the release (status %d); facts/CoreMIDI/CoreMIDI.md", (int)status);
                }
            }
            if (buffer != stackList)
                free(buffer);
        }
    }
    if (midi != stackMidi)
        free(midi);
}

@end

@interface CharonBLECentral : NSObject <CBCentralManagerDelegate>
@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) NSMutableDictionary *devices;
@property (nonatomic, assign) BOOL activated;
@property (nonatomic, assign) MIDIClientRef client;
- (void)forgetDevice:(NSString *)key;
@end

@implementation CharonBLECentral

@synthesize manager = _manager;
@synthesize devices = _devices;
@synthesize activated = _activated;
@synthesize client = _client;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _devices = [NSMutableDictionary dictionary];
        _manager = [[(id)charon_cb_class("CBCentralManager") alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    }
    return self;
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBManagerStatePoweredOn && self.activated)
        [central scanForPeripheralsWithServices:@[charon_uuid(charon_service)] options:nil];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSString *key = charon_peripheral_key(peripheral);
    if (self.devices[key])
        return;
    CharonBLEDevice *device = [[CharonBLEDevice alloc] init];
    device.peripheral = peripheral;
    peripheral.delegate = device;
    self.devices[key] = device;
    [central connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    CharonBLEDevice *device = self.devices[charon_peripheral_key(peripheral)];
    if (!device)
        return;
    if (self.client == 0) {
        if (MIDIClientCreate(CFSTR("charon-bluetooth"), NULL, NULL, &_client) != noErr) {
            NSLog(@"charon: the release would not make a MIDI client for a Bluetooth device; its bytes are dropped");
            [peripheral discoverServices:@[charon_uuid(charon_service)]];
            return;
        }
    }
    NSString *name = peripheral.name ? peripheral.name : @"Bluetooth MIDI";
    MIDIEndpointRef source = 0;
    OSStatus status = MIDISourceCreate(self.client, (__bridge CFStringRef)name, &source);
    if (status == noErr) {
        CharonMIDIForgetRoute(source);
        device.source = source;
    } else {
        NSLog(@"charon: the release refused a virtual source for a Bluetooth MIDI device (status %d); its bytes are dropped (facts/CoreMIDI/CoreMIDI.md)", (int)status);
    }
    [peripheral discoverServices:@[charon_uuid(charon_service)]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"charon: a Bluetooth MIDI device did not connect (%@)", error);
    [self forgetDevice:charon_peripheral_key(peripheral)];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self forgetDevice:charon_peripheral_key(peripheral)];
}

- (void)forgetDevice:(NSString *)key
{
    CharonBLEDevice *device = self.devices[key];
    if (device.source != 0) {
        if (MIDIEndpointDispose(device.source) != noErr)
            NSLog(@"charon: the virtual source of a Bluetooth MIDI device could not be disposed");
        device.source = 0;
    }
    [self.devices removeObjectForKey:key];
}

@end

static CharonBLECentral *charon_central(void)
{
    static CharonBLECentral *central;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        central = [[CharonBLECentral alloc] init];
    });
    return central;
}

OSStatus charon_bluetooth_activate_all_connections(void)
{
    CharonBLECentral *central = charon_central();
    dispatch_async(dispatch_get_main_queue(), ^{
        central.activated = YES;
        if (central.manager.state == CBManagerStatePoweredOn)
            [central.manager scanForPeripheralsWithServices:@[charon_uuid(charon_service)] options:nil];
    });
    return noErr;
}

OSStatus charon_bluetooth_disconnect(CFStringRef uuid)
{
    CharonBLECentral *central = charon_central();
    NSString *key = (__bridge NSString *)uuid;
    dispatch_async(dispatch_get_main_queue(), ^{
        CharonBLEDevice *device = central.devices[key];
        if (device) {
            [central.manager cancelPeripheralConnection:device.peripheral];
            [central forgetDevice:key];
        }
    });
    return noErr;
}
