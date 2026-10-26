local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local frameworks = path.join(workspace.sdk(), "System", "Library", "Frameworks")

local function header(framework, name)
    return io.readfile(path.join(frameworks, framework .. ".framework", "Headers", name))
end

local function source(relative)
    return io.readfile(path.join(backports, relative))
end

local function contains(text, needle, label)
    assert(text:find(needle, 1, true), label .. " does not contain " .. needle)
end

function main()
    local photosPicker = source("src/Photos/PHPickerViewController14.m")
    local photosResult = source("src/Photos/PHPickerResult14.m")
    contains(photosPicker, "UIImagePickerControllerSourceTypePhotoLibrary", "the PhotosUI picker adapter")
    contains(photosPicker, "availableMediaTypesForSourceType", "the PhotosUI picker adapter")
    contains(photosPicker, "registerDataRepresentationForTypeIdentifier", "the PhotosUI image result")
    contains(photosPicker, "registerFileRepresentationForTypeIdentifier", "the PhotosUI video result")
    contains(photosPicker, "picker:didFinishPicking:", "the PhotosUI picker delegate")
    contains(photosResult, "- (NSString *)assetIdentifier", "the PhotosUI result")

    local visionHandlers = source("src/Vision/VNHandlers.m")
    contains(visionHandlers, "#import <CoreImage/CoreImage.h>", "the Core Image Vision request implementation")
    contains(visionHandlers, "VNErrorUnsupportedRequest", "unavailable Vision requests")
    contains(visionHandlers, "is not supported on this release", "unavailable Vision request errors")
    contains(visionHandlers, "CIDetectorTypeFace", "the iOS 6 Core Image face detector")
    contains(visionHandlers, "VNDetectFaceRectanglesRequest", "the Vision face rectangle request")
    contains(visionHandlers, "CIDetectorImageOrientation", "the Vision face request orientation")

    local vision = header("VisionKit", "VNDocumentCameraViewController.h")
    local visionImpl = source("src/VisionKit/VNDocumentCameraViewController.m")
    contains(vision, "isSupported", "the SDK VisionKit header")
    contains(vision, "didFailWithError:", "the SDK VisionKit delegate")
    contains(visionImpl, "isSupported", "the VisionKit backport")
    contains(visionImpl, "didFailWithError:error", "the VisionKit backport")

    local foundationHasCode = false
    for _, file in ipairs(os.files(path.join(frameworks, "Foundation.framework", "Headers", "*.h"))) do
        if io.readfile(file):find("NSFeatureUnsupportedError", 1, true) then
            foundationHasCode = true
            break
        end
    end
    assert(foundationHasCode, "the SDK Foundation headers do not declare NSFeatureUnsupportedError")
    contains(visionImpl, "NSFeatureUnsupportedError", "the VisionKit backport")

    contains(header("BackgroundTasks", "BGTaskScheduler.h"), "BGTaskSchedulerErrorCodeUnavailable", "the SDK scheduler header")
    contains(header("BackgroundTasks", "BGTaskRequest.h"), "@interface BGContinuedProcessingTaskRequest", "the SDK request header")
    contains(header("BackgroundTasks", "BGTask.h"), "@interface BGContinuedProcessingTask", "the SDK task header")
    local continued = source("src/BackgroundTasks/BGContinuedProcessing.m")
    contains(continued, "@implementation BGContinuedProcessingTaskRequest", "the BackgroundTasks backport")
    contains(continued, "@implementation BGContinuedProcessingTask", "the BackgroundTasks backport")
    contains(source("src/BackgroundTasks/BGTaskScheduler.m"), "BGTaskSchedulerErrorCodeUnavailable", "the BackgroundTasks backport")
end
