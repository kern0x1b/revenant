#import <CoreMIDI/MIDIServices.h>
#import <Foundation/Foundation.h>

static inline void RevenantForEachMIDIMessage(const MIDIEventList *list, void (^send)(const uint8_t *bytes, UInt32 length))
{
    if (list == NULL || send == nil) {
        return;
    }
    NSMutableData *sysex = nil;
    const MIDIEventPacket *packet = &list->packet[0];
    for (UInt32 p = 0; p < list->numPackets; p++) {
        for (UInt32 w = 0; w < packet->wordCount; w++) {
            UInt32 word = packet->words[w];
            UInt32 nextWord = (w + 1 < packet->wordCount) ? packet->words[w + 1] : 0;
            UInt32 type = word >> 28;
            uint8_t bytes[3];
            switch (type) {
                case 0x1: {
                    uint8_t status = (uint8_t)(word >> 16);
                    if (status < 0xF1 || status == 0xF7) {
                        break;
                    }
                    bytes[0] = status;
                    bytes[1] = (uint8_t)(word >> 8);
                    bytes[2] = (uint8_t)word;
                    UInt32 length = (status == 0xF2) ? 3 : (status == 0xF1 || status == 0xF3) ? 2 : 1;
                    send(bytes, length);
                    break;
                }
                case 0x2: {
                    bytes[0] = (uint8_t)(word >> 16);
                    bytes[1] = (uint8_t)(word >> 8);
                    bytes[2] = (uint8_t)word;
                    UInt32 length = ((bytes[0] & 0xF0) == 0xC0 || (bytes[0] & 0xF0) == 0xD0) ? 2 : 3;
                    send(bytes, length);
                    break;
                }
                case 0x3: {
                    UInt32 status = (word >> 20) & 0xF;
                    UInt32 count = (word >> 16) & 0xF;
                    if (count > 6) {
                        break;
                    }
                    if (status == 0x0 || status == 0x1) {
                        sysex = [NSMutableData dataWithBytes:(const uint8_t[]){ 0xF0 } length:1];
                    }
                    if (sysex == nil) {
                        break;
                    }
                    uint8_t data[6] = { (uint8_t)(word >> 8), (uint8_t)word, (uint8_t)(nextWord >> 24),
                                        (uint8_t)(nextWord >> 16), (uint8_t)(nextWord >> 8), (uint8_t)nextWord };
                    [sysex appendBytes:data length:count];
                    if (status == 0x0 || status == 0x3) {
                        uint8_t end = 0xF7;
                        [sysex appendBytes:&end length:1];
                        send(sysex.bytes, (UInt32)sysex.length);
                        sysex = nil;
                    }
                    w++;
                    break;
                }
                case 0x4: {
                    uint8_t opcode = (uint8_t)((word >> 20) & 0xF);
                    uint8_t channel = (uint8_t)((word >> 16) & 0xF);
                    uint8_t index = (uint8_t)(word >> 8);
                    UInt32 value = nextWord;
                    w++;
                    switch (opcode) {
                        case 0x8:
                            bytes[0] = 0x80 | channel; bytes[1] = index; bytes[2] = (uint8_t)(value >> 25);
                            send(bytes, 3);
                            break;
                        case 0x9: {
                            uint8_t velocity = (uint8_t)(value >> 25);
                            if (velocity == 0) {
                                velocity = 1;
                            }
                            bytes[0] = 0x90 | channel; bytes[1] = index; bytes[2] = velocity;
                            send(bytes, 3);
                            break;
                        }
                        case 0xA:
                            bytes[0] = 0xA0 | channel; bytes[1] = index; bytes[2] = (uint8_t)(value >> 25);
                            send(bytes, 3);
                            break;
                        case 0xB:
                            bytes[0] = 0xB0 | channel; bytes[1] = index; bytes[2] = (uint8_t)(value >> 25);
                            send(bytes, 3);
                            break;
                        case 0xC: {
                            if (word & 1) {
                                bytes[0] = 0xB0 | channel; bytes[1] = 0; bytes[2] = (uint8_t)((value >> 8) & 0x7F);
                                send(bytes, 3);
                                bytes[1] = 32; bytes[2] = (uint8_t)(value & 0x7F);
                                send(bytes, 3);
                            }
                            bytes[0] = 0xC0 | channel; bytes[1] = (uint8_t)(value >> 24);
                            send(bytes, 2);
                            break;
                        }
                        case 0xD:
                            bytes[0] = 0xD0 | channel; bytes[1] = (uint8_t)(value >> 25);
                            send(bytes, 2);
                            break;
                        case 0xE: {
                            UInt32 bend = value >> 18;
                            bytes[0] = 0xE0 | channel; bytes[1] = (uint8_t)(bend & 0x7F); bytes[2] = (uint8_t)(bend >> 7);
                            send(bytes, 3);
                            break;
                        }
                        default:
                            break;
                    }
                    break;
                }
                default:
                    break;
            }
        }
        packet = MIDIEventPacketNext(packet);
    }
}
