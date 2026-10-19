#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <CoreMIDI/MIDIMessages.h>
#include "RevenantCoreMIDI.h"

static int gChecks = 0;
static int gFailures = 0;

static void check(int passed, const char *name, const char *detail)
{
    gChecks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        gFailures++;
        printf("FAIL %s: %s\n", name, detail);
    }
}

static int same_words(const uint32_t *got, size_t gotCount, const unsigned int *want, int wantCount, char *detail, size_t size)
{
    if ((int)gotCount != wantCount) {
        snprintf(detail, size, "got %zu words, macOS gave %d", gotCount, wantCount);
        return 0;
    }
    for (size_t i = 0; i < gotCount; i++) {
        if (got[i] != want[i]) {
            snprintf(detail, size, "word %zu: got %08X, macOS gave %08X", i, got[i], want[i]);
            return 0;
        }
    }
    return 1;
}

static size_t bytes_of_word(uint32_t word, uint8_t *bytes)
{
    bytes[0] = (uint8_t)(word >> 16);
    bytes[1] = (uint8_t)(word >> 8);
    bytes[2] = (uint8_t)word;
    return (bytes[0] & 0xF0) == 0xC0 || (bytes[0] & 0xF0) == 0xD0 ? 2 : 3;
}

static size_t words_of_bytes(const RevenantMIDIBytes *bytes, uint32_t *words)
{
    size_t count = 0;
    for (size_t i = 0; i < bytes->count;) {
        uint8_t status = bytes->bytes[i];
        size_t size = (status & 0xF0) == 0xC0 || (status & 0xF0) == 0xD0 ? 2 : 3;
        uint32_t word = 0x20000000u | (uint32_t)status << 16;
        if (i + 1 < bytes->count && size > 1)
            word |= (uint32_t)bytes->bytes[i + 1] << 8;
        if (i + 2 < bytes->count && size > 2)
            word |= bytes->bytes[i + 2];
        words[count++] = word;
        i += size;
    }
    return count;
}

static void check_scaling_laws(void)
{
    check(RevenantMIDIUp16From7(0) == 0 && RevenantMIDIUp16From7(127) == 0xFFFF, "scaling: 16-bit ends", "");
    check(RevenantMIDIUp32From7(0) == 0 && RevenantMIDIUp32From7(127) == 0xFFFFFFFFu, "scaling: 32-bit ends", "");
    check(RevenantMIDIUp32From7(64) == 0x80000000u, "scaling: 32-bit centre", "");
    int differing = 0;
    for (uint64_t value = 0; value < 128; value++) {
        uint64_t rule = value <= 64 ? value << 25 : 0x80000000ull + (2 * (value - 64) * 0x7FFFFFFFull + 63) / 126;
        if (RevenantMIDIUp32From7((UInt32)value) != (UInt32)rule)
            differing++;
    }
    check(differing == 0, "scaling: the 32-bit rule in 32-bit arithmetic is the 64-bit rule at all 128 inputs", "");
    check(RevenantMIDIUp32From14(0) == 0 && RevenantMIDIUp32From14(16383) == 0xFFFFFFFFu, "scaling: 14-bit ends", "");
    check(RevenantMIDIUp32From14(8192) == 0x80000000u, "scaling: 14-bit centre", "");
    check(RevenantMIDIUMPWordCount(0x20000000u) == 1 && RevenantMIDIUMPWordCount(0x40000000u) == 2 && RevenantMIDIUMPWordCount(0x50000000u) == 4,
          "word counts: one, two and four words by type", "");
}

typedef struct revenant_expect {
    char tag[40];
    unsigned int in[4];
    int inCount;
    unsigned int out[8];
    int outCount;
} revenant_expect;

static const char *gOracleDir;

static int parse_words(const char *text, size_t length, unsigned int *out, int max)
{
    int count = 0;
    size_t i = 0;
    while (i < length) {
        while (i < length && text[i] == ' ')
            i++;
        if (i >= length)
            break;
        unsigned int value = 0;
        int digits = 0;
        while (i < length && text[i] != ' ') {
            char c = text[i++];
            int digit = c >= '0' && c <= '9' ? c - '0' : c >= 'A' && c <= 'F' ? c - 'A' + 10 : c >= 'a' && c <= 'f' ? c - 'a' + 10 : -1;
            if (digit < 0)
                return -1;
            value = value << 4 | (unsigned int)digit;
            digits++;
        }
        if (digits == 0 || digits > 8 || count == max)
            return -1;
        out[count++] = value;
    }
    return count;
}

