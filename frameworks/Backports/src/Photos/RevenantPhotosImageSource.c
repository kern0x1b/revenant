#include "RevenantPhotosImageSource.h"

RevenantPhotosImageSource RevenantPhotosImageSourceForRequest(float requestedPixels, float thumbnailPixels, float screenPixels,
                                                               bool hasThumbnail, bool hasScreen, bool hasResolution, bool maximum)
{
    if (maximum)
        return hasResolution ? RevenantPhotosImageSourceFullResolution : hasScreen ? RevenantPhotosImageSourceFullScreen
                                                                                  : hasThumbnail ? RevenantPhotosImageSourceThumbnail : RevenantPhotosImageSourceNone;
    if (hasThumbnail && thumbnailPixels >= requestedPixels)
        return RevenantPhotosImageSourceThumbnail;
    if (hasScreen && screenPixels >= requestedPixels)
        return RevenantPhotosImageSourceFullScreen;
    if (hasResolution && hasScreen && requestedPixels > screenPixels)
        return RevenantPhotosImageSourceFullResolution;
    if (hasScreen)
        return RevenantPhotosImageSourceFullScreen;
    return hasThumbnail ? RevenantPhotosImageSourceThumbnail : RevenantPhotosImageSourceNone;
}
