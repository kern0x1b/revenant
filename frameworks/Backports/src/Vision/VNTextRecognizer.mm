#import "VNTextRecognizer.h"
#import "VNGrayscale.h"
#import "VNTextRecognizerCore.hpp"

static NSError *revenant_text_error(NSString *description)
{
    return [NSError errorWithDomain:@"RevenantVisionText" code:1 userInfo:@{NSLocalizedDescriptionKey: description}];
}

static CGRect revenant_text_normalized(int left, int top, int right, int bottom, size_t wide, size_t high)
{
    return CGRectMake((CGFloat)left / wide, 1.0 - (CGFloat)bottom / high, (CGFloat)(right - left) / wide, (CGFloat)(bottom - top) / high);
}

static BOOL revenant_text_ideograph(unichar character)
{
    return (character >= 0x3040 && character <= 0x30FF) || (character >= 0x3400 && character <= 0x9FFF) || (character >= 0xF900 && character <= 0xFAFF);
}

static NSString *revenant_text_joined(NSString *text)
{
    NSMutableString *joined = [NSMutableString stringWithCapacity:text.length];
    for (NSUInteger index = 0; index < text.length; ++index) {
        unichar character = [text characterAtIndex:index];
        if (character == ' ' && index > 0 && index + 1 < text.length && revenant_text_ideograph([text characterAtIndex:index - 1])
            && revenant_text_ideograph([text characterAtIndex:index + 1]))
            continue;
        [joined appendFormat:@"%C", character];
    }
    return joined;
}

static NSDictionary *revenant_text_models(void)
{
    static NSDictionary *models;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        models = @{@"en-US": @"eng", @"fr-FR": @"fra", @"it-IT": @"ita", @"de-DE": @"deu", @"es-ES": @"spa", @"pt-BR": @"por",
                   @"zh-Hans": @"chi_sim", @"zh-Hant": @"chi_tra", @"yue-Hans": @"chi_sim", @"yue-Hant": @"chi_tra",
                   @"ko-KR": @"kor", @"ja-JP": @"jpn", @"ru-RU": @"rus", @"uk-UA": @"ukr", @"th-TH": @"tha", @"vi-VT": @"vie",
                   @"ar-SA": @"ara", @"ars-SA": @"ara", @"tr-TR": @"tur", @"id-ID": @"ind", @"cs-CZ": @"ces", @"da-DK": @"dan",
                   @"nl-NL": @"nld", @"no-NO": @"nor", @"nn-NO": @"nor", @"nb-NO": @"nor", @"ms-MY": @"msa", @"pl-PL": @"pol",
                   @"ro-RO": @"ron", @"sv-SE": @"swe", @"fi-FI": @"fin", @"hi-IN": @"hin", @"mr-IN": @"mar"};
    });
    return models;
}

static NSArray *revenant_text_candidates(NSUInteger revision, BOOL fast)
{
    static NSArray *fastSix;
    static NSArray *accurateRevisionTwo;
    static NSArray *accurateRevisionThree;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fastSix = @[@"en-US", @"fr-FR", @"it-IT", @"de-DE", @"es-ES", @"pt-BR"];
        accurateRevisionTwo = @[@"en-US", @"fr-FR", @"it-IT", @"de-DE", @"es-ES", @"pt-BR", @"zh-Hans", @"zh-Hant"];
        accurateRevisionThree = @[@"en-US", @"fr-FR", @"it-IT", @"de-DE", @"es-ES", @"pt-BR", @"zh-Hans", @"zh-Hant",
                                  @"yue-Hans", @"yue-Hant", @"ko-KR", @"ja-JP", @"ru-RU", @"uk-UA", @"th-TH", @"vi-VT",
                                  @"ar-SA", @"ars-SA", @"tr-TR", @"id-ID", @"cs-CZ", @"da-DK", @"nl-NL", @"no-NO", @"nn-NO",
                                  @"nb-NO", @"ms-MY", @"pl-PL", @"ro-RO", @"sv-SE", @"fi-FI", @"hi-IN", @"mr-IN"];
    });
    if (revision <= 1)
        return @[@"en-US"];
    if (fast)
        return fastSix;
    return revision == 2 ? accurateRevisionTwo : accurateRevisionThree;
}

static NSString *revenant_text_folder(NSString *root, BOOL fast)
{
    return [root stringByAppendingPathComponent:fast ? @"fast" : @"best"];
}

static BOOL revenant_text_installed(NSString *root, NSString *language, BOOL fast)
{
    NSString *code = revenant_text_models()[language];
    if (code == nil)
        return NO;
    NSString *file = [[revenant_text_folder(root, fast) stringByAppendingPathComponent:code] stringByAppendingPathExtension:@"traineddata"];
    return [[NSFileManager defaultManager] fileExistsAtPath:file];
}

NSString *RevenantVisionTextModelRoot(void)
{
    return @"/usr/share/revenant/tessdata";
}

NSArray *RevenantVisionTextLanguages(NSString *root, NSUInteger revision, BOOL fast)
{
    NSMutableArray *installed = [NSMutableArray array];
    for (NSString *language in revenant_text_candidates(revision, fast)) {
        if (revenant_text_installed(root, language, fast))
            [installed addObject:language];
    }
    return installed;
}