static revenant_expect *load_rows(const char *name, size_t *count)
{
    char path[1024];
    snprintf(path, sizeof(path), "%s/%s", gOracleDir ? gOracleDir : ".", name);
    *count = 0;
    FILE *file = fopen(path, "r");
    if (!file)
        return NULL;
    size_t capacity = 1024, used = 0;
    revenant_expect *rows = malloc(capacity * sizeof(revenant_expect));
    char line[512];
    int bad = 0;
    while (rows && fgets(line, sizeof(line), file)) {
        if (!strncmp(line, "MISMATCH", 8) || !strncmp(line, "cases=", 6))
            continue;
        char *inMark = strstr(line, " in: ");
        char *arrow = inMark ? strstr(inMark, " -> ") : NULL;
        if (!inMark || !arrow || (size_t)(inMark - line) >= sizeof(rows[0].tag)) {
            bad++;
            continue;
        }
        if (used == capacity) {
            capacity *= 2;
            revenant_expect *grown = realloc(rows, capacity * sizeof(revenant_expect));
            if (!grown) {
                bad++;
                break;
            }
            rows = grown;
        }
        revenant_expect *row = &rows[used];
        memcpy(row->tag, line, (size_t)(inMark - line));
        row->tag[inMark - line] = 0;
        char *inWords = inMark + 5;
        char *outWords = arrow + 4;
        size_t outLength = strlen(outWords);
        while (outLength > 0 && (outWords[outLength - 1] == '\n' || outWords[outLength - 1] == ' '))
            outLength--;
        row->inCount = parse_words(inWords, (size_t)(arrow - inWords), row->in, 4);
        row->outCount = parse_words(outWords, outLength, row->out, 8);
        if (row->inCount < 0 || row->outCount < 0) {
            bad++;
            continue;
        }
        used++;
    }
    fclose(file);
    if (bad || !rows) {
        printf("    %s: %d rows that cannot be read\n", name, bad);
        free(rows);
        return NULL;
    }
    *count = used;
    return rows;
}

static void check_up_rows(void)
{
    size_t count = 0;
    revenant_expect *rows = load_rows("batch-up.txt", &count);
    int failed = 0;
    char detail[160];
    for (size_t i = 0; i < count; i++) {
        const revenant_expect *row = &rows[i];
        uint8_t bytes[3];
        size_t size = bytes_of_word(row->in[0], bytes);
        RevenantMIDIParser parser;
        memset(&parser, 0, sizeof(parser));
        RevenantMIDIWords words;
        memset(&words, 0, sizeof(words));
        RevenantMIDIParseBytes(&parser, bytes, size, 2, 0, &words);
        if (!same_words(words.words, words.count, row->out, row->outCount, detail, sizeof(detail))) {
            if (failed < 5)
                printf("    %s (in %08X): %s\n", row->tag, row->in[0], detail);
            failed++;
        }
        free(words.words);
    }
    char name[96];
    snprintf(name, sizeof(name), "1.0 -> 2.0 rows from macOS (%zu, all of the recorded answers)", count);
    snprintf(detail, sizeof(detail), "%d rows differ", failed);
    check(rows != NULL && count > 0 && failed == 0, name, rows ? detail : "the recorded answers cannot be read");
    free(rows);
}

static void check_down_rows(void)
{
    size_t count = 0;
    revenant_expect *rows = load_rows("batch-down.txt", &count);
    int failed = 0;
    char detail[160];
    for (size_t i = 0; i < count; i++) {
        const revenant_expect *row = &rows[i];
        RevenantMIDIRPN rpn[16];
        memset(rpn, 0, sizeof(rpn));
        RevenantMIDIBytes bytes;
        memset(&bytes, 0, sizeof(bytes));
        RevenantMIDIUMPToBytes(row->in, (size_t)row->inCount, rpn, &bytes);
        uint32_t words[16];
        size_t produced = words_of_bytes(&bytes, words);
        if (!same_words(words, produced, row->out, row->outCount, detail, sizeof(detail))) {
            if (failed < 5)
                printf("    %s (in %08X %08X): %s\n", row->tag, row->in[0], row->in[1], detail);
            failed++;
        }
        free(bytes.bytes);
    }
    char name[96];
    snprintf(name, sizeof(name), "2.0 -> 1.0 rows from macOS (%zu, all of the recorded answers)", count);
    snprintf(detail, sizeof(detail), "%d rows differ", failed);
    check(rows != NULL && count > 0 && failed == 0, name, rows ? detail : "the recorded answers cannot be read");
    free(rows);
}

static void check_bytes_to_ump(void)
{
    struct {
        const char *name;
        uint8_t bytes[8];
        int count;
        uint32_t want[4];
        int wantCount;
    } cases[] = {
        {"90 3C 7F", {0x90, 0x3C, 0x7F}, 3, {0x20903C7Fu}, 1},
        {"B0 07 40", {0xB0, 0x07, 0x40}, 3, {0x20B00740u}, 1},
        {"E0 00 40", {0xE0, 0x00, 0x40}, 3, {0x20E00040u}, 1},
        {"C0 05", {0xC0, 0x05}, 2, {0x20C00500u}, 1},
        {"F8", {0xF8}, 1, {0x10F80000u}, 1},
        {"F2 01 02", {0xF2, 0x01, 0x02}, 3, {0x10F20102u}, 1},
        {"F0 01 02 03 F7", {0xF0, 0x01, 0x02, 0x03, 0xF7}, 5, {0x30030102u, 0x03000000u}, 2},
    };
    for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
        RevenantMIDIParser parser;
        memset(&parser, 0, sizeof(parser));
        RevenantMIDIWords words;
        memset(&words, 0, sizeof(words));
        RevenantMIDIParseBytes(&parser, cases[c].bytes, (size_t)cases[c].count, 1, 0, &words);
        char detail[160];
        int passed = same_words(words.words, words.count, cases[c].want, cases[c].wantCount, detail, sizeof(detail));
        char name[96];
        snprintf(name, sizeof(name), "bytes %s -> 1.0 words", cases[c].name);
        check(passed, name, detail);
        free(words.words);
    }
}

