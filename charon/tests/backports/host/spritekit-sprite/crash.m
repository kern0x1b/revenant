#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <SpriteKit/SpriteKit.h>
#include <string.h>
#include <stdio.h>
int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    const char *c = argc > 1 ? argv[1] : "";
    @try {
        if (!strcmp(c, "rect-nil-base")) {
            id none = nil;
            SKTexture *t = [SKTexture textureWithRect:CGRectMake(0, 0, 0.5, 0.5) inTexture:none];
            printf("returned %p\n", (__bridge void *)t);
        } else if (!strcmp(c, "data-short")) {
            SKTexture *t = [SKTexture textureWithData:[NSMutableData dataWithLength:8] size:CGSizeMake(4, 4)];
            printf("returned size=(%g,%g) rect=(%g,%g,%g,%g)\n", t.size.width, t.size.height, t.textureRect.origin.x, t.textureRect.origin.y, t.textureRect.size.width, t.textureRect.size.height);
        } else if (!strcmp(c, "data-nil")) {
            id none = nil;
            SKTexture *t = [SKTexture textureWithData:none size:CGSizeMake(4, 4)];
            printf("returned %p\n", (__bridge void *)t);
        } else if (!strcmp(c, "sprite-neg-color")) {
            SKSpriteNode *s = [SKSpriteNode spriteNodeWithColor:[NSColor redColor] size:CGSizeMake(-2, 3)];
            printf("returned size=(%g,%g)\n", s.size.width, s.size.height);
        } else if (!strcmp(c, "sprite-neg-texture-size")) {
            SKTexture *t = [SKTexture textureWithData:[NSMutableData dataWithLength:64] size:CGSizeMake(4, 4)];
            SKSpriteNode *s = [SKSpriteNode spriteNodeWithTexture:t size:CGSizeMake(-1, 1)];
            printf("returned size=(%g,%g)\n", s.size.width, s.size.height);
        } else if (!strcmp(c, "sprite-neg-init")) {
            SKSpriteNode *s = [[SKSpriteNode alloc] initWithColor:[NSColor redColor] size:CGSizeMake(0, -4)];
            printf("returned size=(%g,%g)\n", s.size.width, s.size.height);
        } else if (!strcmp(c, "tex-color-neg")) {
            SKTexture *t = [SKTexture textureWithData:[NSMutableData dataWithLength:64] size:CGSizeMake(4, 4)];
            SKSpriteNode *s = [[SKSpriteNode alloc] initWithTexture:t color:[NSColor redColor] size:CGSizeMake(2, -2)];
            printf("returned size=(%g,%g)\n", s.size.width, s.size.height);
        } else if (!strcmp(c, "tex-size-zero-height")) {
            SKTexture *t = [SKTexture textureWithData:[NSMutableData dataWithLength:64] size:CGSizeMake(4, 4)];
            SKSpriteNode *s = [SKSpriteNode spriteNodeWithTexture:t size:CGSizeMake(0, -3)];
            printf("returned size=(%g,%g)\n", s.size.width, s.size.height);
        } else if (!strcmp(c, "copy-mip")) {
            SKTexture *t = [SKTexture textureWithData:[NSMutableData dataWithLength:64] size:CGSizeMake(4, 4)];
            t.usesMipmaps = YES; t.filteringMode = SKTextureFilteringNearest;
            SKTexture *k = [t copy];
            printf("copy mip=%d filter=%ld rect=(%g,%g,%g,%g)\n", k.usesMipmaps, (long)k.filteringMode, k.textureRect.origin.x, k.textureRect.origin.y, k.textureRect.size.width, k.textureRect.size.height);
        } else {
            printf("unknown case\n");
        }
    } @catch (NSException *e) {
        printf("exception name=%s reason=%s\n", [e.name UTF8String], [e.reason UTF8String]);
    }
    return 0;
}
