#import <CoreMIDI/MIDIServices.h>
#import <Foundation/Foundation.h>

// The list form of a MIDI send, for -[AVAudioUnitMIDIInstrument sendMIDIEventList:] (iOS 16).
//
// The list is Universal MIDI Packets. The release's only sends are MusicDeviceMIDIEvent (a MIDI 1.0 status and two data
// bytes) and MusicDeviceSysEx (a whole system-exclusive message), so each UMP message is turned into one of those, in
// the order the list gives them. CharonForEachMIDIMessage calls the block once per message, with the bytes of the MIDI
// 1.0 message (one to three bytes) or of a complete system-exclusive message (F0 ... F7).
//
// The conversions, and what each is measured against (facts/AVFAudio/AVAudioUnitMIDI.md, host sampler measurements):
//   type 1, system common and realtime: the status is the message; its data bytes are the ones the status takes.
//     Not observable on the host's sampler (it ignores system messages), so the mapping is the MIDI 1.0 one.
//   type 2, MIDI 1.0 channel voice: the bytes as written.
//   type 3, SysEx7: the packets are joined (start, continue, end; complete on its own) into one F0 ... F7 message. A
//     message that is not complete within the list is not sent. Not observable on the host's sampler (it ignores sysex),
//     so the join is the UMP definition.
//   type 4, MIDI 2.0 channel voice, converted to MIDI 1.0 by the scaling the host's sampler answers bit for bit:
//     note on: velocity = max(1, velocity16 >> 9)  (measured: 0xFFFF -> 127, 0x8000 -> 64, 0x0100 -> 1, 0 -> 1);
//     control change: value = value32 >> 25        (measured on CC 7: 0xFFFFFFFF -> 127, 0x80000000 -> 64);
//     pitch bend: 14-bit value = value32 >> 18     (measured: 0xFFFFFFFF -> 16383, 0xC0000000 -> 12288, 0 -> 0).
//     Not observable on the sampler, so the scaling is the UMP one: note off velocity (velocity16 >> 9, no minimum),
//     poly pressure and channel pressure (value32 >> 25), and program change (bank MSB and LSB as control change 0 and 32
//     when the bank-valid bit is set, then the program, bits 31-24 of the second word).
//     Dropped: the registered and assignable controllers, the per-note forms and the relative forms, which have no MIDI 1.0
//     single-message form.
//   types 0, 5 to 15: not sent (no MIDI 1.0 form, or a reserved type).
//
// A message of a type this file does not convert is skipped and the walk goes on.
static inline void CharonForEachMIDIMessage(const MIDIEventList *list, void (^send)(const uint8_t *bytes, UInt32 length))
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
                case 0x1: {   // system common and realtime
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
                case 0x2: {   // MIDI 1.0 channel voice
                    bytes[0] = (uint8_t)(word >> 16);
                    bytes[1] = (uint8_t)(word >> 8);
                    bytes[2] = (uint8_t)word;
                    UInt32 length = ((bytes[0] & 0xF0) == 0xC0 || (bytes[0] & 0xF0) == 0xD0) ? 2 : 3;
                    send(bytes, length);
                    break;
                }
                case 0x3: {   // SysEx7: up to six data bytes per packet
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
                    w++;   // the second word of the packet carries the data bytes 3 to 6
                    break;
                }
                case 0x4: {   // MIDI 2.0 channel voice, converted to MIDI 1.0
                    uint8_t opcode = (uint8_t)((word >> 20) & 0xF);
                    uint8_t channel = (uint8_t)((word >> 16) & 0xF);
                    uint8_t index = (uint8_t)(word >> 8);
                    UInt32 value = nextWord;
                    w++;   // every channel voice message of type 4 is two words
                    switch (opcode) {
                        case 0x8:   // note off: velocity16 >> 9, no minimum
                            bytes[0] = 0x80 | channel; bytes[1] = index; bytes[2] = (uint8_t)(value >> 25);
                            send(bytes, 3);
                            break;
                        case 0x9: { // note on: a velocity16 of 0 still sounds, at the minimum velocity 1
                            uint8_t velocity = (uint8_t)(value >> 25);
                            if (velocity == 0) {
                                velocity = 1;
                            }
                            bytes[0] = 0x90 | channel; bytes[1] = index; bytes[2] = velocity;
                            send(bytes, 3);
                            break;
                        }
                        case 0xA:   // poly pressure
                            bytes[0] = 0xA0 | channel; bytes[1] = index; bytes[2] = (uint8_t)(value >> 25);
                            send(bytes, 3);
                            break;
                        case 0xB:   // control change
                            bytes[0] = 0xB0 | channel; bytes[1] = index; bytes[2] = (uint8_t)(value >> 25);
                            send(bytes, 3);
                            break;
                        case 0xC: { // program change, with the bank as controls 0 and 32 when the bank is valid
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
                        case 0xD:   // channel pressure
                            bytes[0] = 0xD0 | channel; bytes[1] = (uint8_t)(value >> 25);
                            send(bytes, 2);
                            break;
                        case 0xE: { // pitch bend, 14 bits
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
