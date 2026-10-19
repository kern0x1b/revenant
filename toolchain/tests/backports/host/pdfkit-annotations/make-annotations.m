#import <Foundation/Foundation.h>
#include <stdio.h>

static NSData *pdfBytes(NSArray<NSString *> *bodies)
{
    NSMutableData *out = [NSMutableData data];
    [out appendData:[@"%PDF-1.4\n" dataUsingEncoding:NSASCIIStringEncoding]];
    NSMutableArray<NSNumber *> *offsets = [NSMutableArray array];
    for (NSUInteger i = 0; i < bodies.count; i++) {
        [offsets addObject:@(out.length)];
        NSString *object = [NSString stringWithFormat:@"%lu 0 obj\n%@\nendobj\n", (unsigned long)(i + 1), bodies[i]];
        [out appendData:[object dataUsingEncoding:NSASCIIStringEncoding]];
    }
    NSUInteger xref = out.length;
    NSMutableString *table = [NSMutableString stringWithFormat:@"xref\n0 %lu\n0000000000 65535 f \n", (unsigned long)(bodies.count + 1)];
    for (NSNumber *offset in offsets)
        [table appendFormat:@"%010lu 00000 n \n", (unsigned long)offset.unsignedIntegerValue];
    [table appendFormat:@"trailer\n<< /Size %lu /Root 1 0 R >>\nstartxref\n%lu\n%%%%EOF\n",
                        (unsigned long)(bodies.count + 1), (unsigned long)xref];
    [out appendData:[table dataUsingEncoding:NSASCIIStringEncoding]];
    return out;
}

static NSString *appearanceStream(void)
{
    NSString *content = @"0 g 0 0 100 20 re f";
    return [NSString stringWithFormat:@"<< /Type /XObject /Subtype /Form /BBox [0 0 100 20] /Length %lu >>\nstream\n%@\nendstream",
                                      (unsigned long)[content length], content];
}

static NSArray<NSString *> *pageWith(NSString *annotation, NSString *appearance)
{
    NSString *annots = annotation ? @" /Annots [4 0 R]" : @"";
    NSString *page = [NSString stringWithFormat:@"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300]%@ >>", annots];
    return @[
        @"<< /Type /Catalog /Pages 2 0 R >>",
        @"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        page,
        annotation ?: @"<< /Type /Null >>",
        appearance ?: appearanceStream(),
    ];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *directory = argc > 1 ? @(argv[1]) : NSTemporaryDirectory();
        NSDictionary<NSString *, NSArray<NSString *> *> *fixtures = @{
            @"annot-square.pdf" : pageWith(@"<< /Type /Annot /Subtype /Square /Rect [10 10 100 100] >>", nil),
            @"annot-ap.pdf" : pageWith(@"<< /Type /Annot /Subtype /Square /Rect [10 10 110 30] /AP << /N 5 0 R >> >>", nil),
            @"annot-uri.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /A << /S /URI /URI (https://example.com/a) >> >>", nil),
            @"annot-link-noa.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] >>", nil),
            @"annot-open.pdf" : pageWith(@"<< /Type /Annot /Subtype /Text /Rect [10 10 30 30] /Open true >>", nil),
            @"annot-open-no.pdf" : pageWith(@"<< /Type /Annot /Subtype /Text /Rect [10 10 30 30] /Open false >>", nil),
            @"annot-highlight.pdf" : pageWith(@"<< /Type /Annot /Subtype /Highlight /Rect [10 10 100 40] /QuadPoints [10 40 100 40 10 10 100 10] >>", nil),
            @"annot-ap-down.pdf" : pageWith(@"<< /Type /Annot /Subtype /Square /Rect [10 10 110 30] /AP << /D 5 0 R >> >>", nil),
            @"annot-link-h.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /H /I /A << /S /URI /URI (https://example.com/h) >> >>", nil),
            @"annot-link-h-n.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /H /N >>", nil),
            @"annot-goto.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /Dest [3 0 R /Fit] >>", nil),
            @"annot-square-open.pdf" : pageWith(@"<< /Type /Annot /Subtype /Square /Rect [10 10 100 100] /Open true >>", nil),
            @"annot-link-open.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /Open true >>", nil),
            @"annot-gotor.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /A << /S /GoToR /F (other.pdf) /D [0 /Fit] >> >>", nil),
            @"annot-launch.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /A << /S /Launch /F (other.pdf) >> >>", nil),
            @"annot-launch-spec.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /A << /S /Launch /F << /Type /Filespec /F (other.pdf) >> >> >>", nil),
            @"annot-launch-win.pdf" : pageWith(@"<< /Type /Annot /Subtype /Link /Rect [10 10 100 40] /A << /S /Launch /Win << /F (other.exe) >> >> >>", nil),
            @"annot-none.pdf" : pageWith(nil, nil),
        };
        for (NSString *name in [fixtures.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *path = [directory stringByAppendingPathComponent:name];
            if (![pdfBytes(fixtures[name]) writeToFile:path atomically:NO]) {
                fprintf(stderr, "could not write %s\n", path.UTF8String);
                return 1;
            }
            printf("%s written\n", name.UTF8String);
        }
    }
    return 0;
}