static void check_rpn_sequence(void)
{
    RevenantMIDIRPN rpn[16];
    memset(rpn, 0, sizeof(rpn));
    struct {
        const char *name;
        uint32_t word0, word1;
        uint8_t want[12];
        int wantCount;
    } cases[] = {
        {"program with bank", 0x40C00001u, 0x05000A03u, {0xB0, 0x00, 0x0A, 0xB0, 0x20, 0x03, 0xC0, 0x05}, 8},
        {"rpn 0,0 value 0x00400000", 0x40200000u, 0x00400000u, {0xB0, 0x65, 0x00, 0xB0, 0x64, 0x00, 0xB0, 0x06, 0x00, 0xB0, 0x26, 0x10}, 12},
        {"nrpn 1,35 value 0x00400000", 0x40300000u | 0x0100u | 0x23u, 0x00400000u, {0xB0, 0x63, 0x01, 0xB0, 0x62, 0x23, 0xB0, 0x06, 0x00, 0xB0, 0x26, 0x10}, 12},
        {"rpn 0,0 value 0", 0x40200000u, 0x00000000u, {0xB0, 0x65, 0x00, 0xB0, 0x64, 0x00, 0xB0, 0x06, 0x00}, 9},
        {"rpn 0,0 value FFFFFFFF (same parameter)", 0x40200000u, 0xFFFFFFFFu, {0xB0, 0x06, 0x7F, 0xB0, 0x26, 0x7F}, 6},
    };
    for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
        uint32_t words[2] = {cases[c].word0, cases[c].word1};
        RevenantMIDIBytes bytes;
        memset(&bytes, 0, sizeof(bytes));
        RevenantMIDIUMPToBytes(words, 2, rpn, &bytes);
        int passed = bytes.count == (size_t)cases[c].wantCount && memcmp(bytes.bytes, cases[c].want, bytes.count) == 0;
        char name[96], detail[64];
        snprintf(name, sizeof(name), "2.0 -> 1.0 %s", cases[c].name);
        snprintf(detail, sizeof(detail), "got %zu bytes", bytes.count);
        check(passed, name, detail);
        free(bytes.bytes);
    }
}

static void check_dropped_messages(void)
{
    uint32_t words[][2] = {{0x40603C00u, 0x40000000u}, {0x40F03C00u, 0x00000001u}, {0x40103C00u, 0x40000000u}, {0x40400000u, 0x00400000u}};
    for (size_t c = 0; c < sizeof(words) / sizeof(words[0]); c++) {
        RevenantMIDIRPN rpn[16];
        memset(rpn, 0, sizeof(rpn));
        RevenantMIDIBytes bytes;
        memset(&bytes, 0, sizeof(bytes));
        RevenantMIDIUMPToBytes(words[c], 2, rpn, &bytes);
        char name[96];
        snprintf(name, sizeof(name), "2.0 %08X dropped, as macOS drops it", words[c][0]);
        check(bytes.count == 0, name, "produced bytes");
        free(bytes.bytes);
    }
}

static void check_sysex_chunks(void)
{
    struct {
        const char *name;
        uint8_t bytes[16];
        int count;
        uint32_t want[8];
        int wantCount;
    } cases[] = {
        {"empty", {0xF0, 0xF7}, 2, {0x30000000u, 0x00000000u}, 2},
        {"6 bytes", {0xF0, 1, 2, 3, 4, 5, 6, 0xF7}, 8, {0x30060102u, 0x03040506u}, 2},
        {"7 bytes", {0xF0, 1, 2, 3, 4, 5, 6, 7, 0xF7}, 9, {0x30160102u, 0x03040506u, 0x30310700u, 0x00000000u}, 4},
        {"12 bytes", {0xF0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0xF7}, 14,
         {0x30160102u, 0x03040506u, 0x30360708u, 0x090A0B0Cu}, 4},
        {"open at the end of the list", {0xF0, 1, 2}, 3, {0x30120102u, 0x00000000u}, 2},
        {"real-time byte inside", {0xF0, 1, 0xF8, 2, 0xF7}, 5,
         {0x30010100u, 0x00000000u, 0x10F80000u, 0x30310200u, 0x00000000u}, 5},
        {"real-time byte at the end", {0xF0, 1, 0xF8, 0xF7}, 4,
         {0x30010100u, 0x00000000u, 0x10F80000u, 0x30300000u, 0x00000000u}, 5},
    };
    for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
        RevenantMIDIParser parser;
        memset(&parser, 0, sizeof(parser));
        RevenantMIDIWords words;
        memset(&words, 0, sizeof(words));
        RevenantMIDIParseBytes(&parser, cases[c].bytes, (size_t)cases[c].count, 2, 0, &words);
        RevenantMIDIParseFlush(&parser, 0, &words);
        char detail[160], name[96];
        int passed = same_words(words.words, words.count, cases[c].want, cases[c].wantCount, detail, sizeof(detail));
        snprintf(name, sizeof(name), "SysEx %s -> UMP", cases[c].name);
        check(passed, name, detail);
        free(words.words);
    }
}

static void check_sysex_split(void)
{
    RevenantMIDIParser parser;
    memset(&parser, 0, sizeof(parser));
    RevenantMIDIWords words;
    memset(&words, 0, sizeof(words));
    uint8_t first[3] = {0xF0, 1, 2}, second[3] = {3, 4, 0xF7};
    RevenantMIDIParseBytes(&parser, first, 3, 2, 0, &words);
    RevenantMIDIParseBytes(&parser, second, 3, 2, 0, &words);
    RevenantMIDIParseFlush(&parser, 0, &words);
    const uint32_t want[2] = {0x30040102u, 0x03040000u};
    char detail[160];
    check(same_words(words.words, words.count, want, 2, detail, sizeof(detail)), "SysEx split over two packets of one list", detail);
    free(words.words);
}

