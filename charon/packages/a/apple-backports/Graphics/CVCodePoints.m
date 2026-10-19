#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <pthread.h>

typedef struct {
    int code;
    CFStringRef name;
} charon_code_name;

static const charon_code_name charon_primaries_names[] = {
    {1, CFSTR("ITU_R_709_2")}, {5, CFSTR("EBU_3213")}, {6, CFSTR("SMPTE_C")}, {9, CFSTR("ITU_R_2020")},
    {11, CFSTR("DCI_P3")}, {12, CFSTR("P3_D65")}, {22, CFSTR("P22")}
};

static const charon_code_name charon_transfer_names[] = {
    {1, CFSTR("ITU_R_709_2")}, {6, CFSTR("ITU_R_709_2")}, {14, CFSTR("ITU_R_709_2")}, {15, CFSTR("ITU_R_709_2")},
    {7, CFSTR("SMPTE_240M_1995")}, {8, CFSTR("Linear")}, {13, CFSTR("IEC_sRGB")}, {16, CFSTR("SMPTE_ST_2084_PQ")},
    {17, CFSTR("SMPTE_ST_428_1")}, {18, CFSTR("ITU_R_2100_HLG")}
};

static const charon_code_name charon_transfer_strings[] = {
    {1, CFSTR("ITU_R_709_2")}, {2, CFSTR("UseGamma")}, {7, CFSTR("SMPTE_240M_1995")}, {16, CFSTR("SMPTE_ST_2084_PQ")},
    {17, CFSTR("SMPTE_ST_428_1")}, {18, CFSTR("ITU_R_2100_HLG")}, {8, CFSTR("Linear")}, {13, CFSTR("IEC_sRGB")},
    {1, CFSTR("ITU_R_2020")}
};

static const charon_code_name charon_matrix_names[] = {
    {1, CFSTR("ITU_R_709_2")}, {6, CFSTR("ITU_R_601_4")}, {7, CFSTR("SMPTE_240M_1995")}, {9, CFSTR("ITU_R_2020")}
};

typedef struct {
    const charon_code_name *names;
    size_t count;
    const charon_code_name *strings;
    size_t string_count;
    const char *prefix;
    CFStringRef prefix_string;
    CFMutableDictionaryRef unrecognized;
} charon_code_table;

static charon_code_table charon_primaries = {charon_primaries_names, sizeof charon_primaries_names / sizeof *charon_primaries_names, charon_primaries_names, sizeof charon_primaries_names / sizeof *charon_primaries_names, "ColorPrimaries", CFSTR("ColorPrimaries#"), NULL};
static charon_code_table charon_transfer = {charon_transfer_names, sizeof charon_transfer_names / sizeof *charon_transfer_names, charon_transfer_strings, sizeof charon_transfer_strings / sizeof *charon_transfer_strings, "TransferFunction", CFSTR("TransferFunction#"), NULL};
static charon_code_table charon_matrix = {charon_matrix_names, sizeof charon_matrix_names / sizeof *charon_matrix_names, charon_matrix_names, sizeof charon_matrix_names / sizeof *charon_matrix_names, "YCbCrMatrix", CFSTR("YCbCrMatrix#"), NULL};

static pthread_mutex_t charon_unrecognized_lock = PTHREAD_MUTEX_INITIALIZER;

static CFStringRef charon_unrecognized_string(charon_code_table *table, int code)
{
    pthread_mutex_lock(&charon_unrecognized_lock);
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
    pthread_mutex_unlock(&charon_unrecognized_lock);
    return string;
}

static CFStringRef charon_string_for_code(charon_code_table *table, int code)
{
    if (code == 0 || code == 2)
        return NULL;
    for (size_t index = 0; index < table->count; index++)
        if (table->names[index].code == code)
            return table->names[index].name;
    return charon_unrecognized_string(table, code);
}

static int charon_code_for_string(charon_code_table *table, CFStringRef string)
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
    return charon_string_for_code(&charon_primaries, codePoint);
}

int CVColorPrimariesGetIntegerCodePointForString(CFStringRef colorPrimariesString)
{
    return charon_code_for_string(&charon_primaries, colorPrimariesString);
}

CFStringRef CVTransferFunctionGetStringForIntegerCodePoint(int codePoint)
{
    return charon_string_for_code(&charon_transfer, codePoint);
}

int CVTransferFunctionGetIntegerCodePointForString(CFStringRef transferFunctionString)
{
    return charon_code_for_string(&charon_transfer, transferFunctionString);
}

CFStringRef CVYCbCrMatrixGetStringForIntegerCodePoint(int codePoint)
{
    return charon_string_for_code(&charon_matrix, codePoint);
}

int CVYCbCrMatrixGetIntegerCodePointForString(CFStringRef yCbCrMatrixString)
{
    return charon_code_for_string(&charon_matrix, yCbCrMatrixString);
}
