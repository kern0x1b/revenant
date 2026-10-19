#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

static bool charon_key_valid(const char *key)
{
    if (!key)
        return false;
    size_t length = strlen(key);
    if (length == 0 || length > 255)
        return false;
    for (size_t index = 0; index < length; index++) {
        unsigned char character = (unsigned char)key[index];
        if (character < 0x21 || character > 0x7E)
            return false;
    }
    return true;
}

static CharonNWTxtRecord *charon_txt_record(BOOL dictionary)
{
    CharonNWTxtRecord *record = [[CharonNWTxtRecord alloc] init];
    record->_keys = [NSMutableArray array];
    record->_values = [NSMutableArray array];
    record->_dictionary = dictionary;
    return record;
}

static BOOL charon_has_no_value(id value)
{
    return !value || [value isKindOfClass:[NSNull class]];
}

static nw_txt_record_find_key_t charon_find(CharonNWTxtRecord *record, const char *key)
{
    if (!charon_key_valid(key))
        return nw_txt_record_find_key_invalid;
    NSUInteger index = [record->_keys indexOfObject:@(key)];
    if (index == NSNotFound)
        return nw_txt_record_find_key_not_present;
    id value = record->_values[index];
    if (charon_has_no_value(value))
        return nw_txt_record_find_key_no_value;
    return ((NSData *)value).length ? nw_txt_record_find_key_non_empty_value : nw_txt_record_find_key_empty_value;
}

nw_txt_record_t nw_txt_record_create_dictionary(void)
{
    return charon_txt_record(YES);
}

nw_txt_record_t nw_txt_record_create_with_bytes(const uint8_t *txt_bytes, size_t txt_len)
{
    if (!txt_len)
        return NULL;
    if (!txt_bytes)
        return NULL;
    CharonNWTxtRecord *record = charon_txt_record(YES);
    size_t offset = 0;
    while (offset < txt_len) {
        size_t length = txt_bytes[offset++];
        if (offset + length > txt_len)
            break;
        const char *string = (const char *)(txt_bytes + offset);
        offset += length;
        const char *equals = memchr(string, '=', length);
        if (!equals) {
            char *key = malloc(length + 1);
            if (!key)
                break;
            memcpy(key, string, length);
            key[length] = 0;
            if (charon_key_valid(key)) {
                [record->_keys addObject:@(key)];
                [record->_values addObject:[NSNull null]];
            }
            free(key);
            continue;
        }
        size_t key_length = (size_t)(equals - string);
        char *key = malloc(key_length + 1);
        if (!key)
            break;
        memcpy(key, string, key_length);
        key[key_length] = 0;
        if (charon_key_valid(key)) {
            [record->_keys addObject:@(key)];
            [record->_values addObject:[NSData dataWithBytes:equals + 1 length:length - key_length - 1]];
        }
        free(key);
    }
    return record;
}

nw_txt_record_t nw_txt_record_copy(nw_txt_record_t txt_record)
{
    CharonNWTxtRecord *source = (CharonNWTxtRecord *)txt_record;
    if (!source)
        return NULL;
    CharonNWTxtRecord *copy = charon_txt_record(source->_dictionary);
    copy->_keys = [source->_keys mutableCopy];
    copy->_values = [source->_values mutableCopy];
    return copy;
}

size_t nw_txt_record_get_key_count(nw_txt_record_t txt_record)
{
    CharonNWTxtRecord *value = (CharonNWTxtRecord *)txt_record;
    return value ? value->_keys.count : 0;
}

bool nw_txt_record_is_dictionary(nw_txt_record_t txt_record)
{
    CharonNWTxtRecord *value = (CharonNWTxtRecord *)txt_record;
    return value ? value->_dictionary : false;
}

bool nw_txt_record_is_equal(nw_txt_record_t left, nw_txt_record_t right)
{
    if (left == right)
        return true;
    if (!left || !right)
        return false;
    CharonNWTxtRecord *a = (CharonNWTxtRecord *)left, *b = (CharonNWTxtRecord *)right;
    if (a->_keys.count != b->_keys.count)
        return false;
    for (NSUInteger index = 0; index < a->_keys.count; index++) {
        if (![a->_keys[index] isEqualToString:b->_keys[index]])
            return false;
        NSData *first = a->_values[index], *second = b->_values[index];
        if (charon_has_no_value(first) != charon_has_no_value(second))
            return false;
        if (charon_has_no_value(first))
            continue;
        if (first && second && ![first isEqualToData:second])
            return false;
    }
    return true;
}