static void check_event_list_rules(void)
{
    static uint8_t buffer[1024];
    uint32_t words[70];
    for (int i = 0; i < 70; i++)
        words[i] = 0x20900000u + (uint32_t)i;

    MIDIEventList *list = (MIDIEventList *)buffer;
    list->protocol = 1;
    list->numPackets = 0;
    MIDIEventPacket *end = &list->packet[0];
    end = RevenantMIDIEventListAdd(list, sizeof(buffer), end, 7, 2, words);
    end = RevenantMIDIEventListAdd(list, sizeof(buffer), end, 7, 2, words + 2);
    check(list->numPackets == 1 && list->packet[0].wordCount == 4 && list->packet[0].timeStamp == 7 &&
          list->packet[0].words[3] == 0x20900003u, "event list: same time stamp merges (macOS probe3 A)", "");

    list->numPackets = 0;
    end = &list->packet[0];
    end = RevenantMIDIEventListAdd(list, sizeof(buffer), end, 7, 1, words);
    end = RevenantMIDIEventListAdd(list, sizeof(buffer), end, 8, 1, words + 1);
    end = RevenantMIDIEventListAdd(list, sizeof(buffer), end, 8, 1, words + 2);
    MIDIEventPacket *second = MIDIEventPacketNext(&list->packet[0]);
    check(list->numPackets == 2 && list->packet[0].wordCount == 1 && second->wordCount == 2 &&
          second->timeStamp == 8, "event list: new time stamp starts a packet (macOS probe3 B)", "");

    list->numPackets = 0;
    end = &list->packet[0];
    check(RevenantMIDIEventListAdd(list, sizeof(buffer), end, 7, 0, words) == end && list->numPackets == 0,
          "event list: zero words adds nothing (macOS probe3 G)", "");

    list->numPackets = 0;
    end = &list->packet[0];
    end = RevenantMIDIEventListAdd(list, sizeof(buffer), end, 7, 65, words);
    check(end != NULL && list->numPackets == 1 && list->packet[0].wordCount == 65,
          "event list: 65 words kept whole (macOS probe3 D)", "");

    static uint8_t small[40];
    MIDIEventList *tiny = (MIDIEventList *)small;
    tiny->protocol = 1;
    tiny->numPackets = 0;
    MIDIEventPacket *at = &tiny->packet[0];
    int merged = 0;
    while (at) {
        MIDIEventPacket *next = RevenantMIDIEventListAdd(tiny, sizeof(small), at, 5, 1, words);
        if (!next)
            break;
        at = next;
        merged++;
    }
    check(merged == 5 && tiny->numPackets == 1, "event list: 40 bytes hold five merged words (macOS probe3 I)", "");

    list->numPackets = 0;
    end = &list->packet[0];
    int packets = 0;
    uint8_t sixty[64];
    MIDIEventList *shortList = (MIDIEventList *)sixty;
    shortList->numPackets = 0;
    end = &shortList->packet[0];
    while (end) {
        MIDIEventPacket *next = RevenantMIDIEventListAdd(shortList, sizeof(sixty), end, (MIDITimeStamp)packets, 1, words);
        if (!next)
            break;
        end = next;
        packets++;
    }
    check(packets == 3 && shortList->numPackets == 3, "event list: 64 bytes hold three packets (macOS probe2)", "");
}

#include "eventlistadd.h"

static void check_event_list_oracle(void)
{
    char path[1024];
    snprintf(path, sizeof(path), "%s/eventlistadd-macos.txt", gOracleDir);
    FILE *recorded = fopen(path, "r");
    char *text = NULL;
    size_t length = 0;
    FILE *out = open_memstream(&text, &length);
    if (!recorded || !out) {
        check(0, "event list: the recorded macOS lines are read", path);
        return;
    }
    eventlistadd_run(out);
    fclose(out);
    char want[512];
    const char *at = text;
    int lines = 0, differing = 0;
    while (fgets(want, sizeof(want), recorded)) {
        size_t n = strlen(want);
        lines++;
        if (strncmp(at, want, n) != 0) {
            differing++;
            char detail[1024];
            const char *eol = strchr(at, '\n');
            snprintf(detail, sizeof(detail), "line %d: macOS \"%.*s\", library \"%.*s\"", lines, (int)n - 1, want,
                     eol ? (int)(eol - at) : 0, at);
            check(0, "event list: add and return as macOS (oracle/eventlistadd-macos.txt)", detail);
            break;
        }
        at += n;
    }
    fclose(recorded);
    check(differing == 0 && lines > 0 && *at == 0, "event list: the library prints every recorded macOS line, and no other",
          lines > 0 ? "" : "no lines recorded");
    free(text);
}

static double event_list_build_ms(int packets)
{
    size_t size = 64 + (size_t)packets * 16;
    MIDIEventList *list = malloc(size);
    UInt32 word = 0x20903C7F;
    double best = 1e9;
    for (int run = 0; run < 5; run++) {
        struct timespec begin, finish;
        clock_gettime(CLOCK_MONOTONIC, &begin);
        MIDIEventPacket *p = MIDIEventListInit(list, kMIDIProtocol_1_0);
        for (int i = 0; i < packets && p; i++)
            p = MIDIEventListAdd(list, size, p, (MIDITimeStamp)i + 1, 1, &word);
        clock_gettime(CLOCK_MONOTONIC, &finish);
        double ms = (double)(finish.tv_sec - begin.tv_sec) * 1e3 + (double)(finish.tv_nsec - begin.tv_nsec) / 1e6;
        if (p && ms < best)
            best = ms;
    }
    free(list);
    return best;
}

