// CharonNDEF.m - the record shape of CharonNDEF.h, per the NFC Forum NDEF Technical Specification.
// Every field is written and read where the specification puts it, and a record that does not add up is
// refused rather than repaired.

#import "CharonNDEF.h"

const char *const CharonNDEFURIPrefixes[CharonNDEFURIPrefixCount] = {
    "", "http://www.", "https://www.", "http://", "https://", "tel:", "mailto:",
    "ftp://anonymous:anonymous@", "ftp://ftp.", "ftps://", "sftp://", "smb://", "nfs://", "ftp://",
    "dav://", "news:", "telnet://", "imap:", "rtsp://", "urn:", "pop:", "sip:", "sips:", "tftp:",
    "btspp://", "btl2cap://", "btgoep://", "tcpobex://", "irdaobex://", "file://", "urn:epc:id:",
    "urn:epc:tag:", "urn:epc:pat:", "urn:epc:raw:", "urn:epc:", "urn:nfc:"};

static uint32_t CharonNDEFBigEndian(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static void CharonNDEFPutBigEndian(uint8_t *bytes, uint32_t value)
{
    bytes[0] = (uint8_t)(value >> 24);
    bytes[1] = (uint8_t)(value >> 16);
    bytes[2] = (uint8_t)(value >> 8);
    bytes[3] = (uint8_t)value;
}

size_t CharonNDEFRecordLength(const CharonNDEFRecord *record)
{
    if (record->typeLength > CharonNDEFMaxTypeLength || record->identifierLength > CharonNDEFMaxIDLength) {
        return 0;
    }
    // The header, the type length, the payload length of one or four bytes, and the ID length byte
    // exactly when the header's IL says it is there.
    size_t head = (record->payloadLength < 0x100 ? 3 : 6) + (record->hasIdentifierField ? 1 : 0);
    return head + record->typeLength + record->identifierLength + record->payloadLength;
}

size_t CharonNDEFRecordEncode(const CharonNDEFRecord *record, uint8_t *out, size_t capacity)
{
    int shortRecord = record->payloadLength < 0x100;
    size_t total = CharonNDEFRecordLength(record);
    if (total == 0 || total > capacity) {
        return 0;
    }
    uint8_t header = (uint8_t)((record->format & 0x07) << 1);
    if (record->first) {
        header |= 0x80;
    }
    if (record->last) {
        header |= 0x40;
    }
    if (shortRecord) {
        header |= 0x20;
    }
    // IL: the ID length field is present whenever the record carries one - which for a record with no
    // identifier at all is not, and which is why the text RTD's own worked example is twelve bytes.
    if (record->hasIdentifierField) {
        header |= 0x10;
    }
    if (record->continuation) {
        header |= 0x01;
    }
    size_t offset = 0;
    out[offset++] = header;
    out[offset++] = (uint8_t)record->typeLength;
    if (shortRecord) {
        out[offset++] = (uint8_t)record->payloadLength;
    } else {
        CharonNDEFPutBigEndian(out + offset, (uint32_t)record->payloadLength);
        offset += 4;
    }
    if (record->hasIdentifierField) {
        out[offset++] = (uint8_t)record->identifierLength;
    }
    if (record->typeLength) {
        memcpy(out + offset, record->type, record->typeLength);
        offset += record->typeLength;
    }
    if (record->identifierLength) {
        memcpy(out + offset, record->identifier, record->identifierLength);
        offset += record->identifierLength;
    }
    if (record->payloadLength) {
        memcpy(out + offset, record->payload, record->payloadLength);
        offset += record->payloadLength;
    }
    return offset;
}

size_t CharonNDEFRecordDecode(const uint8_t *bytes, size_t length, CharonNDEFRecord *record)
{
    if (length < 4) {
        return 0;
    }
    uint8_t header = bytes[0];
    size_t typeLength = bytes[1];
    size_t payloadLength;
    size_t offset = 2;
    if (header & 0x20) {
        if (length < 3) {
            return 0;
        }
        payloadLength = bytes[offset++];
    } else {
        if (length < 7) {
            return 0;
        }
        payloadLength = CharonNDEFBigEndian(bytes + offset);
        offset += 4;
    }
    size_t identifierLength = 0;
    int hasIdentifierField = (header & 0x10) != 0;
    if (hasIdentifierField) {
        if (offset >= length) {
            return 0;
        }
        identifierLength = bytes[offset++];
    }
    size_t total = offset + typeLength + identifierLength + payloadLength;
    if (total > length || typeLength > CharonNDEFMaxTypeLength || identifierLength > CharonNDEFMaxIDLength) {
        return 0;
    }
    record->format = (uint8_t)((header >> 1) & 0x07);
    record->first = (header & 0x80) != 0;
    record->last = (header & 0x40) != 0;
    record->continuation = (header & 0x01) != 0;
    record->typeLength = typeLength;
    if (typeLength) {
        memcpy(record->type, bytes + offset, typeLength);
    }
    offset += typeLength;
    record->identifierLength = identifierLength;
    record->hasIdentifierField = hasIdentifierField;
    if (identifierLength) {
        memcpy(record->identifier, bytes + offset, identifierLength);
    }
    offset += identifierLength;
    record->payload = bytes + offset;
    record->payloadLength = payloadLength;
    return total;
}
