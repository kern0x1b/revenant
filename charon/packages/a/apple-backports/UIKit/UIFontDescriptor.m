#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <objc/runtime.h>
#include <dlfcn.h>


static struct {
    CTFontDescriptorRef (*descriptorWithAttributes)(CFDictionaryRef);
    CFTypeRef (*descriptorCopyAttribute)(CTFontDescriptorRef, CFStringRef);
    CFDictionaryRef (*descriptorCopyAttributes)(CTFontDescriptorRef);
    CFArrayRef (*matching)(CTFontDescriptorRef, CFSetRef);
    CTFontRef (*fontWithDescriptor)(CTFontDescriptorRef, CGFloat, const CGAffineTransform *);
    CTFontRef (*copyWithTraits)(CTFontRef, CGFloat, const CGAffineTransform *, CTFontSymbolicTraits, CTFontSymbolicTraits);
    CFStringRef (*postScriptName)(CTFontRef);
    CTFontSymbolicTraits (*symbolicTraits)(CTFontRef);
} charon_ct;

static void charon_ct_load(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_ct.descriptorWithAttributes = dlsym(RTLD_DEFAULT, "CTFontDescriptorCreateWithAttributes");
        charon_ct.descriptorCopyAttribute = dlsym(RTLD_DEFAULT, "CTFontDescriptorCopyAttribute");
        charon_ct.descriptorCopyAttributes = dlsym(RTLD_DEFAULT, "CTFontDescriptorCopyAttributes");
        charon_ct.matching = dlsym(RTLD_DEFAULT, "CTFontDescriptorCreateMatchingFontDescriptors");
        charon_ct.fontWithDescriptor = dlsym(RTLD_DEFAULT, "CTFontCreateWithFontDescriptor");
        charon_ct.copyWithTraits = dlsym(RTLD_DEFAULT, "CTFontCreateCopyWithSymbolicTraits");
        charon_ct.postScriptName = dlsym(RTLD_DEFAULT, "CTFontCopyPostScriptName");
        charon_ct.symbolicTraits = dlsym(RTLD_DEFAULT, "CTFontGetSymbolicTraits");
    });
}

static const UIFontDescriptorSymbolicTraits CharonTraitMask = UIFontDescriptorTraitItalic | UIFontDescriptorTraitBold | UIFontDescriptorTraitExpanded | UIFontDescriptorTraitCondensed;

@implementation UIFontDescriptor {
    NSDictionary *_attributes;
    CTFontDescriptorRef _descriptor;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    return [self initWithFontAttributes:@{}];
}

- (instancetype)initWithFontAttributes:(NSDictionary *)attributes
{
    if ((self = [super init]))
        _attributes = [attributes copy] ?: @{};
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSDictionary *attributes = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSValue class], [NSData class], [NSSet class], [NSCharacterSet class], nil] forKey:@"UIFontDescriptorAttributes"];
    return [self initWithFontAttributes:attributes ?: @{}];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_attributes forKey:@"UIFontDescriptorAttributes"];
}

- (void)dealloc
{
    if (_descriptor)
        CFRelease(_descriptor);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isKindOfClass:[UIFontDescriptor class]] && [_attributes isEqualToDictionary:[(UIFontDescriptor *)object fontAttributes]]);
}

- (NSUInteger)hash
{
    return _attributes.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<UIFontDescriptor: %p> = %@", self, _attributes];
}

- (CTFontDescriptorRef)charon_descriptor
{
    charon_ct_load();
    if (!_descriptor)
        _descriptor = charon_ct.descriptorWithAttributes((__bridge CFDictionaryRef)_attributes);
    return _descriptor;
}

- (CTFontRef)charon_fontWithSize:(CGFloat)size
{
    charon_ct_load();
    CGAffineTransform matrix = self.matrix;
    BOOL identity = CGAffineTransformIsIdentity(matrix);
    return charon_ct.fontWithDescriptor([self charon_descriptor], size > 0 ? size : (self.pointSize > 0 ? self.pointSize : 12), identity ? NULL : &matrix);
}