static void check_event_list_linear(void)
{
    double small = event_list_build_ms(4000), large = event_list_build_ms(16000);
    char detail[128];
    snprintf(detail, sizeof(detail), "4000 packets %.3f ms, 16000 packets %.3f ms, ratio %.1f", small, large,
             small > 0 ? large / small : 0.0);
    check(small > 0 && large < 8 * small, "event list: building by MIDIEventListAdd is linear in its packets", detail);
}

extern const CFStringRef revenant_host_kMIDIPropertyUMPActiveGroupBitmap;
extern const CFStringRef revenant_host_kMIDIPropertyUMPCanTransmitGroupless;
extern const CFStringRef revenant_host_kMIDIPropertyAssociatedEndpoint;
extern NSString *const revenant_host_MIDICIDeviceObjectKey;
extern NSString *const revenant_host_MIDICIProfileObjectKey;
extern NSString *const revenant_host_MIDIUMPEndpointObjectKey;
extern NSString *const revenant_host_MIDIUMPFunctionBlockObjectKey;
extern NSString *const revenant_host_MIDICIDeviceWasAddedNotification;
extern NSString *const revenant_host_MIDICIDeviceWasRemovedNotification;
extern NSString *const revenant_host_MIDICIProfileWasRemovedNotification;
extern NSString *const revenant_host_MIDICIProfileWasUpdatedNotification;
extern NSString *const revenant_host_MIDIUMPEndpointWasAddedNotification;
extern NSString *const revenant_host_MIDIUMPEndpointWasRemovedNotification;
extern NSString *const revenant_host_MIDIUMPEndpointWasUpdatedNotification;
extern NSString *const revenant_host_MIDIUMPFunctionBlockWasUpdatedNotification;

static void check_constants(void)
{
    check([(__bridge NSString *)revenant_host_kMIDIPropertyUMPActiveGroupBitmap isEqualToString:@"active group bitmap"],
          "constant kMIDIPropertyUMPActiveGroupBitmap is \"active group bitmap\", as on macOS after MIDIClientCreate", "");
    check([(__bridge NSString *)revenant_host_kMIDIPropertyUMPCanTransmitGroupless isEqualToString:@"ump endpoint"],
          "constant kMIDIPropertyUMPCanTransmitGroupless is \"ump endpoint\", as on macOS after MIDIClientCreate", "");
    check([(__bridge NSString *)revenant_host_kMIDIPropertyAssociatedEndpoint isEqualToString:@"associated endpoint"],
          "constant kMIDIPropertyAssociatedEndpoint is \"associated endpoint\", as on macOS after MIDIClientCreate", "");
    NSDictionary *names = @{
        @"MIDICIDeviceObjectKey": revenant_host_MIDICIDeviceObjectKey,
        @"MIDICIProfileObjectKey": revenant_host_MIDICIProfileObjectKey,
        @"MIDIUMPEndpointObjectKey": revenant_host_MIDIUMPEndpointObjectKey,
        @"MIDIUMPFunctionBlockObjectKey": revenant_host_MIDIUMPFunctionBlockObjectKey,
        @"MIDICIDeviceWasAddedNotification": revenant_host_MIDICIDeviceWasAddedNotification,
        @"MIDICIDeviceWasRemovedNotification": revenant_host_MIDICIDeviceWasRemovedNotification,
        @"MIDICIProfileWasRemovedNotification": revenant_host_MIDICIProfileWasRemovedNotification,
        @"MIDICIProfileWasUpdatedNotification": revenant_host_MIDICIProfileWasUpdatedNotification,
        @"MIDIUMPEndpointWasAddedNotification": revenant_host_MIDIUMPEndpointWasAddedNotification,
        @"MIDIUMPEndpointWasRemovedNotification": revenant_host_MIDIUMPEndpointWasRemovedNotification,
        @"MIDIUMPEndpointWasUpdatedNotification": revenant_host_MIDIUMPEndpointWasUpdatedNotification,
        @"MIDIUMPFunctionBlockWasUpdatedNotification": revenant_host_MIDIUMPFunctionBlockWasUpdatedNotification,
    };
    int matched = 0;
    for (NSString *name in names) {
        if ([(NSString *)names[name] isEqualToString:name])
            matched++;
    }
    char detail[64];
    snprintf(detail, sizeof(detail), "%d of 12 equal their names", matched);
    check(matched == 12, "constants: the 12 keys and notifications are their names, as on macOS", detail);
}

#include "visit-expectations.h"

extern void revenant_host_MIDIEventListForEachEvent(const MIDIEventList *evtlist, MIDIEventVisitor visitor, void *visitorContext);

static MIDIUniversalMessage gVisited[4];
static int gVisitedCount;

static void revenant_visit_record(void *context, MIDITimeStamp timeStamp, MIDIUniversalMessage message)
{
    if (gVisitedCount < 4)
        gVisited[gVisitedCount++] = message;
}

