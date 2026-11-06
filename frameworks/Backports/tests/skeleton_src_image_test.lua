local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local skeleton = import("skeleton", {rootdir = tools, anonymous = true})

local COREML = "/System/Library/Frameworks/CoreML.framework/CoreML"

function main()
    local name = "MLModelCollectionDidChangeNotification"
    assert(skeleton.src_only_image({[name] = "/usr/lib/libX.dylib"}, name, "CoreML", true) == "/usr/lib/libX.dylib",
        "an SDK .tbd export must win over the framework binary")
    assert(skeleton.src_only_image({}, name, "CoreML", true) == COREML,
        "a symbol that no .tbd lists, sunset on iOS 27.2, must be looked up in its framework binary")
    local refused = false
    try {
        function ()
            skeleton.src_only_image({}, "kMissing", "NoSuchFramework", false)
        end,
        catch {
            function (error)
                refused = true
            end
        }
    }
    assert(refused, "a src folder that is not an SDK framework must still be refused")
    print("skeleton src images: a sunset symbol is looked up in its framework binary")
end
