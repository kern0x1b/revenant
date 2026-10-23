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
