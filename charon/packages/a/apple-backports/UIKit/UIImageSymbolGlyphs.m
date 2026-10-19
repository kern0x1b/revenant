#import "CharonSymbols.h"
#import "CharonSymbolMetrics.h"
#import "CharonSymbolGlyphs.h"
#include <math.h>

// A glyph is a script over a box of 100 by 100 units, y down: m l c q z o r a A * G build a path, S F B X Y end it, d and h draw a dot and an arrowhead, H an arc with
// one, g draws another glyph into a rectangle, K and k switch to clearing, w scales the line, !f fills what is closed.

typedef struct {
    CGContextRef context;
    CGAffineTransform map;
    CGFloat line;
    BOOL fill;
    BOOL clear;
    int depth;
    CGRect *bounds;
} CharonScene;

static NSArray<NSString *> *charon_tokens(NSString *script)
{
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSMutableDictionary alloc] init];
    });
    @synchronized (cache) {
        NSArray *tokens = cache[script];
        if (!tokens) {
            tokens = [script componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            tokens = [tokens filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
            cache[script] = tokens;
        }
        return tokens;
    }
}

NSString *charon_glyph_script(NSString *name);


static NSDictionary<NSString *, NSString *> *charon_glyph_table(void)
{
    static NSDictionary *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary *built = [NSMutableDictionary dictionary];
        for (size_t i = 0; i < sizeof CharonGlyphs / sizeof CharonGlyphs[0]; i++)
            built[@(CharonGlyphs[i].name)] = @(CharonGlyphs[i].script);
        table = built;
    });
    return table;
}

// Where a glyph sits inside an enclosure, as x, y, width, height of the 100 by 100 box.
static NSString *charon_core_box(NSString *core)
{
    static NSDictionary *boxes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        boxes = @{@"questionmark": @"36 22 28 56", @"exclamationmark": @"42 22 16 56", @"info": @"42 22 16 56", @"plus": @"26 26 48 48", @"minus": @"24 24 52 52",
                  @"checkmark": @"24 28 52 44", @"xmark": @"28 28 44 44", @"dollarsign": @"32 22 36 56", @"waveform": @"22 26 56 48", @"infinity": @"18 32 64 36",
                  @"chevron.up": @"30 34 40 28", @"chevron.down": @"30 38 40 28", @"chevron.left": @"38 30 28 40", @"chevron.right": @"34 30 28 40",
                  @"line.3.horizontal.decrease": @"24 30 52 40", @"line.horizontal.3.decrease": @"24 30 52 40", @"viewfinder": @"24 24 52 52", @"stop": @"32 32 36 36",
                  @"play": @"34 28 40 44", @"pause": @"32 28 36 44", @"playpause": @"24 30 52 40", @"number": @"32 26 36 48", @"star": @"24 22 52 52", @"triangle": @"26 24 48 44",
                  @"pencil": @"26 26 48 48", @"magnifyingglass": @"24 24 52 52", @"arrow.up": @"30 24 40 52", @"arrow.down": @"30 24 40 52", @"arrow.left": @"24 30 52 40", @"arrow.right": @"24 30 52 40"};
    });
    return boxes[core] ?: @"26 26 48 48";
}

static NSString *charon_badge_core(NSString *kind)
{
    static NSDictionary *cores;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cores = @{@"plus": @"plus", @"minus": @"minus", @"person.crop": @"person", @"checkmark": @"checkmark", @"clock": @"clock", @"gearshape": @"gearshape", @"gear": @"gearshape",
                  @"key": @"key", @"eye": @"eye", @"play": @"play", @"exclamationmark": @"exclamationmark", @"shield.half.filled": @"shield", @"fill": @""};
    });
    return cores[kind];
}

