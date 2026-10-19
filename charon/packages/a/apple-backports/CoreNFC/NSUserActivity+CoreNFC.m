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
