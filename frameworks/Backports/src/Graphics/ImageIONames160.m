#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

extern CFStringRef const kCGImagePropertyGroupImageBaseline;
extern CFStringRef const kCGImagePropertyGroupImageDisparityAdjustment;
extern CFStringRef const kIIOCameraExtrinsics_CoordinateSystemID;
extern CFStringRef const kIIOCameraExtrinsics_Position;
extern CFStringRef const kIIOCameraExtrinsics_Rotation;
extern CFStringRef const kIIOCameraModelType_GenericPinhole;
extern CFStringRef const kIIOCameraModelType_SimplifiedPinhole;
extern CFStringRef const kIIOCameraModel_Intrinsics;
extern CFStringRef const kIIOCameraModel_ModelType;
extern CFStringRef const kIIOMetadata_CameraExtrinsicsKey;
extern CFStringRef const kIIOMetadata_CameraModelKey;

CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupImageBaseline) = CFSTR("GroupImageBaseline");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupImageDisparityAdjustment) = CFSTR("GroupImageDisparityAdjustment");
CFStringRef const BACKPORT_IMPL(kIIOCameraExtrinsics_CoordinateSystemID) = CFSTR("CoordinateSystemID");
CFStringRef const BACKPORT_IMPL(kIIOCameraExtrinsics_Position) = CFSTR("Position");
CFStringRef const BACKPORT_IMPL(kIIOCameraExtrinsics_Rotation) = CFSTR("Rotation");
CFStringRef const BACKPORT_IMPL(kIIOCameraModelType_GenericPinhole) = CFSTR("GenericPinhole");
CFStringRef const BACKPORT_IMPL(kIIOCameraModelType_SimplifiedPinhole) = CFSTR("SimplifiedPinhole");
CFStringRef const BACKPORT_IMPL(kIIOCameraModel_Intrinsics) = CFSTR("Intrinsics");
CFStringRef const BACKPORT_IMPL(kIIOCameraModel_ModelType) = CFSTR("ModelType");
CFStringRef const BACKPORT_IMPL(kIIOMetadata_CameraExtrinsicsKey) = CFSTR("CameraExtrinsics");
CFStringRef const BACKPORT_IMPL(kIIOMetadata_CameraModelKey) = CFSTR("CameraModel");