NSString *charon_glyph_script(NSString *name)
{
    NSString *exact = charon_glyph_table()[name];
    if (exact)
        return exact;
    NSArray<NSString *> *parts = [name componentsSeparatedByString:@"."];
    NSUInteger count = parts.count;
    if (count < 2)
        return nil;
    NSString *last = parts.lastObject;
    NSString *afterLast = count > 2 ? parts[count - 2] : nil;

    // gauge.with.dots.needle.NNpercent and gauge.with.dots.needle.bottom.NNpercent
    if ([name hasPrefix:@"gauge.with.dots.needle."] && [last hasSuffix:@"percent"]) {
        double percent = [last doubleValue];
        BOOL bottom = [afterLast isEqualToString:@"bottom"];
        double pivotY = bottom ? 58 : 50, angle = (135 + 270 * percent / 100) * M_PI / 180;
        NSMutableString *ticks = [NSMutableString string];
        for (int i = 0; i <= 8; i++) {
            double a = (135 + 270 * i / 8.0) * M_PI / 180;
            [ticks appendFormat:@"d %.1f %.1f ", 50 + 33 * cos(a), pivotY + 33 * sin(a)];
        }
        return [NSString stringWithFormat:@"o 50 50 48 48 S %@w 1.4 m 50 %.1f l %.1f %.1f S d 50 %.1f", ticks, pivotY, 50 + 24 * cos(angle), pivotY + 24 * sin(angle), pivotY];
    }
    // (square|rectangle).split.AxB and square.grid.AxB, filled or not
    BOOL filled = [last isEqualToString:@"fill"];
    NSArray *shape = [(filled ? [name substringToIndex:name.length - 5] : name) componentsSeparatedByString:@"."];
    if (shape.count == 3 && ([shape[0] isEqualToString:@"square"] || [shape[0] isEqualToString:@"rectangle"]) && ([shape[1] isEqualToString:@"split"] || [shape[1] isEqualToString:@"grid"])) {
        NSArray *cells = [shape[2] componentsSeparatedByString:@"x"];
        if (cells.count == 2) {
            int columns = [cells[0] intValue], rows = [cells[1] intValue];
            if (columns < 1 || rows < 1 || columns > 6 || rows > 6)
                return nil;
            NSMutableString *script = [NSMutableString string];
            if ([shape[1] isEqualToString:@"split"]) {
                [script appendString:@"r 2 4 96 92 14 S "];
                for (int c = 1; c < columns; c++)
                    [script appendFormat:@"m %.1f 4 l %.1f 96 ", 2 + 96.0 * c / columns, 2 + 96.0 * c / columns];
                for (int r = 1; r < rows; r++)
                    [script appendFormat:@"m 2 %.1f l 98 %.1f ", 4 + 92.0 * r / rows, 4 + 92.0 * r / rows];
                [script appendString:@"S"];
            } else {
                double gap = 12, width = (100 - gap * (columns - 1)) / columns, height = (100 - gap * (rows - 1)) / rows;
                for (int r = 0; r < rows; r++)
                    for (int c = 0; c < columns; c++)
                        [script appendFormat:@"r %.1f %.1f %.1f %.1f %d %@ ", c * (width + gap), r * (height + gap), width, height, filled ? 3 : 9, filled ? @"F" : @"S"];
            }
            return script;
        }
    }
    // enclosures
    static NSArray *enclosures;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enclosures = @[@"circle", @"square", @"rectangle", @"diamond"];
    });
    for (NSString *shapeName in enclosures) {
        BOOL enclosed = (count > 2 && [last isEqualToString:@"fill"] && [afterLast isEqualToString:shapeName]) || [last isEqualToString:shapeName];
        if (!enclosed)
            continue;
        BOOL solid = [last isEqualToString:@"fill"];
        NSUInteger drop = solid ? 2 : 1;
        NSString *core = [[parts subarrayWithRange:NSMakeRange(0, count - drop)] componentsJoinedByString:@"."];
        if (!core.length || !charon_glyph_script(core))
            continue;
        NSString *outline = [shapeName isEqualToString:@"circle"] ? @"o 50 50 50 50" : [shapeName isEqualToString:@"square"] ? @"r 0 0 100 100 24" : [shapeName isEqualToString:@"rectangle"] ? @"r 0 6 100 88 18" : @"m 50 0 l 100 50 l 50 100 l 0 50 z";
        NSString *box = charon_core_box(core);
        if (solid)
            return [NSString stringWithFormat:@"%@ B K g %@ %@ 0", outline, core, box];
        return [NSString stringWithFormat:@"%@ S g %@ %@ 0", outline, core, box];
    }
    // slashes
    if ([last isEqualToString:@"slash"] || ([last isEqualToString:@"fill"] && [afterLast isEqualToString:@"slash"])) {
        BOOL solid = [last isEqualToString:@"fill"];
        NSString *base = [[parts subarrayWithRange:NSMakeRange(0, count - (solid ? 2 : 1))] componentsJoinedByString:@"."];
        if (charon_glyph_script(base))
            return [NSString stringWithFormat:@"%@g %@ 0 0 100 100 0 K w 2.6 m 6 6 l 94 94 S k w 1 m 6 6 l 94 94 S", solid ? @"!f " : @"", base];
    }
    // badges: BASE.badge.KIND and BASE.trianglebadge.exclamationmark
    for (NSUInteger i = 1; i + 1 < count; i++) {
        BOOL triangle = [parts[i] hasSuffix:@"trianglebadge"] && ![parts[i] isEqualToString:@"badge"];
        if (![parts[i] isEqualToString:@"badge"] && !triangle)
            continue;
        NSString *base = [[parts subarrayWithRange:NSMakeRange(0, i)] componentsJoinedByString:@"."];
        NSString *kind = [[parts subarrayWithRange:NSMakeRange(i + 1, count - i - 1)] componentsJoinedByString:@"."];
        if ([kind hasSuffix:@".fill"] && ![kind isEqualToString:@"fill"])
            kind = [kind substringToIndex:kind.length - 5];
        NSString *core = charon_badge_core(kind);
        if (triangle && [kind isEqualToString:@"exclamationmark"]) {
            NSString *baseScript = charon_glyph_script(base) ? base : nil;
            if (!baseScript)
                return nil;
            return [NSString stringWithFormat:@"g %@ 0 0 100 92 0 K m 76 44 l 100 96 l 52 96 z Y k m 76 46 l 96 92 l 56 92 z B K m 76 60 l 76 72 S d 76 82 k", baseScript];
        }
        if (!core || !charon_glyph_script(base) || (core.length && !charon_glyph_script(core)))
            continue;
        NSString *first = parts[0];
        double x = 76, y = 76;
        if ([first isEqualToString:@"folder"])
            y = 24;
        else if ([@[@"doc", @"macwindow", @"externaldrive", @"keyboard", @"rectangle"] containsObject:first])
            x = 24;
        else if ([first isEqualToString:@"text"])
            x = y = 24;
        NSString *inner = core.length ? [NSString stringWithFormat:@"K g %@ %.1f %.1f 24 24 0 k", core, x - 12, y - 12] : @"";
        return [NSString stringWithFormat:@"g %@ 0 0 100 100 0 K o %.1f %.1f 27 27 Y k o %.1f %.1f 19 19 B %@", base, x, y, x, y, inner];
    }
    // the filled form of a glyph
    if ([last isEqualToString:@"fill"]) {
        NSString *base = [name substringToIndex:name.length - 5];
        if (charon_glyph_script(base))
            return [NSString stringWithFormat:@"!f g %@ 0 0 100 100 0", base];
    }
    return nil;
}

