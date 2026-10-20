#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@implementation MDLRelativeAssetResolver {
    __unsafe_unretained MDLAsset *_asset;
}

- (instancetype)initWithAsset:(MDLAsset *)asset
{
    if ((self = [super init]))
        _asset = asset;
    return self;
}

- (MDLAsset *)asset
{
    return _asset;
}

- (void)setAsset:(MDLAsset *)asset
{
    _asset = asset;
}

- (NSURL *)resolveAssetNamed:(NSString *)name
{
    if (!name)
        return nil;
    if ([name hasPrefix:@"/"])
        return [NSURL fileURLWithPath:name];
    NSURL *base = _asset.URL;
    if (!base)
        return nil;
    NSString *directory = [base URLByDeletingLastPathComponent].path;
    if (!directory.length)
        return nil;
    return [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:name]];
}

- (BOOL)canResolveAssetNamed:(NSString *)name
{
    if (!name)
        return NO;
    if ([name hasPrefix:@"/"])
        return [[NSFileManager defaultManager] fileExistsAtPath:name];
    NSURL *resolved = [self resolveAssetNamed:name];
    return resolved && [[NSFileManager defaultManager] fileExistsAtPath:resolved.path];
}

@end
@implementation MDLPathAssetResolver {
    NSString *_path;
}

@synthesize path = _path;

- (instancetype)initWithPath:(NSString *)path
{
    if ((self = [super init]))
        _path = [path copy];
    return self;
}

- (void)dealloc
{
}

- (NSURL *)resolveAssetNamed:(NSString *)name
{
    if (!name)
        return nil;
    if ([name hasPrefix:@"/"])
        return [NSURL fileURLWithPath:name];
    if (!self.path.length)
        return [NSURL fileURLWithPath:name];
    return [NSURL fileURLWithPath:[self.path stringByAppendingPathComponent:name]];
}

- (BOOL)canResolveAssetNamed:(NSString *)name
{
    NSURL *resolved = [self resolveAssetNamed:name];
    return resolved && [[NSFileManager defaultManager] fileExistsAtPath:resolved.path];
}

@end
@implementation MDLBundleAssetResolver {
    NSString *_path;
}

@synthesize path = _path;

- (instancetype)initWithBundle:(NSString *)path
{
    if ((self = [super init]))
        _path = [path copy];
    return self;
}

- (void)dealloc
{
}

- (NSURL *)resolveAssetNamed:(NSString *)name
{
    if (!name)
        return nil;
    NSString *base = self.path.length ? self.path : [NSBundle mainBundle].resourcePath;
    if (!base)
        return nil;
    return [NSURL fileURLWithPath:[base stringByAppendingPathComponent:name]];
}

- (BOOL)canResolveAssetNamed:(NSString *)name
{
    NSURL *resolved = [self resolveAssetNamed:name];
    return resolved && [[NSFileManager defaultManager] fileExistsAtPath:resolved.path];
}

@end
