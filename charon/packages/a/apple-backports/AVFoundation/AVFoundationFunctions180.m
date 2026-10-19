#import "CharonAVFoundationCaption18.h"
#import <AVFoundation/AVFoundation.h>

// The caption geometry constructors and the reaction system's image names, one release's worth: an
// object may only hold API of one release, and which release that is was measured - the three
// constructors and AVCaptureReactionSystemImageNameForType are all first EXPORTED by the 18.0 cache
// (tools/symbol-first-release.lua over the held ladder), even though the header calls the reaction
// function iOS 17.0, because the ladder holds no cache between 12.0 and 16.0 and none above 18.0.
//
// The three constructors build a struct out of their two arguments and there is nothing else they could
// do: each field holds exactly what it was handed. The host's own symbols were asked over a spread of
// arguments - five values including 0, 1, 42.5, 100 and -3.25, against each of the three units, and
// three mixed-unit pairs - and returned the arguments unchanged every time
// (facts/AVFoundation/Functions.md has the run). They are written that way here, not by copying the
// host: a struct with two fields has one answer, and the host is what says which.
//
// AVCaptureReactionSystemImageNameForType is a lookup in Apple's own table of SF Symbol names, and that
// table is not something this repository can derive: it is the eight names below, each read out of the
// host's own function by calling it with the reaction type that AVFoundationGlobals180.m carries. The
// reaction TYPE constants are referenced, not written out again, so there is one copy of each string in
// the tree.
AVCaptionDimension AVCaptionDimensionMake(CGFloat value, AVCaptionUnitsType units)
{
    AVCaptionDimension dimension;
    dimension.value = value;
    dimension.units = units;
    return dimension;
}

AVCaptionPoint AVCaptionPointMake(AVCaptionDimension x, AVCaptionDimension y)
{
    AVCaptionPoint point;
    point.x = x;
    point.y = y;
    return point;
}

AVCaptionSize AVCaptionSizeMake(AVCaptionDimension width, AVCaptionDimension height)
{
    AVCaptionSize size;
    size.width = width;
    size.height = height;
    return size;
}

NSString *AVCaptureReactionSystemImageNameForType(AVCaptureReactionType reactionType)
{
    if ([reactionType isEqualToString:AVCaptureReactionTypeBalloons]) {
        return @"balloon.2.fill";
    }
    if ([reactionType isEqualToString:AVCaptureReactionTypeConfetti]) {
        return @"party.popper.fill";
    }
    if ([reactionType isEqualToString:AVCaptureReactionTypeFireworks]) {
        return @"fireworks";
    }
    if ([reactionType isEqualToString:AVCaptureReactionTypeHeart]) {
        return @"heart.fill";
    }
    if ([reactionType isEqualToString:AVCaptureReactionTypeLasers]) {
        return @"laser.burst";
    }
    if ([reactionType isEqualToString:AVCaptureReactionTypeRain]) {
        return @"cloud.rain.fill";
    }
    if ([reactionType isEqualToString:AVCaptureReactionTypeThumbsUp]) {
        return @"hand.thumbsup.fill";
    }
    if ([reactionType isEqualToString:AVCaptureReactionTypeThumbsDown]) {
        return @"hand.thumbsdown.fill";
    }
    // A reaction type this port does not carry has no image name, and nil is what a lookup that finds
    // nothing returns. There is no ninth name to fall back on: the table has one entry per type.
    return nil;
}