- (NSString *)postscriptName
{
    NSString *name = _attributes[UIFontDescriptorNameAttribute];
    if (name)
        return name;
    CTFontRef font = [self charon_fontWithSize:0];
    NSString *resolved = font ? CFBridgingRelease(charon_ct.postScriptName(font)) : nil;
    if (font)
        CFRelease(font);
    return resolved;
}

- (CGFloat)pointSize
{
    return [_attributes[UIFontDescriptorSizeAttribute] doubleValue];
}

- (CGAffineTransform)matrix
{
    id value = _attributes[UIFontDescriptorMatrixAttribute];
    return [value isKindOfClass:[NSValue class]] ? [value CGAffineTransformValue] : CGAffineTransformIdentity;
}

- (UIFontDescriptorSymbolicTraits)symbolicTraits
{
    charon_ct_load();
    CTFontRef font = [self charon_fontWithSize:0];
    UIFontDescriptorSymbolicTraits traits = font ? charon_ct.symbolicTraits(font) : 0;
    if (font)
        CFRelease(font);
    return traits;
}

- (id)objectForKey:(UIFontDescriptorAttributeName)attribute
{
    id value = _attributes[attribute];
    if (value)
        return value;
    if (![attribute isKindOfClass:[NSString class]])
        return nil;
    return CFBridgingRelease(charon_ct.descriptorCopyAttribute([self charon_descriptor], (__bridge CFStringRef)attribute));
}

- (NSDictionary *)fontAttributes
{
    return _attributes;
}

- (NSArray *)matchingFontDescriptorsWithMandatoryKeys:(NSSet *)mandatoryKeys
{
    charon_ct_load();
    CFArrayRef matches = charon_ct.matching([self charon_descriptor], (__bridge CFSetRef)mandatoryKeys);
    NSMutableArray *result = [NSMutableArray array];
    for (id match in CFBridgingRelease(matches)) {
        NSDictionary *attributes = CFBridgingRelease(charon_ct.descriptorCopyAttributes((__bridge CTFontDescriptorRef)match));
        if (attributes)
            [result addObject:[[UIFontDescriptor alloc] initWithFontAttributes:attributes]];
    }
    return result;
}

+ (UIFontDescriptor *)fontDescriptorWithFontAttributes:(NSDictionary *)attributes
{
    return [[self alloc] initWithFontAttributes:attributes];
}

+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)fontName size:(CGFloat)size
{
    return [[self alloc] initWithFontAttributes:@{UIFontDescriptorNameAttribute: fontName ?: @"", UIFontDescriptorSizeAttribute: @(size)}];
}

+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)fontName matrix:(CGAffineTransform)matrix
{
    return [[self alloc] initWithFontAttributes:@{UIFontDescriptorNameAttribute: fontName ?: @"", UIFontDescriptorMatrixAttribute: [NSValue valueWithCGAffineTransform:matrix]}];
}

+ (UIFontDescriptor *)preferredFontDescriptorWithTextStyle:(UIFontTextStyle)style
{
    UIFont *font = [UIFont preferredFontForTextStyle:style];
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:font.fontDescriptor.fontAttributes];
    if (style)
        attributes[UIFontDescriptorTextStyleAttribute] = style;
    return [[self alloc] initWithFontAttributes:attributes];
}

+ (UIFontDescriptor *)preferredFontDescriptorWithTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    return [self preferredFontDescriptorWithTextStyle:style];
}

- (UIFontDescriptor *)fontDescriptorByAddingAttributes:(NSDictionary *)attributes
{
    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:_attributes];
    [merged addEntriesFromDictionary:attributes];
    return [[UIFontDescriptor alloc] initWithFontAttributes:merged];
}

- (UIFontDescriptor *)fontDescriptorWithSize:(CGFloat)newPointSize
{
    return [self fontDescriptorByAddingAttributes:@{UIFontDescriptorSizeAttribute: @(newPointSize)}];
}