static void check_visitor(void)
{
    int failed = 0;
    size_t total = sizeof(revenant_visit_cases) / sizeof(revenant_visit_cases[0]);
    for (size_t c = 0; c < total; c++) {
        const revenant_visit_case *row = &revenant_visit_cases[c];
        Byte buffer[256];
        MIDIEventList *list = (MIDIEventList *)buffer;
        UInt32 words[4];
        for (int w = 0; w < row->wordCount; w++)
            words[w] = row->words[w];
        MIDIEventPacket *end = MIDIEventListInit(list, row->wordCount > 1 ? kMIDIProtocol_2_0 : kMIDIProtocol_1_0);
        RevenantMIDIEventListAdd(list, sizeof(buffer), end, 42, (size_t)row->wordCount, words);
        gVisitedCount = 0;
        revenant_host_MIDIEventListForEachEvent(list, revenant_visit_record, NULL);
        const unsigned char *got = gVisitedCount == 1 ? (const unsigned char *)&gVisited[0] : NULL;
        size_t from = 8, to = 23;
        unsigned int type = row->bytes[0];
        if (type == 0x00 || type == 0x01) to = 13;
        else if (type == 0x02) to = 17;
        else if (type == 0x03) to = 18;
        else if (type == 0x05) to = 26;
        int same = got != NULL;
        for (size_t i = 0; same && i < 5; i++)
            same = got[i] == row->bytes[i];
        for (size_t i = from; same && i <= to; i++)
            same = got[i] == row->bytes[i];
        if (!same) {
            if (failed < 5)
                printf("    visitor %s: got %s\n", row->label, got ? "a different message" : "no message");
            failed++;
        }
    }
    char name[96], detail[64];
    snprintf(name, sizeof(name), "visitor: %zu macOS messages, the defined bytes equal", total);
    snprintf(detail, sizeof(detail), "%d differ", failed);
    check(failed == 0, name, detail);
}

extern OSStatus revenant_host_MIDIEventPacketSysexBytesForGroup(const MIDIEventPacket *pkt, UInt8 groupIndex, CFDataRef *outData);
extern OSStatus revenant_host_MIDIDeviceNewEntity(MIDIDeviceRef device, CFStringRef name, MIDIProtocolID protocol, Boolean embedded,
                                                ItemCount numSourceEndpoints, ItemCount numDestinationEndpoints, MIDIEntityRef *newEntity);

static int bytes_equal_hex(CFDataRef data, const char *want)
{
    if (!data || CFDataGetLength(data) != (CFIndex)(strlen(want) / 2))
        return 0;
    const UInt8 *b = CFDataGetBytePtr(data);
    for (size_t i = 0; i < strlen(want) / 2; i++) {
        unsigned int v = 0;
        sscanf(want + 2 * i, "%2X", &v);
        if (b[i] != v)
            return 0;
    }
    return 1;
}

static void check_sysex_bytes_for_group(void)
{
    struct {
        const char *name;
        UInt32 words[2];
        int wordCount;
        UInt8 group;
        OSStatus status;
        const char *want;
    } cases[] = {
        {"complete 3 bytes", {0x30030102u, 0x03000000u}, 2, 0, 0, "F0010203F7"},
        {"complete 3 bytes, group 1", {0x30030102u, 0x03000000u}, 2, 1, -50, NULL},
        {"start 6 bytes", {0x30160102u, 0x03040506u}, 2, 0, 0, "F0010203040506"},
        {"continue 6 bytes", {0x30260708u, 0x090A0B0Cu}, 2, 0, 0, "0708090A0B0C"},
        {"end 1 byte", {0x30310D00u, 0x00000000u}, 2, 0, 0, "0DF7"},
        {"end 0 bytes", {0x30300000u, 0x00000000u}, 2, 0, 0, "F7"},
        {"midi 2.0 note on", {0x40903C00u, 0xFFFF0000u}, 2, 0, -50, NULL},
        {"complete, group 15", {0x30030102u, 0x03000000u}, 2, 15, -50, NULL},
    };
    int failed = 0;
    for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
        Byte buffer[256];
        MIDIEventList *list = (MIDIEventList *)buffer;
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        RevenantMIDIEventListAdd(list, sizeof(buffer), end, 0, (size_t)cases[c].wordCount, cases[c].words);
        CFDataRef data = NULL;
        OSStatus status = revenant_host_MIDIEventPacketSysexBytesForGroup(&list->packet[0], cases[c].group, &data);
        int same = status == cases[c].status;
        if (cases[c].want)
            same = same && bytes_equal_hex(data, cases[c].want);
        else
            same = same && data == NULL;
        if (!same) {
            printf("    sysex bytes %s: status %d\n", cases[c].name, (int)status);
            failed++;
        }
        if (data)
            CFRelease(data);
    }
    char name[96], detail[64];
    snprintf(name, sizeof(name), "sysex bytes for group: %zu macOS answers", sizeof(cases) / sizeof(cases[0]));
    snprintf(detail, sizeof(detail), "%d differ", failed);
    check(failed == 0, name, detail);
}

static void sysex7_words(UInt32 *out, UInt32 status, const UInt8 *data, UInt32 count)
{
    UInt8 pad[6] = {0, 0, 0, 0, 0, 0};
    memcpy(pad, data, count);
    out[0] = 0x30000000u | status << 20 | count << 16 | (UInt32)pad[0] << 8 | pad[1];
    out[1] = (UInt32)pad[2] << 24 | (UInt32)pad[3] << 16 | (UInt32)pad[4] << 8 | pad[5];
}