static void charon_arc(CGMutablePathRef path, const CGAffineTransform *map, double cx, double cy, double r, double from, double to, BOOL connect)
{
    double span = to - from;
    int pieces = (int)ceil(fabs(span) / 90);
    if (pieces < 1)
        pieces = 1;
    double step = span / pieces * M_PI / 180;
    double angle = from * M_PI / 180;
    double k = 4.0 / 3.0 * tan(step / 4);
    CGPoint start = CGPointMake(cx + r * cos(angle), cy + r * sin(angle));
    if (connect)
        CGPathAddLineToPoint(path, map, start.x, start.y);
    else
        CGPathMoveToPoint(path, map, start.x, start.y);
    for (int piece = 0; piece < pieces; piece++) {
        double a0 = angle + piece * step, a1 = a0 + step;
        CGPathAddCurveToPoint(path, map, cx + r * (cos(a0) - k * sin(a0)), cy + r * (sin(a0) + k * cos(a0)), cx + r * (cos(a1) + k * sin(a1)), cy + r * (sin(a1) - k * cos(a1)),
                              cx + r * cos(a1), cy + r * sin(a1));
    }
}

static void charon_head(CGMutablePathRef path, const CGAffineTransform *map, double x, double y, double degrees, double length)
{
    double angle = degrees * M_PI / 180, spread = 40 * M_PI / 180;
    CGPathMoveToPoint(path, map, x + length * cos(angle + M_PI - spread), y + length * sin(angle + M_PI - spread));
    CGPathAddLineToPoint(path, map, x, y);
    CGPathAddLineToPoint(path, map, x + length * cos(angle + M_PI + spread), y + length * sin(angle + M_PI + spread));
}

