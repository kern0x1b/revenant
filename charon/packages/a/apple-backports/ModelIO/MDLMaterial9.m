#import <ModelIO/ModelIO.h>
#import <string.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// A material is a set of named properties, each of one semantic (what it means to a renderer) and of
// one type (how its value is written). A property's value is a string, a URL, a texture, a colour, a
// float or a vector, or a 4x4 matrix, and the type says which: a property written as a float read
// back as a float3 is three floats of it, which is what a renderer wants from a scalar.

@implementation MDLTextureFilter {
    MDLMaterialTextureWrapMode _sWrapMode, _tWrapMode, _rWrapMode;
    MDLMaterialTextureFilterMode _minFilter, _magFilter;
    MDLMaterialMipMapFilterMode _mipFilter;
}

@synthesize sWrapMode = _sWrapMode;
@synthesize tWrapMode = _tWrapMode;
@synthesize rWrapMode = _rWrapMode;
@synthesize minFilter = _minFilter;
@synthesize magFilter = _magFilter;
@synthesize mipFilter = _mipFilter;

- (instancetype)init
{
    if ((self = [super init])) {
        _sWrapMode = _tWrapMode = _rWrapMode = MDLMaterialTextureWrapModeRepeat;
        _minFilter = _magFilter = MDLMaterialTextureFilterModeLinear;
        _mipFilter = MDLMaterialMipMapFilterModeLinear;
    }
    return self;
}

@end
@implementation MDLTextureSampler {
    MDLTexture *_texture;
    MDLTextureFilter *_hardwareFilter;
    MDLTransform *_transform;
}

@synthesize texture = _texture;
@synthesize hardwareFilter = _hardwareFilter;
@synthesize transform = _transform;

- (void)dealloc
{
}

@end
@implementation MDLMaterialProperty {
    NSString *_name;
    MDLMaterialSemantic _semantic;
    MDLMaterialPropertyType _type;
    NSString *_stringValue;
    NSURL *_URLValue;
    MDLTextureSampler *_textureSamplerValue;
    CGColorRef _color;
    float _floatValue;
    vector_float2 _float2Value;
    vector_float3 _float3Value;
    vector_float4 _float4Value;
    matrix_float4x4 _matrix4x4;
}

@synthesize name = _name;
@synthesize semantic = _semantic;
@synthesize type = _type;
@synthesize stringValue = _stringValue;
@synthesize URLValue = _URLValue;
@synthesize textureSamplerValue = _textureSamplerValue;
@synthesize color = _color;
@synthesize floatValue = _floatValue;
@synthesize float2Value = _float2Value;
@synthesize float3Value = _float3Value;
@synthesize float4Value = _float4Value;
@synthesize matrix4x4 = _matrix4x4;

// The value a property is given decides its type, so there is one place that reads it back out.
- (void)charon_setValue:(id)value
{
    if (!value) {
        _type = MDLMaterialPropertyTypeNone;
    } else if ([value isKindOfClass:[NSString class]]) {
        [self charon_setString:value];
    } else if ([value isKindOfClass:[NSURL class]]) {
        [self charon_setURL:value];
    } else if ([value isKindOfClass:[MDLTextureSampler class]]) {
        [self charon_setTextureSampler:value];
    } else if ([value isKindOfClass:[NSNumber class]]) {
        _floatValue = [value floatValue];
        _type = MDLMaterialPropertyTypeFloat;
    } else if (CFGetTypeID((__bridge CFTypeRef)value) == CGColorGetTypeID()) {
        [self charon_setColor:(__bridge CGColorRef)value];
    } else if (strncmp([value objCType], @encode(vector_float2), strlen(@encode(vector_float2))) == 0) {
        vector_float2 typed;
        memcpy(&typed, &value, sizeof typed);
        [self charon_setFloat2:typed];
    } else if (strncmp([value objCType], @encode(vector_float3), strlen(@encode(vector_float3))) == 0) {
        vector_float3 typed;
        memcpy(&typed, &value, sizeof typed);
        [self charon_setFloat3:typed];
    } else if (strncmp([value objCType], @encode(vector_float4), strlen(@encode(vector_float4))) == 0) {
        vector_float4 typed;
        memcpy(&typed, &value, sizeof typed);
        [self charon_setFloat4:typed];
    } else if (strncmp([value objCType], @encode(matrix_float4x4), strlen(@encode(matrix_float4x4))) == 0) {
        matrix_float4x4 typed;
        memcpy(&typed, &value, sizeof typed);
        [self charon_setMatrix4x4:typed];
    } else if ([value isKindOfClass:[NSData class]]) {
        _type = MDLMaterialPropertyTypeBuffer;
    } else {
        _type = MDLMaterialPropertyTypeNone;
    }
}