static void check_sysex_long(void)
{
    struct {
        const char *name;
        int complete;
        const char *want;
    } cases[] = {
        {"12 complete messages of 6 bytes", 1,
         "F0010203040506F7F00708090A0B0CF7F00D0E0F101112F7F0131415161718F7F0191A1B1C1D1EF7F01F2021222324F7F025262728292A"
         "F7F02B2C2D2E2F30F7F0313233343536F7F03738393A3B3CF7F03D3E3F404142F7F0434445464748F7"},
        {"start, 10 continues, end: 66 bytes", 0,
         "F00102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F303132333435363738"
         "393A3B3C3D3E3F404142434445464748F7"},
    };
    int failed = 0;
    for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
        UInt32 words[24];
        for (UInt32 part = 0; part < 12; part++) {
            UInt8 data[6];
            for (UInt32 i = 0; i < 6; i++)
                data[i] = (UInt8)(1 + part * 6 + i);
            UInt32 status = cases[c].complete ? 0 : (part == 0 ? 1 : (part == 11 ? 3 : 2));
            sysex7_words(words + 2 * part, status, data, 6);
        }
        Byte buffer[256];
        MIDIEventList *list = (MIDIEventList *)buffer;
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        RevenantMIDIEventListAdd(list, sizeof(buffer), end, 0, 24, words);
        CFDataRef data = NULL;
        OSStatus status = revenant_host_MIDIEventPacketSysexBytesForGroup(&list->packet[0], 0, &data);
        int same = status == 0 && bytes_equal_hex(data, cases[c].want);
        if (!same) {
            printf("    sysex long %s: status %d\n", cases[c].name, (int)status);
            failed++;
        }
        if (data)
            CFRelease(data);
    }
    char name[96], detail[64];
    snprintf(name, sizeof(name), "sysex bytes for group, long: %zu macOS answers", sizeof(cases) / sizeof(cases[0]));
    snprintf(detail, sizeof(detail), "%d differ", failed);
    check(failed == 0, name, detail);
}

static void check_event_list_wrap(void)
{
    Byte buffer[64];
    MIDIEventList *list = (MIDIEventList *)buffer;
    list->protocol = kMIDIProtocol_2_0;
    list->numPackets = 0;
    UInt32 word = 0;
    MIDIEventPacket *next = RevenantMIDIEventListAdd(list, sizeof(buffer), &list->packet[0], 0, SIZE_MAX / 2, &word);
    check(next == NULL && list->numPackets == 0, "RevenantMIDIEventListAdd refuses a word count whose byte size wraps", "");
}

static void check_new_entity_device_zero(void)
{
    MIDIEntityRef entity = 99;
    OSStatus status = revenant_host_MIDIDeviceNewEntity(0, CFSTR("x"), kMIDIProtocol_1_0, false, 0, 0, &entity);
    check(status == -50 && entity == 0, "MIDIDeviceNewEntity on device 0: paramErr and no entity, as macOS", "");
}

static size_t hex_bytes(const char *text, uint8_t *out)
{
    size_t n = 0;
    for (const char *p = text; *p;) {
        if (*p == ' ') {
            p++;
            continue;
        }
        unsigned int v = 0;
        sscanf(p, "%2X", &v);
        out[n++] = (uint8_t)v;
        p += 2;
    }
    return n;
}

static void check_ble_case(const char *name, const char *const *packets, int packetCount, const char *want)
{
    RevenantBLEParser parser;
    memset(&parser, 0, sizeof(parser));
    uint8_t got[1024];
    size_t count = 0;
    for (int p = 0; p < packetCount; p++) {
        uint8_t data[256];
        size_t n = hex_bytes(packets[p], data);
        count += RevenantBLEMIDIParse(&parser, data, n, got + count);
    }
    uint8_t wantBytes[1024];
    size_t wantCount = hex_bytes(want, wantBytes);
    int same = count == wantCount && memcmp(got, wantBytes, count) == 0;
    char detail[3 * 1024 + 64] = "";
    size_t at = 0;
    for (size_t i = 0; i < count && at + 4 < sizeof(detail); i++)
        at += (size_t)snprintf(detail + at, sizeof(detail) - at, "%02X ", got[i]);
    check(same, name, detail);
}

static void check_ble_parse(void)
{
    const char *single[] = {"80 80 90 3C 7F"};
    check_ble_case("BLE: a note after its timestamp", single, 1, "90 3C 7F");
    const char *timestampNotStatus[] = {"80 81 3C 40"};
    check_ble_case("BLE: a timestamp is not a status: data with no status is dropped", timestampNotStatus, 1, "");
    const char *headerOnly[] = {"80 81"};
    check_ble_case("BLE: a header and a timestamp alone give nothing", headerOnly, 1, "");
    const char *runningStatus[] = {"80 81 90 3C 7F 82 3E 00"};
    check_ble_case("BLE: running status after a timestamp is sent with its data", runningStatus, 1, "90 3C 7F 90 3E 00");
    const char *sysex[] = {"80 81 F0 01 02 82 F7"};
    check_ble_case("BLE: a SysEx with the timestamp before its F7", sysex, 1, "F0 01 02 F7");
    const char *realtimeNote[] = {"80 81 90 3C 7F 82 F8 83 3E 00"};
    check_ble_case("BLE: a real-time byte between notes keeps the running status", realtimeNote, 1, "90 3C 7F F8 90 3E 00");
    const char *realtimeSysex[] = {"80 81 F0 01 82 F8 02 83 F7"};
    check_ble_case("BLE: a real-time byte inside a SysEx does not end it", realtimeSysex, 1, "F0 01 F8 02 F7");
    const char *split[] = {"80 81 F0 01 02", "80 82 03 83 F7"};
    check_ble_case("BLE: a SysEx continued in the next notification", split, 2, "F0 01 02 03 F7");
    const char *notHeader[] = {"01 81 90 3C 7F"};
    check_ble_case("BLE: a packet without a header is dropped", notHeader, 1, "");
    const char *stray[] = {"80 81 F7"};
    check_ble_case("BLE: a stray F7 is not a message", stray, 1, "");
    const char *twoNotes[] = {"80 81 90 3C 7F 82 90 3E 00"};
    check_ble_case("BLE: two notes, each with its own timestamp", twoNotes, 1, "90 3C 7F 90 3E 00");
}