static void charon_run(NSString *script, CharonScene scene);

static void charon_draw_path(CharonScene *scene, CGMutablePathRef path, unichar style, BOOL open, CGFloat multiplier, const CGFloat *dash)
{
    if (scene->bounds) {
        if (!scene->clear && style != 'X' && style != 'Y')
            *scene->bounds = CGRectUnion(*scene->bounds, CGPathGetPathBoundingBox(path));
        return;
    }
    CGContextRef context = scene->context;
    CGContextSaveGState(context);
    CGContextSetBlendMode(context, scene->clear ? kCGBlendModeClear : kCGBlendModeNormal);
    CGContextSetGrayFillColor(context, 0, 1);
    CGContextSetGrayStrokeColor(context, 0, 1);
    CGContextSetLineWidth(context, scene->line * multiplier);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    if (dash)
        CGContextSetLineDash(context, 0, dash, 2);
    if (scene->fill && style == 'S' && !open)
        style = 'B';
    CGContextAddPath(context, path);
    switch (style) {
    case 'S':
    case 'X':
        CGContextStrokePath(context);
        break;
    case 'F':
    case 'Y':
        CGContextEOFillPath(context);
        break;
    default:
        CGContextDrawPath(context, kCGPathEOFillStroke);
    }
    CGContextRestoreGState(context);
}

