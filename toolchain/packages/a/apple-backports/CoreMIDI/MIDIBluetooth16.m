#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreMIDI/CoreMIDI.h>

#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdlib.h>

#import "RevenantCoreMIDI.h"

static Class revenant_cb_class(const char *name)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (!dlopen("/System/Library/Frameworks/CoreBluetooth.framework/CoreBluetooth", RTLD_LAZY))
            NSLog(@"revenant: CoreBluetooth would not open (%s); the Bluetooth MIDI central has no framework", dlerror());
    });
    return objc_getClass(name);
}

static CBUUID *revenant_uuid(NSString *string)
{
    return [(id)revenant_cb_class("CBUUID") UUIDWithString:string];
}

static NSString *const revenant_service = @"03B80E5A-EDE8-4B33-A751-6CE34EC4C700";
static NSString *const revenant_characteristic = @"7772E5DB-3868-4112-A1A9-F2669D106BF3";

@interface CBPeripheral (RevenantUUID)
- (CFUUIDRef)UUID;
@end

static NSString *revenant_peripheral_key(CBPeripheral *peripheral)
{
    if ([peripheral respondsToSelector:@selector(identifier)])
        return peripheral.identifier.UUIDString;
    return (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, [peripheral UUID]);
}

@interface RevenantBLEDevice : NSObject <CBPeripheralDelegate> {
    RevenantBLEParser _parser;
}
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, assign) MIDIEndpointRef source;
@property (nonatomic, assign) BOOL refusedOnce;
@end

@implementation RevenantBLEDevice

@synthesize peripheral = _peripheral;
@synthesize source = _source;
@synthesize refusedOnce = _refusedOnce;

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:revenant_uuid(revenant_service)])
            [peripheral discoverCharacteristics:@[revenant_uuid(revenant_characteristic)] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:revenant_uuid(revenant_characteristic)])
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
            NSLog(@"revenant: a Bluetooth MIDI notification of %lu bytes could not be given memory and is dropped", (unsigned long)value.length);
            return;
        }
    }
    size_t count = RevenantBLEMIDIParse(&_parser, value.bytes, value.length, midi);
    if (count > 0) {
        size_t listSize = sizeof(MIDIPacketList) + count + 4;
        Byte stackList[1024 + sizeof(MIDIPacketList) + 4] __attribute__((aligned(4)));
        Byte *buffer = stackList;
        if (listSize > sizeof(stackList))
            buffer = malloc(listSize);
        if (!buffer) {
            NSLog(@"revenant: a Bluetooth MIDI notification of %lu bytes could not be given memory and is dropped", (unsigned long)count);
        } else {
            MIDIPacketList *list = (MIDIPacketList *)buffer;
            if (MIDIPacketListAdd(list, listSize, MIDIPacketListInit(list), 0, count, midi) == NULL) {
                NSLog(@"revenant: a Bluetooth MIDI notification of %lu bytes did not fit its packet list and is dropped", (unsigned long)count);
            } else {
                OSStatus status = MIDIReceived(self.source, list);
                if (status != noErr && !self.refusedOnce) {
                    self.refusedOnce = YES;
                    NSLog(@"revenant: a Bluetooth MIDI device's bytes were not received by the release (status %d); facts/CoreMIDI/CoreMIDI.md", (int)status);
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

@interface RevenantBLECentral : NSObject <CBCentralManagerDelegate>
@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) NSMutableDictionary *devices;
@property (nonatomic, assign) BOOL activated;
@property (nonatomic, assign) MIDIClientRef client;
- (void)forgetDevice:(NSString *)key;
@end

@implementation RevenantBLECentral

@synthesize manager = _manager;
@synthesize devices = _devices;
@synthesize activated = _activated;
@synthesize client = _client;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _devices = [NSMutableDictionary dictionary];
        _manager = [[(id)revenant_cb_class("CBCentralManager") alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    }
    return self;
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBManagerStatePoweredOn && self.activated)
        [central scanForPeripheralsWithServices:@[revenant_uuid(revenant_service)] options:nil];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSString *key = revenant_peripheral_key(peripheral);
    if (self.devices[key])
        return;
    RevenantBLEDevice *device = [[RevenantBLEDevice alloc] init];
    device.peripheral = peripheral;
    peripheral.delegate = device;
    self.devices[key] = device;
    [central connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    RevenantBLEDevice *device = self.devices[revenant_peripheral_key(peripheral)];
    if (!device)
        return;
    if (self.client == 0) {
        if (MIDIClientCreate(CFSTR("revenant-bluetooth"), NULL, NULL, &_client) != noErr) {
            NSLog(@"revenant: the release would not make a MIDI client for a Bluetooth device; its bytes are dropped");
            [peripheral discoverServices:@[revenant_uuid(revenant_service)]];
            return;
        }
    }
    NSString *name = peripheral.name ? peripheral.name : @"Bluetooth MIDI";
    MIDIEndpointRef source = 0;
    OSStatus status = MIDISourceCreate(self.client, (__bridge CFStringRef)name, &source);
    if (status == noErr) {
        RevenantMIDIForgetRoute(source);
        device.source = source;
    } else {
        NSLog(@"revenant: the release refused a virtual source for a Bluetooth MIDI device (status %d); its bytes are dropped (facts/CoreMIDI/CoreMIDI.md)", (int)status);
    }
    [peripheral discoverServices:@[revenant_uuid(revenant_service)]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"revenant: a Bluetooth MIDI device did not connect (%@)", error);
    [self forgetDevice:revenant_peripheral_key(peripheral)];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self forgetDevice:revenant_peripheral_key(peripheral)];
}

- (void)forgetDevice:(NSString *)key
{
    RevenantBLEDevice *device = self.devices[key];
    if (device.source != 0) {
        if (MIDIEndpointDispose(device.source) != noErr)
            NSLog(@"revenant: the virtual source of a Bluetooth MIDI device could not be disposed");
        device.source = 0;
    }
    [self.devices removeObjectForKey:key];
}

@end

static RevenantBLECentral *revenant_central(void)
{
    static RevenantBLECentral *central;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        central = [[RevenantBLECentral alloc] init];
    });
    return central;
}

OSStatus revenant_bluetooth_activate_all_connections(void)
{
    RevenantBLECentral *central = revenant_central();
    dispatch_async(dispatch_get_main_queue(), ^{
        central.activated = YES;
        if (central.manager.state == CBManagerStatePoweredOn)
            [central.manager scanForPeripheralsWithServices:@[revenant_uuid(revenant_service)] options:nil];
    });
    return noErr;
}

OSStatus revenant_bluetooth_disconnect(CFStringRef uuid)
{
    RevenantBLECentral *central = revenant_central();
    NSString *key = (__bridge NSString *)uuid;
    dispatch_async(dispatch_get_main_queue(), ^{
        RevenantBLEDevice *device = central.devices[key];
        if (device) {
            [central.manager cancelPeripheralConnection:device.peripheral];
            [central forgetDevice:key];
        }
    });
    return noErr;
}
