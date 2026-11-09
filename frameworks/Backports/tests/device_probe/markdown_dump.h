#import <Foundation/Foundation.h>

static NSString *revenant_intent(NSPresentationIntent *intent)
{
    NSMutableArray *chain = [NSMutableArray array];
    for (NSPresentationIntent *step = intent; step; step = step.parentIntent) {
        NSMutableString *line = [NSMutableString stringWithFormat:@"%ld#%ld", (long)step.intentKind, (long)step.identity];
        switch (step.intentKind) {
        case NSPresentationIntentKindHeader:
            [line appendFormat:@" level=%ld", (long)step.headerLevel];
            break;
        case NSPresentationIntentKindListItem:
            [line appendFormat:@" ordinal=%ld", (long)step.ordinal];
            break;
        case NSPresentationIntentKindCodeBlock:
            [line appendFormat:@" hint=%@", step.languageHint ?: @"nil"];
            break;
        case NSPresentationIntentKindTable:
            [line appendFormat:@" columns=%ld alignments=%@", (long)step.columnCount, [step.columnAlignments componentsJoinedByString:@","]];
            break;
        case NSPresentationIntentKindTableRow:
            [line appendFormat:@" row=%ld", (long)step.row];
            break;
        case NSPresentationIntentKindTableCell:
            [line appendFormat:@" column=%ld", (long)step.column];
            break;
        default:
            break;
        }
        [chain addObject:line];
    }
    return [chain componentsJoinedByString:@" <- "];
}

static NSString *revenant_value(id value)
{
    if ([value isKindOfClass:[NSPresentationIntent class]]) {
        return [NSString stringWithFormat:@"intent(%@)", revenant_intent(value)];
    }
    if ([value isKindOfClass:[NSURL class]]) {
        return [NSString stringWithFormat:@"url(%@)", [value absoluteString]];
    }
    return [NSString stringWithFormat:@"%@", value];
}

static NSString *revenant_dump(NSAttributedString *text)
{
    NSMutableString *out = [NSMutableString stringWithFormat:@"length=%lu\n", (unsigned long)text.length];
    [text enumerateAttributesInRange:NSMakeRange(0, text.length) options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *key in [attributes.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [items addObject:[NSString stringWithFormat:@"%@=%@", key, revenant_value(attributes[key])]];
        }
        NSString *piece = [text.string substringWithRange:range];
        piece = [piece stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        piece = [piece stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        piece = [piece stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
        piece = [piece stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
        [out appendFormat:@"  %lu,%lu %@ {%@}\n", (unsigned long)range.location, (unsigned long)range.length, piece, [items componentsJoinedByString:@"; "]];
    }];
    return out;
}

static NSString *revenant_decode(NSString *line)
{
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < line.length; i++) {
        unichar c = [line characterAtIndex:i];
        if (c != '\\' || i + 1 >= line.length) {
            [out appendFormat:@"%C", c];
            continue;
        }
        unichar next = [line characterAtIndex:++i];
        if (next == 'n')
            [out appendString:@"\n"];
        else if (next == 'r')
            [out appendString:@"\r"];
        else if (next == 't')
            [out appendString:@"\t"];
        else if (next == 'z')
            continue;
        else if (next == 'u' && i + 4 < line.length) {
            unsigned value = 0;
            [[NSScanner scannerWithString:[line substringWithRange:NSMakeRange(i + 1, 4)]] scanHexInt:&value];
            [out appendFormat:@"%C", (unichar)value];
            i += 4;
        } else
            [out appendFormat:@"%C", next];
    }
    return out;
}

static NSArray *revenant_corpus(NSString *path)
{
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    NSMutableArray *entries = [NSMutableArray array];
    NSUInteger length = text.length, start = 0;
    while (start < length) {
        NSRange found = [text rangeOfString:@"\n" options:NSLiteralSearch range:NSMakeRange(start, length - start)];
        NSUInteger end = found.location == NSNotFound ? length : found.location;
        if (end > start)
            [entries addObject:revenant_decode([text substringWithRange:NSMakeRange(start, end - start)])];
        start = end + 1;
    }
    return entries;
}

static NSArray *revenant_syntax_names(void)
{
    return @[@"full", @"inline", @"inlinePreserving"];
}