static void charon_run(NSString *script, CharonScene scene)
{
    if (!script || scene.depth > 6)
        return;
    NSArray *tokens = charon_tokens(script);
    NSUInteger count = tokens.count, index = 0;
    CGMutablePathRef path = CGPathCreateMutable();
    CGAffineTransform map = scene.map;
    BOOL open = NO, hasPath = NO;
    CGFloat multiplier = 1, dashPattern[2] = {0, 0};
    BOOL dashed = NO;
    double v[8];
    while (index < count) {
        NSString *token = tokens[index++];
        unichar op = [token characterAtIndex:0];
        int arguments = 0;
        switch (op) {
        case 'm': case 'l': case 'd': case 'w': case 'u': arguments = (op == 'w') ? 1 : 2; break;
        case 'q': arguments = 4; break;
        case 'c': arguments = 6; break;
        case 'o': arguments = 4; break;
        case 'r': arguments = 5; break;
        case 'a': case 'A': arguments = 5; break;
        case 'H': arguments = 6; break;
        case 'h': arguments = 4; break;
        case '*': arguments = 5; break;
        case 'G': arguments = 4; break;
        default: arguments = 0;
        }
        if ([token isEqualToString:@"g"])
            arguments = 5;
        if ([token isEqualToString:@"!f"]) {
            scene.fill = YES;
            continue;
        }
        NSString *nameArgument = nil;
        if ([token isEqualToString:@"g"])
            nameArgument = tokens[index++];
        for (int i = 0; i < arguments && index < count; i++)
            v[i] = strtod([tokens[index++] UTF8String], NULL);
        if ([token isEqualToString:@"g"]) {
            CharonScene child = scene;
            child.depth++;
            CGRect rect = CGRectMake(v[0], v[1], v[2], v[3]);
            CGAffineTransform placed = CGAffineTransformTranslate(map, rect.origin.x, rect.origin.y);
            placed = CGAffineTransformScale(placed, rect.size.width / 100, rect.size.height / 100);
            if (v[4] != 0) {
                placed = CGAffineTransformTranslate(placed, 50, 50);
                placed = CGAffineTransformRotate(placed, v[4] * M_PI / 180);
                placed = CGAffineTransformTranslate(placed, -50, -50);
            }
            child.map = placed;
            child.line = scene.line * multiplier;
            charon_run(charon_glyph_script(nameArgument), child);
            continue;
        }
        switch (op) {
        case 'm': CGPathMoveToPoint(path, &map, v[0], v[1]); open = YES; hasPath = YES; break;
        case 'l': CGPathAddLineToPoint(path, &map, v[0], v[1]); break;
        case 'q': CGPathAddQuadCurveToPoint(path, &map, v[0], v[1], v[2], v[3]); break;
        case 'c': CGPathAddCurveToPoint(path, &map, v[0], v[1], v[2], v[3], v[4], v[5]); break;
        case 'z': CGPathCloseSubpath(path); open = NO; break;
        case 'o': CGPathAddEllipseInRect(path, &map, CGRectMake(v[0] - v[2], v[1] - v[3], 2 * v[2], 2 * v[3])); hasPath = YES; break;
        case 'r': CGPathAddRoundedRect(path, &map, CGRectMake(v[0], v[1], v[2], v[3]), v[4], v[4]); hasPath = YES; break;
        case 'a': charon_arc(path, &map, v[0], v[1], v[2], v[3], v[4], NO); open = YES; hasPath = YES; break;
        case 'A': charon_arc(path, &map, v[0], v[1], v[2], v[3], v[4], YES); break;
        case 'H': {
            charon_arc(path, &map, v[0], v[1], v[2], v[3], v[4], NO);
            double end = v[4] * M_PI / 180, direction = v[4] > v[3] ? 1 : -1;
            double x = v[0] + v[2] * cos(end), y = v[1] + v[2] * sin(end);
            double heading = v[4] + direction * 90;
            charon_head(path, &map, x, y, heading, v[5]);
            open = YES; hasPath = YES;
            break;
        }
        case 'h': charon_head(path, &map, v[0], v[1], v[2], v[3]); open = YES; hasPath = YES; break;
        case '*': {
            int points = (int)v[4];
            for (int i = 0; i < points * 2; i++) {
                double radius = (i % 2) ? v[3] : v[2], angle = (-90 + i * 180.0 / points) * M_PI / 180;
                double x = v[0] + radius * cos(angle), y = v[1] + radius * sin(angle);
                if (i == 0) CGPathMoveToPoint(path, &map, x, y); else CGPathAddLineToPoint(path, &map, x, y);
            }
            CGPathCloseSubpath(path);
            hasPath = YES;
            break;
        }
        case 'G': {
            int teeth = (int)v[3];
            double outer = v[2], inner = v[2] * 0.8, slice = 2 * M_PI / teeth;
            for (int i = 0; i < teeth; i++) {
                double base = i * slice - M_PI / 2;
                double angles[4] = {base - slice * 0.22, base - slice * 0.13, base + slice * 0.13, base + slice * 0.22};
                double radii[4] = {inner, outer, outer, inner};
                for (int j = 0; j < 4; j++) {
                    double x = v[0] + radii[j] * cos(angles[j]), y = v[1] + radii[j] * sin(angles[j]);
                    if (i == 0 && j == 0) CGPathMoveToPoint(path, &map, x, y); else CGPathAddLineToPoint(path, &map, x, y);
                }
            }
            CGPathCloseSubpath(path);
            CGPathAddEllipseInRect(path, &map, CGRectMake(v[0] - v[2] * 0.3, v[1] - v[2] * 0.3, v[2] * 0.6, v[2] * 0.6));
            hasPath = YES;
            break;
        }
        case 'd': {
            CGMutablePathRef dot = CGPathCreateMutable();
            double r = scene.line * multiplier * 0.62;
            CGPoint centre = CGPointApplyAffineTransform(CGPointMake(v[0], v[1]), map);
            if (scene.bounds && !scene.clear)
                *scene.bounds = CGRectUnion(*scene.bounds, CGRectMake(centre.x, centre.y, 0, 0));
            CGPathAddEllipseInRect(dot, NULL, CGRectMake(centre.x - r, centre.y - r, 2 * r, 2 * r));
            CharonScene flat = scene;
            charon_draw_path(&flat, dot, 'F', NO, 1, NULL);
            CGPathRelease(dot);
            break;
        }
        case 'w': multiplier = v[0]; break;
        case 'u': dashPattern[0] = v[0] * scene.line; dashPattern[1] = v[1] * scene.line; dashed = YES; break;
        case 'U': dashed = NO; break;
        case 'K': scene.clear = YES; break;
        case 'k': scene.clear = NO; break;
        case 'S': case 'F': case 'B': case 'X': case 'Y':
            if (hasPath) {
                if (op == 'X' || op == 'Y') {
                    CharonScene wiping = scene;
                    wiping.clear = YES;
                    charon_draw_path(&wiping, path, op, open, multiplier, dashed ? dashPattern : NULL);
                } else {
                    charon_draw_path(&scene, path, op, open, multiplier, dashed ? dashPattern : NULL);
                }
            }
            CGPathRelease(path);
            path = CGPathCreateMutable();
            open = NO;
            hasPath = NO;
            break;
        default:
            break;
        }
    }
    if (hasPath)
        charon_draw_path(&scene, path, 'S', open, multiplier, dashed ? dashPattern : NULL);
    CGPathRelease(path);
}