- (UIFontDescriptor *)fontDescriptorWithMatrix:(CGAffineTransform)matrix
{
    return [self fontDescriptorByAddingAttributes:@{UIFontDescriptorMatrixAttribute: [NSValue valueWithCGAffineTransform:matrix]}];
}

- (UIFontDescriptor *)fontDescriptorWithFace:(NSString *)newFace
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:_attributes];
    [attributes removeObjectForKey:UIFontDescriptorNameAttribute];
    attributes[UIFontDescriptorFaceAttribute] = newFace;
    return [[UIFontDescriptor alloc] initWithFontAttributes:attributes];
}

- (UIFontDescriptor *)fontDescriptorWithFamily:(NSString *)newFamily
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:_attributes];
    [attributes removeObjectForKey:UIFontDescriptorNameAttribute];
    attributes[UIFontDescriptorFamilyAttribute] = newFamily;
    return [[UIFontDescriptor alloc] initWithFontAttributes:attributes];
}

- (UIFontDescriptor *)fontDescriptorWithSymbolicTraits:(UIFontDescriptorSymbolicTraits)symbolicTraits
{
    charon_ct_load();
    CGFloat size = self.pointSize;
    CTFontRef font = [self charon_fontWithSize:size];
    if (!font)
        return nil;
    UIFontDescriptorSymbolicTraits current = charon_ct.symbolicTraits(font);
    CTFontRef changed = ((current ^ symbolicTraits) & CharonTraitMask) ? charon_ct.copyWithTraits(font, size > 0 ? size : 12, NULL, symbolicTraits & CharonTraitMask, CharonTraitMask) : (CTFontRef)CFRetain(font);
    CFRelease(font);
    if (!changed)
        return nil;
    NSString *name = CFBridgingRelease(charon_ct.postScriptName(changed));
    CFRelease(changed);
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObject:name forKey:UIFontDescriptorNameAttribute];
    if (size > 0)
        attributes[UIFontDescriptorSizeAttribute] = @(size);
    return [[UIFontDescriptor alloc] initWithFontAttributes:attributes];
}

@end

@implementation UIFont (CharonFontDescriptor)

- (UIFontDescriptor *)fontDescriptor
{
    return [UIFontDescriptor fontDescriptorWithName:self.fontName size:self.pointSize];
}

@end

static UIFont *charon_font_with_descriptor(UIFontDescriptor *descriptor, CGFloat size)
{
    CGFloat points = size > 0 ? size : (descriptor.pointSize > 0 ? descriptor.pointSize : 12);
    CTFontRef ct = [descriptor charon_fontWithSize:points];
    NSString *name = ct ? CFBridgingRelease(charon_ct.postScriptName(ct)) : nil;
    if (ct)
        CFRelease(ct);
    return [UIFont fontWithName:name size:points] ?: [UIFont systemFontOfSize:points];
}

@implementation UIFont (CharonFontWithDescriptor)

+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)descriptor size:(CGFloat)pointSize
{
    return [descriptor isKindOfClass:[UIFontDescriptor class]] ? charon_font_with_descriptor(descriptor, pointSize) : nil;
}

@end

@interface CharonFontDescriptorInstaller : NSObject
@end

@implementation CharonFontDescriptorInstaller

+ (void)load
{
    Class metaclass = object_getClass([UIFont class]);
    SEL selector = @selector(fontWithDescriptor:size:);
    Method method = class_getInstanceMethod(metaclass, selector);
    if (!method)
        return;
    UIFont *(*original)(id, SEL, id, CGFloat) = (UIFont * (*)(id, SEL, id, CGFloat))method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^UIFont *(id self_, id descriptor, CGFloat size) {
        if ([descriptor isKindOfClass:[UIFontDescriptor class]])
            return charon_font_with_descriptor(descriptor, size);
        return original(self_, selector, descriptor, size);
    }));
}

@end
