#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <pthread.h>

typedef struct {
    int code;
    CFStringRef name;
} revenant_code_name;

static const revenant_code_name revenant_primaries_names[] = {
    {1, CFSTR("ITU_R_709_2")}, {5, CFSTR("EBU_3213")}, {6, CFSTR("SMPTE_C")}, {9, CFSTR("ITU_R_2020")},
    {11, CFSTR("DCI_P3")}, {12, CFSTR("P3_D65")}, {22, CFSTR("P22")}
};

static const revenant_code_name revenant_transfer_names[] = {
    {1, CFSTR("ITU_R_709_2")}, {6, CFSTR("ITU_R_709_2")}, {14, CFSTR("ITU_R_709_2")}, {15, CFSTR("ITU_R_709_2")},
    {7, CFSTR("SMPTE_240M_1995")}, {8, CFSTR("Linear")}, {13, CFSTR("IEC_sRGB")}, {16, CFSTR("SMPTE_ST_2084_PQ")},
    {17, CFSTR("SMPTE_ST_428_1")}, {18, CFSTR("ITU_R_2100_HLG")}
};

static const revenant_code_name revenant_transfer_strings[] = {
    {1, CFSTR("ITU_R_709_2")}, {2, CFSTR("UseGamma")}, {7, CFSTR("SMPTE_240M_1995")}, {16, CFSTR("SMPTE_ST_2084_PQ")},
    {17, CFSTR("SMPTE_ST_428_1")}, {18, CFSTR("ITU_R_2100_HLG")}, {8, CFSTR("Linear")}, {13, CFSTR("IEC_sRGB")},
    {1, CFSTR("ITU_R_2020")}
};

static const revenant_code_name revenant_matrix_names[] = {
    {1, CFSTR("ITU_R_709_2")}, {6, CFSTR("ITU_R_601_4")}, {7, CFSTR("SMPTE_240M_1995")}, {9, CFSTR("ITU_R_2020")}
};

typedef struct {
    const revenant_code_name *names;
    size_t count;
    const revenant_code_name *strings;
    size_t string_count;
    const char *prefix;
    CFStringRef prefix_string;
    CFMutableDictionaryRef unrecognized;
} revenant_code_table;

static revenant_code_table revenant_primaries = {revenant_primaries_names, sizeof revenant_primaries_names / sizeof *revenant_primaries_names, revenant_primaries_names, sizeof revenant_primaries_names / sizeof *revenant_primaries_names, "ColorPrimaries", CFSTR("ColorPrimaries#"), NULL};
static revenant_code_table revenant_transfer = {revenant_transfer_names, sizeof revenant_transfer_names / sizeof *revenant_transfer_names, revenant_transfer_strings, sizeof revenant_transfer_strings / sizeof *revenant_transfer_strings, "TransferFunction", CFSTR("TransferFunction#"), NULL};
static revenant_code_table revenant_matrix = {revenant_matrix_names, sizeof revenant_matrix_names / sizeof *revenant_matrix_names, revenant_matrix_names, sizeof revenant_matrix_names / sizeof *revenant_matrix_names, "YCbCrMatrix", CFSTR("YCbCrMatrix#"), NULL};

static pthread_mutex_t revenant_unrecognized_lock = PTHREAD_MUTEX_INITIALIZER;

static CFStringRef revenant_unrecognized_string(revenant_code_table *table, int code)
{
    pthread_mutex_lock(&revenant_unrecognized_lock);
    if (!table->unrecognized)
        table->unrecognized = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    const void *key = (const void *)(intptr_t)code;
    CFStringRef string = table->unrecognized ? CFDictionaryGetValue(table->unrecognized, key) : NULL;
    if (!string && table->unrecognized) {
        string = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%s#%d"), table->prefix, code);
        if (string) {
            CFDictionarySetValue(table->unrecognized, key, string);
            CFRelease(string);
        }
    }
    pthread_mutex_unlock(&revenant_unrecognized_lock);
    return string;
}

static CFStringRef revenant_string_for_code(revenant_code_table *table, int code)
{
    if (code == 0 || code == 2)
        return NULL;
    for (size_t index = 0; index < table->count; index++)
        if (table->names[index].code == code)
            return table->names[index].name;
    return revenant_unrecognized_string(table, code);
}

static int revenant_code_for_string(revenant_code_table *table, CFStringRef string)
{
    if (!string || CFGetTypeID(string) != CFStringGetTypeID())
        return 2;
    for (size_t index = 0; index < table->string_count; index++)
        if (CFEqual(string, table->strings[index].name))
            return table->strings[index].code;
    if (!CFStringHasPrefix(string, table->prefix_string))
        return 2;
    CFIndex prefix = CFStringGetLength(table->prefix_string);
    CFStringRef digits = CFStringCreateWithSubstring(kCFAllocatorDefault, string, CFRangeMake(prefix, CFStringGetLength(string) - prefix));
    if (!digits)
        return 2;
    int code = CFStringGetIntValue(digits);
    CFRelease(digits);
    return code;
}

CFStringRef CVColorPrimariesGetStringForIntegerCodePoint(int codePoint)
{
    return revenant_string_for_code(&revenant_primaries, codePoint);
}

int CVColorPrimariesGetIntegerCodePointForString(CFStringRef colorPrimariesString)
{
    return revenant_code_for_string(&revenant_primaries, colorPrimariesString);
}

CFStringRef CVTransferFunctionGetStringForIntegerCodePoint(int codePoint)
{
    return revenant_string_for_code(&revenant_transfer, codePoint);
}

int CVTransferFunctionGetIntegerCodePointForString(CFStringRef transferFunctionString)
{
    return revenant_code_for_string(&revenant_transfer, transferFunctionString);
}

CFStringRef CVYCbCrMatrixGetStringForIntegerCodePoint(int codePoint)
{
    return revenant_string_for_code(&revenant_matrix, codePoint);
}

int CVYCbCrMatrixGetIntegerCodePointForString(CFStringRef yCbCrMatrixString)
{
    return revenant_code_for_string(&revenant_matrix, yCbCrMatrixString);
}