static void check_system_words(void)
{
    struct {
        const char *name;
        uint32_t word;
        const char *want;
    } cases[] = {
        {"F0", 0x10F00000u, ""},
        {"F7", 0x10F70000u, ""},
        {"data 45 in the status position", 0x10450000u, ""},
        {"90 with no data", 0x10900000u, ""},
        {"MTC", 0x10F10000u, "F1 00"},
        {"clock", 0x10F80000u, "F8"},
        {"F4", 0x10F40000u, ""},
        {"F5", 0x10F50000u, ""},
        {"tune request", 0x10F60000u, "F6"},
        {"active sensing", 0x10FE0000u, "FE"},
        {"song position 0", 0x10F20000u, "F2 00 00"},
    };
    int failed = 0;
    for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
        RevenantMIDIRPN rpn[16];
        memset(rpn, 0, sizeof(rpn));
        RevenantMIDIBytes bytes;
        memset(&bytes, 0, sizeof(bytes));
        UInt32 word = cases[c].word;
        RevenantMIDIUMPToBytes(&word, 1, rpn, &bytes);
        uint8_t want[8];
        size_t wantCount = hex_bytes(cases[c].want, want);
        int same = !bytes.failed && bytes.count == wantCount && memcmp(bytes.bytes, want, wantCount) == 0;
        if (!same) {
            printf("    system word %s: got %zu bytes\n", cases[c].name, bytes.count);
            failed++;
        }
        free(bytes.bytes);
    }
    char name[96], detail[64];
    snprintf(name, sizeof(name), "UMP system words: the %zu measured answers of macOS", sizeof(cases) / sizeof(cases[0]));
    snprintf(detail, sizeof(detail), "%d differ", failed);
    check(failed == 0, name, detail);
}

static void check_visit_word_sizes(void)
{
    struct {
        const char *name;
        uint32_t head;
        int events;
    } cases[] = {
        {"type 6", 0x60ABCDEFu, 4},
        {"type 7", 0x70ABCDEFu, 4},
        {"type 8", 0x80ABCDEFu, 3},
        {"type 9", 0x90ABCDEFu, 3},
        {"type A", 0xA0ABCDEFu, 3},
        {"type B", 0xB0ABCDEFu, 2},
        {"type C", 0xC0ABCDEFu, 2},
        {"type E", 0xE0ABCDEFu, 1},
    };
    int failed = 0;
    for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
        Byte buffer[256];
        MIDIEventList *list = (MIDIEventList *)buffer;
        UInt32 words[4] = {cases[c].head, 0x00000000u, 0x10F80000u, 0x20903C7Fu};
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        RevenantMIDIEventListAdd(list, sizeof(buffer), end, 42, 4, words);
        gVisitedCount = 0;
        revenant_host_MIDIEventListForEachEvent(list, revenant_visit_record, NULL);
        if (gVisitedCount != cases[c].events) {
            printf("    visitor %s: %d events, macOS %d\n", cases[c].name, gVisitedCount, cases[c].events);
            failed++;
        }
    }
    char name[96], detail[64];
    snprintf(name, sizeof(name), "visitor: the event count of %zu word types, as macOS", sizeof(cases) / sizeof(cases[0]));
    snprintf(detail, sizeof(detail), "%d differ", failed);
    check(failed == 0, name, detail);
}

extern int revenant_ump_classes_run(int *checks);
extern int revenant_ports_run(int *checks);

int main(int argc, char **argv)
{
    gOracleDir = argc > 1 ? argv[1] : ".";
    @autoreleasepool {
        check_scaling_laws();
        check_up_rows();
        check_down_rows();
        check_bytes_to_ump();
        check_rpn_sequence();
        check_dropped_messages();
        check_sysex_chunks();
        check_sysex_split();
        check_event_list_rules();
        check_event_list_oracle();
        check_event_list_linear();
        check_constants();
        check_visitor();
        check_sysex_bytes_for_group();
        check_sysex_long();
        {
            int umpChecks = 0;
            gFailures += revenant_ump_classes_run(&umpChecks);
            gChecks += umpChecks;
        }
        check_new_entity_device_zero();
        check_event_list_wrap();
        check_ble_parse();
        check_system_words();
        check_visit_word_sizes();
        {
            int portChecks = 0;
            gFailures += revenant_ports_run(&portChecks);
            gChecks += portChecks;
        }
        printf("checks=%d failures=%d\n", gChecks, gFailures);
    }
    return gFailures == 0 ? 0 : 1;
}
