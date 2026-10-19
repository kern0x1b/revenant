//
//  NSUserActivity+CoreNFC.m
//  CoreNFC
//
//  The category CoreNFC adds to NSUserActivity (NSUserActivity+CoreNFC.h, iOS 12). Its value is the NDEF message of the tag
//  that launched the activity. An activity no tag launched has the empty message: one record, of the empty type-name format,
//  with an empty type, identifier and payload. That is the host's answer for every activity measured, whatever its type and
//  its user info (tests/backports/host/nfc-activity). Each read makes a message of its own, as the host's reads do.
//

#import <CoreNFC/CoreNFC.h>

@implementation NSUserActivity (CoreNFC)

- (NFCNDEFMessage *)ndefMessagePayload
{
    NFCNDEFPayload *record = [[NFCNDEFPayload alloc] initWithFormat:NFCTypeNameFormatEmpty
                                                               type:[NSData data]
                                                         identifier:[NSData data]
                                                            payload:[NSData data]];
    return [[NFCNDEFMessage alloc] initWithNDEFRecords:@[record]];
}

@end
