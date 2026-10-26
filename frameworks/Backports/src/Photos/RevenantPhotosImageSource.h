#ifndef REVENANT_PHOTOS_IMAGE_SOURCE_H
#define REVENANT_PHOTOS_IMAGE_SOURCE_H

#include <stdbool.h>

typedef enum {
    RevenantPhotosImageSourceNone,
    RevenantPhotosImageSourceThumbnail,
    RevenantPhotosImageSourceFullScreen,
    RevenantPhotosImageSourceFullResolution
} RevenantPhotosImageSource;

RevenantPhotosImageSource RevenantPhotosImageSourceForRequest(float requestedPixels, float thumbnailPixels, float screenPixels,
                                                               bool hasThumbnail, bool hasScreen, bool hasResolution, bool maximum);

#endif
