#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
static void dump(const char *label, CGMutableImageMetadataRef m) {
    CFDataRef d = CGImageMetadataCreateXMPData(m, NULL);
    if (!d) { printf("=== %s: NULL\n", label); return; }
    NSData *data = (__bridge NSData *)d;
    [(__bridge NSData *)d writeToFile:[NSString stringWithFormat:@"xmp-%s.bin", label] atomically:YES];
    printf("=== %s: %lu bytes -> xmp-%s.bin\n", label, (unsigned long)[data length], label);
    CFRelease(d);
}
int main(void) { @autoreleasepool {
    setvbuf(stdout, NULL, _IOLBF, 0);
    CGMutableImageMetadataRef one = CGImageMetadataCreateMutable();
    CGImageMetadataSetValueWithPath(one, NULL, CFSTR("exif:Flash"), CFSTR("1"));
    dump("flash", one);
    CGMutableImageMetadataRef two = CGImageMetadataCreateMutable();
    CGImageMetadataSetValueWithPath(two, NULL, CFSTR("dc:subject"), (__bridge CFTypeRef)[NSArray arrayWithObjects:@"one", @"two", nil]);
    CGImageMetadataSetValueWithPath(two, NULL, CFSTR("tiff:Orientation"), (__bridge CFTypeRef)@1);
    dump("array", two);
    CGMutableImageMetadataRef empty = CGImageMetadataCreateMutable();
    dump("empty", empty);
    // and the other direction: Apple's own parse of a packet we write by hand
    const char *packet = "<?xpacket begin=\"\xef\xbb\xbf\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n"
                         "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n"
                         " <rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n"
                         "  <rdf:Description rdf:about=\"\"\n"
                         "    xmlns:exif=\"http://ns.adobe.com/exif/1.0/\"\n"
                         "    xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n"
                         "    exif:Flash=\"1\">\n"
                         "   <dc:subject><rdf:Bag><rdf:li>one</rdf:li><rdf:li>two</rdf:li></rdf:Bag></dc:subject>\n"
                         "  </rdf:Description>\n"
                         " </rdf:RDF>\n"
                         "</x:xmpmeta>\n<?xpacket end=\"w\"?>\n";
    NSData *in = [NSData dataWithBytes:packet length:strlen(packet)];
    CGImageMetadataRef parsed = CGImageMetadataCreateFromXMPData((__bridge CFDataRef)in);
    printf("=== parse: %s\n", parsed ? "non-NULL" : "NULL");
    NSArray *tags = parsed ? (__bridge_transfer NSArray *)CGImageMetadataCopyTags(parsed) : nil;
    printf("=== parse: %lu tags\n", (unsigned long)tags.count);
    for (id t in tags) {
        CGImageMetadataTagRef tag = (__bridge CGImageMetadataTagRef)t;
        CFStringRef ns = CGImageMetadataTagCopyNamespace(tag), p = CGImageMetadataTagCopyPrefix(tag),
                   n = CGImageMetadataTagCopyName(tag);
        id v = (__bridge_transfer id)CGImageMetadataTagCopyValue(tag);
        printf("  ns=%s prefix=%s name=%s type=%d value=%s\n",
               ns ? CFStringGetCStringPtr(ns, kCFStringEncodingUTF8) : "-",
               p ? CFStringGetCStringPtr(p, kCFStringEncodingUTF8) : "-",
               n ? CFStringGetCStringPtr(n, kCFStringEncodingUTF8) : "-", (int)CGImageMetadataTagGetType(tag),
               [v isKindOfClass:[NSArray class]] ? "(array)" : [[v description] UTF8String]);
    }
    return 0;
} }