static NSString *revenant_text_language(NSArray *languages, NSString *root, NSUInteger revision, BOOL fast, NSError **error)
{
    NSMutableOrderedSet *codes = [NSMutableOrderedSet orderedSet];
    if (languages.count == 0)
        languages = @[@"en-US"];
    for (NSString *language in languages) {
        if (![revenant_text_candidates(revision, fast) containsObject:language]) {
            if (error)
                *error = revenant_text_error([NSString stringWithFormat:@"the recognition language %@ is not supported at this recognition level and revision", language]);
            return nil;
        }
        if (!revenant_text_installed(root, language, fast)) {
            if (error)
                *error = revenant_text_error([NSString stringWithFormat:@"the recognition language %@ is not installed on this device", language]);
            return nil;
        }
        [codes addObject:revenant_text_models()[language]];
    }
    return [[codes array] componentsJoinedByString:@"+"];
}

static NSString *revenant_text_words_file(NSArray *words, NSError **error)
{
    NSString *joined = [words componentsJoinedByString:@"\n"];
    uint64_t hash = 14695981039346656037ULL;
    for (NSUInteger index = 0; index < joined.length; ++index) {
        hash ^= [joined characterAtIndex:index];
        hash *= 1099511628211ULL;
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"revenant-words-%016llx.txt", hash]];
    if (![joined writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error])
        return nil;
    return path;
}

static BOOL revenant_text_region(NSValue *region, size_t wide, size_t high, RevenantTextRequest& request, NSError **error)
{
    CGRect normalized = region ? RevenantVisionRectFromValue(region) : CGRectMake(0, 0, 1, 1);
    CGFloat minX = MAX(0.0, MIN(1.0, CGRectGetMinX(normalized)));
    CGFloat maxX = MAX(0.0, MIN(1.0, CGRectGetMaxX(normalized)));
    CGFloat minY = MAX(0.0, MIN(1.0, CGRectGetMinY(normalized)));
    CGFloat maxY = MAX(0.0, MIN(1.0, CGRectGetMaxY(normalized)));
    int left = (int)floor(minX * wide);
    int right = (int)ceil(maxX * wide);
    int top = (int)floor((1.0 - maxY) * high);
    int bottom = (int)ceil((1.0 - minY) * high);
    if (right <= left || bottom <= top) {
        if (error)
            *error = revenant_text_error(@"the region of interest is empty");
        return NO;
    }
    request.regionLeft = left;
    request.regionTop = top;
    request.regionWidth = right - left;
    request.regionHeight = bottom - top;
    return YES;
}

static NSArray *revenant_text_lines(id image, CGImagePropertyOrientation orientation, NSDictionary *options, NSError **error)
{
    size_t wide = 0;
    size_t high = 0;
    NSData *gray = RevenantVisionGrayscale(image, orientation, &wide, &high, error);
    if (gray == nil)
        return nil;
    BOOL fast = [options[@"fast"] boolValue];
    NSUInteger revision = [options[@"revision"] unsignedIntegerValue];
    NSString *root = options[@"tessdata"];
    if (root.length == 0) {
        if (error)
            *error = revenant_text_error(@"the recognition models are not installed");
        return nil;
    }
    NSString *language = revenant_text_language(options[@"languages"] ?: @[], root, revision, fast, error);
    if (language == nil)
        return nil;
    NSString *words = nil;
    if ([options[@"customWords"] count] > 0) {
        words = revenant_text_words_file(options[@"customWords"], error);
        if (words == nil)
            return nil;
    }
    RevenantTextRequest request{};
    request.datapath = revenant_text_folder(root, fast).UTF8String;
    request.language = language.UTF8String;
    request.userWordsFile = words ? words.UTF8String : "";
    request.correction = [options[@"correction"] boolValue];
    if (!revenant_text_region(options[@"regionOfInterest"], wide, high, request, error))
        return nil;
    std::vector<RevenantTextLine> lines;
    std::string failure;
    if (!RevenantTextRecognize((const uint8_t *)gray.bytes, (int)wide, (int)high, request, lines, failure)) {
        if (error)
            *error = revenant_text_error([NSString stringWithUTF8String:failure.c_str()]);
        return nil;
    }
    double minimumHeight = [options[@"minimumTextHeight"] doubleValue];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:lines.size()];
    for (const RevenantTextLine& line : lines) {
        CGRect bounds = revenant_text_normalized(line.left, line.top, line.right, line.bottom, wide, high);
        if (bounds.size.height < minimumHeight)
            continue;
        NSString *string = revenant_text_joined([NSString stringWithUTF8String:line.text.c_str()]);
        NSMutableArray *wordResults = [NSMutableArray arrayWithCapacity:line.words.size()];
        NSUInteger cursor = 0;
        for (const RevenantTextWord& word : line.words) {
            NSString *text = [NSString stringWithUTF8String:word.text.c_str()];
            NSRange found = [string rangeOfString:text options:NSLiteralSearch range:NSMakeRange(cursor, string.length - cursor)];
            if (found.location == NSNotFound)
                continue;
            cursor = NSMaxRange(found);
            CGRect wordBounds = revenant_text_normalized(word.left, word.top, word.right, word.bottom, wide, high);
            [wordResults addObject:@{@"range": [NSValue valueWithRange:found], @"bounds": RevenantVisionRectValue(wordBounds)}];
        }
        [results addObject:@{@"string": string,
                             @"confidence": @(line.confidence),
                             @"bounds": RevenantVisionRectValue(bounds),
                             @"words": wordResults}];
    }
    return results;
}

NSArray *RevenantVisionTextLines(id image, CGImagePropertyOrientation orientation, NSDictionary *options, NSError **error)
{
    NSError *failure = nil;
    NSArray *lines;
    @autoreleasepool {
        lines = revenant_text_lines(image, orientation, options, &failure);
    }
    if (error)
        *error = failure;
    return lines;
}