// The names are sorted, so a binary search finds one.
static NSInteger charon_symbol_index(NSString *name)
{
    if (![name isKindOfClass:[NSString class]] || !name.length)
        return -1;
    const char *needle = name.UTF8String;
    NSInteger low = 0, high = CHARON_SYMBOL_COUNT - 1;
    while (low <= high) {
        NSInteger middle = (low + high) / 2;
        int order = strcmp(needle, CharonSymbolNames[middle]);
        if (!order)
            return middle;
        if (order < 0)
            high = middle - 1;
        else
            low = middle + 1;
    }
    return -1;
}

static const double CharonLineWeights[10] = {0.09, 0.025, 0.04, 0.07, 0.09, 0.11, 0.13, 0.15, 0.185, 0.21};
static const int CharonWeightAnchors[4] = {1, 4, 7, 9};

static double charon_round_half(double value)
{
    return floor(value * 2 + 0.5) / 2;
}

// One value of the grid at a point size, weight and scale, interpolated between what was measured.
static double charon_grid_value(const int16_t *values, int stride, int offset, double pointSize, int weight, int scale)
{
    double at[2] = {0, 0};
    for (int size = 0; size < 2; size++) {
        int low = 0;
        while (low < 3 && CharonWeightAnchors[low + 1] <= weight)
            low++;
        int high = low < 3 && weight > CharonWeightAnchors[low] ? low + 1 : low;
        double a = values[((size * 4 + low) * 3 + (scale - 1)) * stride + offset] / 2.0;
        double b = values[((size * 4 + high) * 3 + (scale - 1)) * stride + offset] / 2.0;
        double fraction = high == low ? 0 : (CharonLineWeights[weight] - CharonLineWeights[CharonWeightAnchors[low]]) / (CharonLineWeights[CharonWeightAnchors[high]] - CharonLineWeights[CharonWeightAnchors[low]]);
        at[size] = a + (b - a) * fraction;
    }
    return charon_round_half(at[0] + (at[1] - at[0]) * (pointSize - 17) / 83);
}

BOOL charon_symbol_known(NSString *name)
{
    return charon_symbol_index(name) >= 0 && charon_glyph_script(name) != nil;
}