- (void)charon_setString:(NSString *)value
{
    if (_stringValue != value) {
        _stringValue = [value copy];
    }
    _type = MDLMaterialPropertyTypeString;
}

- (void)charon_setURL:(NSURL *)value
{
    if (_URLValue != value) {
        _URLValue = value;
    }
    _type = MDLMaterialPropertyTypeURL;
}

- (void)charon_setTextureSampler:(MDLTextureSampler *)value
{
    if (_textureSamplerValue != value) {
        _textureSamplerValue = value;
    }
    _type = MDLMaterialPropertyTypeTexture;
}

- (void)charon_setColor:(CGColorRef)value
{
    if (_color != value) {
        CGColorRelease(_color);
        _color = value ? CGColorRetain(value) : NULL;
    }
    _type = MDLMaterialPropertyTypeColor;
}

- (void)charon_setFloat:(float)value
{
    _floatValue = value;
    _type = MDLMaterialPropertyTypeFloat;
}

- (void)charon_setFloat2:(vector_float2)value
{
    _float2Value = value;
    _type = MDLMaterialPropertyTypeFloat2;
}

- (void)charon_setFloat3:(vector_float3)value
{
    _float3Value = value;
    _type = MDLMaterialPropertyTypeFloat3;
}

- (void)charon_setFloat4:(vector_float4)value
{
    _float4Value = value;
    _type = MDLMaterialPropertyTypeFloat4;
}

- (void)charon_setMatrix4x4:(matrix_float4x4)value
{
    _matrix4x4 = value;
    _type = MDLMaterialPropertyTypeMatrix44;
}

- (id)initWithName:(NSString *)name semantic:(MDLMaterialSemantic)semantic value:(id)value
{
    if ((self = [super init])) {
        _name = [name copy];
        _semantic = semantic;
        _float4Value = (vector_float4){0, 0, 0, 1};
        [self charon_setValue:value];
    }
    return self;
}

- (void)dealloc
{
    CGColorRelease(_color);
}

- (float)luminance
{
    if (_type == MDLMaterialPropertyTypeColor && _color) {
        const CGFloat *components = CGColorGetComponents(_color);
        size_t count = CGColorGetNumberOfComponents(_color);
        if (count >= 3)
            return (float)(0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2]);
        if (count == 2)
            return (float)(components[0] * components[1]);
        if (count == 1)
            return (float)(components[0] * components[0]);
        return 0;
    }
    if (_type == MDLMaterialPropertyTypeFloat)
        return _floatValue;
    if (_type == MDLMaterialPropertyTypeFloat2)
        return (float)(0.2126 * _float2Value.x + 0.7152 * _float2Value.y);
    if (_type == MDLMaterialPropertyTypeFloat3)
        return (float)(0.2126 * _float3Value.x + 0.7152 * _float3Value.y + 0.0722 * _float3Value.z);
    if (_type == MDLMaterialPropertyTypeFloat4)
        return (float)(0.2126 * _float4Value.x + 0.7152 * _float4Value.y + 0.0722 * _float4Value.z) * _float4Value.w;
    return 0;
}

- (void)setProperties:(MDLMaterialProperty *)property
{
    // The value of the other property, under this property's own name and semantic.
    [self charon_setValue:[property charon_value]];
    if (property.color)
        [self charon_setColor:property.color];
}

