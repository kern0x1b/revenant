#include "../revenant_impl.h"
#import "RevenantAVFoundationCaption18.h"
#import <AVFoundation/AVFoundation.h>

AVCaptionDimension BACKPORT_IMPL(AVCaptionDimensionMake)(CGFloat value, AVCaptionUnitsType units)
{
    AVCaptionDimension dimension;
    dimension.value = value;
    dimension.units = units;
    return dimension;
}

AVCaptionPoint BACKPORT_IMPL(AVCaptionPointMake)(AVCaptionDimension x, AVCaptionDimension y)
{
    AVCaptionPoint point;
    point.x = x;
    point.y = y;
    return point;
}

AVCaptionSize BACKPORT_IMPL(AVCaptionSizeMake)(AVCaptionDimension width, AVCaptionDimension height)
{
    AVCaptionSize size;
    size.width = width;
    size.height = height;
    return size;
}

NSString *BACKPORT_IMPL(AVCaptureReactionSystemImageNameForType)(AVCaptureReactionType reactionType)
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
    return nil;
}