BOOL charon_symbol_metrics(NSString *name, double pointSize, NSInteger weight, NSInteger scale, CGSize *size, UIEdgeInsets *insets, CGFloat *baseline)
{
    NSInteger index = charon_symbol_index(name);
    if (index < 0)
        return NO;
    weight = weight >= 1 && weight <= 9 ? weight : 4;
    scale = scale >= 1 && scale <= 3 ? scale : 2;
    const int16_t *grid = CharonSymbolGrid[index];
    double width = charon_grid_value(grid, 3, 0, pointSize, (int)weight, (int)scale);
    double height = charon_grid_value(grid, 3, 1, pointSize, (int)weight, (int)scale);
    double bottom = charon_grid_value(grid, 3, 2, pointSize, (int)weight, (int)scale);
    double left = 0, right = 0;
    for (size_t i = 0; i < sizeof CharonSymbolSideInsets / sizeof CharonSymbolSideInsets[0]; i++) {
        if (CharonSymbolSideInsets[i].index == index) {
            left = charon_grid_value(CharonSymbolSideInsets[i].values, 2, 0, pointSize, (int)weight, (int)scale);
            right = charon_grid_value(CharonSymbolSideInsets[i].values, 2, 1, pointSize, (int)weight, (int)scale);
        }
    }
    double alignment = charon_round_half(1.174 * pointSize), descent = charon_round_half(0.2085 * pointSize);
    *size = CGSizeMake(width, height);
    *insets = UIEdgeInsetsMake(height - alignment - bottom, left, bottom, right);
    *baseline = bottom + descent;
    return YES;
}

// The extent of a glyph's geometry, so that whatever margin a script leaves, its drawing fills the space the host's symbol fills.
static CGRect charon_glyph_bounds(NSString *name, NSString *script)
{
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSMutableDictionary alloc] init];
    });
    @synchronized (cache) {
        NSValue *stored = cache[name];
        if (stored)
            return [stored CGRectValue];
        CGRect bounds = CGRectNull;
        CharonScene scene = {NULL, CGAffineTransformIdentity, 1, NO, NO, 0, &bounds};
        charon_run(script, scene);
        if (CGRectIsNull(bounds) || bounds.size.width < 1 || bounds.size.height < 1)
            bounds = CGRectMake(0, 0, 100, 100);
        cache[name] = [NSValue valueWithCGRect:bounds];
        return bounds;
    }
}

UIImage *charon_symbol_bitmap(NSString *name, double pointSize, NSInteger weight, NSInteger scale, CGFloat displayScale)
{
    NSInteger index = charon_symbol_index(name);
    NSString *script = charon_glyph_script(name);
    CGSize size;
    UIEdgeInsets insets;
    CGFloat baseline;
    if (index < 0 || !script || !charon_symbol_metrics(name, pointSize, weight, scale, &size, &insets, &baseline))
        return nil;
    weight = weight >= 1 && weight <= 9 ? weight : 4;
    scale = scale >= 1 && scale <= 3 ? scale : 2;
    const int16_t *margins = CharonSymbolMargins[index] + (scale - 1) * 4;
    double unit = pointSize / 100 / 2;
    CGRect ink = CGRectMake(margins[0] * unit, margins[1] * unit, size.width - (margins[0] + margins[2]) * unit, size.height - (margins[1] + margins[3]) * unit);
    double line = pointSize * CharonLineWeights[weight];
    CGRect box = CGRectInset(ink, MIN(line / 2, ink.size.width / 2.2), MIN(line / 2, ink.size.height / 2.2));
    UIGraphicsBeginImageContextWithOptions(size, NO, displayScale);
    CharonScene scene = {UIGraphicsGetCurrentContext(), CGAffineTransformIdentity, (CGFloat)line, NO, NO, 0, NULL};
    CGRect extent = charon_glyph_bounds(name, script);
    scene.map = CGAffineTransformScale(CGAffineTransformMakeTranslation(box.origin.x, box.origin.y), box.size.width / extent.size.width, box.size.height / extent.size.height);
    scene.map = CGAffineTransformTranslate(scene.map, -extent.origin.x, -extent.origin.y);
    charon_run(script, scene);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