- (id)charon_value
{
    switch (_type) {
        case MDLMaterialPropertyTypeString:
            return _stringValue;
        case MDLMaterialPropertyTypeURL:
            return _URLValue;
        case MDLMaterialPropertyTypeTexture:
            return _textureSamplerValue;
        case MDLMaterialPropertyTypeColor:
            return (__bridge id)_color;
        case MDLMaterialPropertyTypeFloat:
            return @(_floatValue);
        case MDLMaterialPropertyTypeFloat2:
            return [NSValue valueWithBytes:&_float2Value objCType:@encode(vector_float2)];
        case MDLMaterialPropertyTypeFloat3:
            return [NSValue valueWithBytes:&_float3Value objCType:@encode(vector_float3)];
        case MDLMaterialPropertyTypeFloat4:
            return [NSValue valueWithBytes:&_float4Value objCType:@encode(vector_float4)];
        case MDLMaterialPropertyTypeMatrix44:
            return [NSValue valueWithBytes:&_matrix4x4 objCType:@encode(matrix_float4x4)];
        case MDLMaterialPropertyTypeBuffer:
        case MDLMaterialPropertyTypeNone:
            return nil;
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    MDLMaterialProperty *copy = [[[self class] allocWithZone:zone] initWithName:_name semantic:_semantic value:nil];
    [copy charon_setValue:[self charon_value]];
    return copy;
}

@end
@implementation MDLScatteringFunction {
    NSString *_name;
    NSMutableDictionary<NSString *, MDLMaterialProperty *> *_properties;
}

@synthesize name = _name;

- (instancetype)init
{
    if ((self = [super init])) {
        _name = @"";
        _properties = [[NSMutableDictionary alloc] init];
        // What every scattering function carries: the colour, the emission, the two indices of
        // refraction, the normal and the ambient occlusion, each of the type a renderer reads it in.
        [self charon_add:@"baseColor" semantic:MDLMaterialSemanticBaseColor type:MDLMaterialPropertyTypeColor value:1];
        [self charon_add:@"emission" semantic:MDLMaterialSemanticEmission type:MDLMaterialPropertyTypeColor value:0];
        [self charon_add:@"specular" semantic:MDLMaterialSemanticSpecular type:MDLMaterialPropertyTypeFloat value:0];
        [self charon_add:@"materialIndexOfRefraction"
                semantic:MDLMaterialSemanticMaterialIndexOfRefraction
                    type:MDLMaterialPropertyTypeFloat
                   value:1];
        [self charon_add:@"interfaceIndexOfRefraction"
                semantic:MDLMaterialSemanticInterfaceIndexOfRefraction
                    type:MDLMaterialPropertyTypeFloat
                   value:1];
        [self charon_add:@"ambientOcclusion" semantic:MDLMaterialSemanticAmbientOcclusion type:MDLMaterialPropertyTypeFloat value:0];
        [self charon_add:@"ambientOcclusionScale"
                semantic:MDLMaterialSemanticAmbientOcclusionScale
                    type:MDLMaterialPropertyTypeFloat
                   value:1];
    }
    return self;
}

- (void)dealloc
{
}

- (void)charon_add:(NSString *)name semantic:(MDLMaterialSemantic)semantic type:(MDLMaterialPropertyType)type
{
    id value = [NSNumber numberWithFloat:0];
    switch (type) {
        case MDLMaterialPropertyTypeFloat3:
            value = [NSValue valueWithBytes:"\0\0\0\0\0\0\0\0\0\0\0\0" objCType:@encode(vector_float3)];
            break;
        case MDLMaterialPropertyTypeFloat4:
            value = [NSValue valueWithBytes:"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" objCType:@encode(vector_float4)];
            break;
        case MDLMaterialPropertyTypeColor:
            value = (__bridge id)CGColorRetain(CGColorCreateGenericRGB(1, 1, 1, 1));
            break;
        default:
            break;
    }
    MDLMaterialProperty *property = [[MDLMaterialProperty alloc] initWithName:name semantic:semantic value:value];
    [_properties setObject:property forKey:name];
}

- (void)charon_add:(NSString *)name
           semantic:(MDLMaterialSemantic)semantic
               type:(MDLMaterialPropertyType)type
              value:(float)value
{
    // The value of a property of the framework's own, read on the host rather than chosen here.
    id given = [NSNumber numberWithFloat:value];
    if (type == MDLMaterialPropertyTypeColor) {
        // A colour of that value, opaque: white where the framework's default is a white.
        CGFloat components[4] = {value, value, value, 1};
        given = (__bridge id)CGColorCreateGenericRGB(components[0], components[1], components[2], components[3]);
    }
    MDLMaterialProperty *property = [[MDLMaterialProperty alloc] initWithName:name semantic:semantic value:given];
    [_properties setObject:property forKey:name];
}

- (MDLMaterialProperty *)charon_propertyNamed:(NSString *)name
{
    return _properties[name];
}

- (NSArray<MDLMaterialProperty *> *)charon_allProperties
{
    return [_properties.allValues sortedArrayUsingComparator:^NSComparisonResult(MDLMaterialProperty *a, MDLMaterialProperty *b) {
        return (NSComparisonResult)(a.semantic - b.semantic);
    }];
}

- (MDLMaterialProperty *)baseColor
{
    return [self charon_propertyNamed:@"baseColor"];
}

- (MDLMaterialProperty *)emission
{
    return [self charon_propertyNamed:@"emission"];
}

- (MDLMaterialProperty *)specular
{
    return [self charon_propertyNamed:@"specular"];
}

- (MDLMaterialProperty *)materialIndexOfRefraction
{
    return [self charon_propertyNamed:@"materialIndexOfRefraction"];
}

- (MDLMaterialProperty *)interfaceIndexOfRefraction
{
    return [self charon_propertyNamed:@"interfaceIndexOfRefraction"];
}

- (MDLMaterialProperty *)normal
{
    return [self charon_propertyNamed:@"normal"];
}

- (MDLMaterialProperty *)ambientOcclusion
{
    return [self charon_propertyNamed:@"ambientOcclusion"];
}

- (MDLMaterialProperty *)ambientOcclusionScale
{
    return [self charon_propertyNamed:@"ambientOcclusionScale"];
}

@end
@implementation MDLPhysicallyPlausibleScatteringFunction

- (instancetype)init
{
    if ((self = [super init])) {
        // The properties a physically based material has that the older function does not: the
        // metallic-roughness set, the sheen, the clear coat and the subsurface colour.
        // The ten of a physically plausible material, and the values the framework gives them by
        // default: zero for most of them, a ninth of a unit of roughness, a twentieth of a unit of
        // sheen, and no anisotropy.
        [self charon_add:@"subsurface" semantic:MDLMaterialSemanticSubsurface type:MDLMaterialPropertyTypeFloat value:0];
        [self charon_add:@"metallic" semantic:MDLMaterialSemanticMetallic type:MDLMaterialPropertyTypeFloat value:0];
        [self charon_add:@"specular" semantic:MDLMaterialSemanticSpecular type:MDLMaterialPropertyTypeFloat value:0];
        [self charon_add:@"specularTint" semantic:MDLMaterialSemanticSpecularTint type:MDLMaterialPropertyTypeFloat value:0];
        [self charon_add:@"roughness" semantic:MDLMaterialSemanticRoughness type:MDLMaterialPropertyTypeFloat value:0.9f];
        [self charon_add:@"anisotropicRotation"
                semantic:MDLMaterialSemanticAnisotropicRotation
                    type:MDLMaterialPropertyTypeFloat
                   value:0];
        [self charon_add:@"sheen" semantic:MDLMaterialSemanticSheen type:MDLMaterialPropertyTypeFloat value:0.05f];
        [self charon_add:@"sheenTint" semantic:MDLMaterialSemanticSheenTint type:MDLMaterialPropertyTypeFloat value:0];
        [self charon_add:@"clearcoat" semantic:MDLMaterialSemanticClearcoat type:MDLMaterialPropertyTypeFloat value:0];
        [self charon_add:@"clearcoatGloss" semantic:MDLMaterialSemanticClearcoatGloss type:MDLMaterialPropertyTypeFloat value:0];
    }
    return self;
}

- (NSInteger)version
{
    return 1;
}

- (MDLMaterialProperty *)subsurface
{
    return [self charon_propertyNamed:@"subsurface"];
}

- (MDLMaterialProperty *)metallic
{
    return [self charon_propertyNamed:@"metallic"];
}

- (MDLMaterialProperty *)specularAmount
{
    return [self charon_propertyNamed:@"specularAmount"];
}

- (MDLMaterialProperty *)specularTint
{
    return [self charon_propertyNamed:@"specularTint"];
}

- (MDLMaterialProperty *)roughness
{
    return [self charon_propertyNamed:@"roughness"];
}

- (MDLMaterialProperty *)anisotropic
{
    return [self charon_propertyNamed:@"anisotropic"];
}

- (MDLMaterialProperty *)anisotropicRotation
{
    return [self charon_propertyNamed:@"anisotropicRotation"];
}

- (MDLMaterialProperty *)sheen
{
    return [self charon_propertyNamed:@"sheen"];
}

- (MDLMaterialProperty *)sheenTint
{
    return [self charon_propertyNamed:@"sheenTint"];
}

- (MDLMaterialProperty *)clearcoat
{
    return [self charon_propertyNamed:@"clearcoat"];
}

- (MDLMaterialProperty *)clearcoatGloss
{
    return [self charon_propertyNamed:@"clearcoatGloss"];
}

@end
@implementation MDLMaterial {
    NSMutableArray<MDLMaterialProperty *> *_properties;
    NSMutableDictionary<NSString *, NSNumber *> *_byName;
    NSMutableDictionary<NSNumber *, MDLMaterialProperty *> *_bySemantic;
    MDLScatteringFunction *_scatteringFunction;
    NSString *_name;
    MDLMaterial *_baseMaterial;
    MDLMaterialFace _materialFace;
}

@synthesize name = _name;
@synthesize baseMaterial = _baseMaterial;
@synthesize materialFace = _materialFace;

- (instancetype)initWithName:(NSString *)name scatteringFunction:(MDLScatteringFunction *)scatteringFunction
{
    if ((self = [super init])) {
        _name = [name copy];
        _properties = [[NSMutableArray alloc] init];
        _byName = [[NSMutableDictionary alloc] init];
        _bySemantic = [[NSMutableDictionary alloc] init];
        _scatteringFunction = scatteringFunction;
        _materialFace = MDLMaterialFaceFront;
        // Every property of the scattering function the material was made with, which is what gives a
        // new material its sixteen: the function's own defaults, not a pair invented here.
        for (MDLMaterialProperty *property in [scatteringFunction charon_allProperties])
            [self setProperty:property];
    }
    return self;
}

- (void)dealloc
{
}

- (MDLScatteringFunction *)scatteringFunction
{
    return _scatteringFunction;
}

- (void)setProperty:(MDLMaterialProperty *)property
{
    if (!property)
        return;
    NSNumber *existing = _byName[property.name];
    if (existing)
        [_properties removeObjectAtIndex:existing.unsignedIntegerValue];
    [_byName removeObjectForKey:property.name];
    [_bySemantic removeObjectForKey:@(property.semantic)];
    [_properties addObject:property];
    _byName[property.name] = @(_properties.count - 1);
    if (property.semantic != MDLMaterialSemanticNone && property.semantic != MDLMaterialSemanticUserDefined)
        _bySemantic[@(property.semantic)] = property;
}

- (void)removeProperty:(MDLMaterialProperty *)property
{
    NSNumber *index = _byName[property.name];
    if (!index)
        return;
    [_properties removeObjectAtIndex:index.unsignedIntegerValue];
    [_byName removeObjectForKey:property.name];
    [_bySemantic removeObjectForKey:@(property.semantic)];
    // The indices of the properties after it move down by one, so the table is rebuilt.
    [_byName removeAllObjects];
    for (NSUInteger k = 0; k < _properties.count; k++)
        _byName[_properties[k].name] = @(k);
}

- (MDLMaterialProperty *)propertyNamed:(NSString *)name
{
    return _properties[_byName[name].unsignedIntegerValue];
}

- (MDLMaterialProperty *)propertyWithSemantic:(MDLMaterialSemantic)semantic
{
    return _bySemantic[@(semantic)];
}

- (void)removeAllProperties
{
    [_properties removeAllObjects];
    [_byName removeAllObjects];
    [_bySemantic removeAllObjects];
}

- (NSUInteger)count
{
    return _properties.count;
}

- (MDLMaterialProperty *)objectAtIndexedSubscript:(NSUInteger)idx
{
    return idx < _properties.count ? _properties[idx] : nil;
}

- (MDLMaterialProperty *)objectForKeyedSubscript:(NSString *)name
{
    return [self propertyNamed:name];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)length
{
    return [_properties countByEnumeratingWithState:state objects:buffer count:length];
}

@end