nw_txt_record_find_key_t nw_txt_record_find_key(nw_txt_record_t txt_record, const char *key)
{
    CharonNWTxtRecord *value = (CharonNWTxtRecord *)txt_record;
    if (!value)
        return nw_txt_record_find_key_not_present;
    return charon_find(value, key);
}

bool nw_txt_record_set_key(nw_txt_record_t txt_record, const char *key, const uint8_t *value, size_t value_len)
{
    CharonNWTxtRecord *record = (CharonNWTxtRecord *)txt_record;
    if (!record || !charon_key_valid(key))
        return false;
    NSData *bytes = value ? [NSData dataWithBytes:value length:value_len] : nil;
    NSUInteger index = [record->_keys indexOfObject:@(key)];
    if (index == NSNotFound) {
        [record->_keys addObject:@(key)];
        [record->_values addObject:bytes ?: (id)[NSNull null]];
    } else {
        record->_values[index] = bytes ?: (id)[NSNull null];
    }
    return true;
}

bool nw_txt_record_remove_key(nw_txt_record_t txt_record, const char *key)
{
    CharonNWTxtRecord *record = (CharonNWTxtRecord *)txt_record;
    if (!record || !charon_key_valid(key))
        return false;
    NSUInteger index = [record->_keys indexOfObject:@(key)];
    if (index == NSNotFound)
        return false;
    [record->_keys removeObjectAtIndex:index];
    [record->_values removeObjectAtIndex:index];
    return true;
}

bool nw_txt_record_access_key(nw_txt_record_t txt_record, const char *key, nw_txt_record_access_key_t access_value)
{
    CharonNWTxtRecord *record = (CharonNWTxtRecord *)txt_record;
    if (!record || !access_value)
        return false;
    nw_txt_record_find_key_t found = charon_find(record, key);
    if (found == nw_txt_record_find_key_invalid || found == nw_txt_record_find_key_not_present)
        return access_value(charon_key_valid(key) ? key : "", found, NULL, 0);
    NSUInteger index = [record->_keys indexOfObject:@(key)];
    id value = record->_values[index];
    if (charon_has_no_value(value))
        return access_value(key, found, NULL, 0);
    return access_value(key, found, (const uint8_t *)((NSData *)value).bytes, ((NSData *)value).length);
}

bool nw_txt_record_apply(nw_txt_record_t txt_record, nw_txt_record_applier_t applier)
{
    CharonNWTxtRecord *record = (CharonNWTxtRecord *)txt_record;
    if (!record || !applier)
        return false;
    for (NSUInteger index = 0; index < record->_keys.count; index++) {
        NSString *key = record->_keys[index];
        id value = record->_values[index];
        if (charon_has_no_value(value)) {
            if (!applier(key.UTF8String, nw_txt_record_find_key_no_value, NULL, 0))
                return false;
        } else if (!applier(key.UTF8String, ((NSData *)value).length ? nw_txt_record_find_key_non_empty_value : nw_txt_record_find_key_empty_value,
                            (const uint8_t *)((NSData *)value).bytes, ((NSData *)value).length)) {
            return false;
        }
    }
    return true;
}

bool nw_txt_record_access_bytes(nw_txt_record_t txt_record, nw_txt_record_access_bytes_t access_bytes)
{
    CharonNWTxtRecord *record = (CharonNWTxtRecord *)txt_record;
    if (!record || !access_bytes)
        return false;
    NSMutableData *bytes = [NSMutableData data];
    if (!record->_keys.count) {
        uint8_t empty = 0;
        [bytes appendBytes:&empty length:1];
        return access_bytes((const uint8_t *)bytes.bytes, bytes.length);
    }
    for (NSUInteger index = 0; index < record->_keys.count; index++) {
        NSMutableData *string = [NSMutableData data];
        [string appendData:[(NSString *)record->_keys[index] dataUsingEncoding:NSUTF8StringEncoding]];
        id value = record->_values[index];
        if (!charon_has_no_value(value)) {
            [string appendBytes:"=" length:1];
            [string appendData:(NSData *)value];
        }
        if (string.length > 255)
            return access_bytes(NULL, 0);
        uint8_t length = (uint8_t)string.length;
        [bytes appendBytes:&length length:1];
        [bytes appendData:string];
    }
    return access_bytes(bytes.length ? (const uint8_t *)bytes.bytes : NULL, bytes.length);
}
