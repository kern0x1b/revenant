local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")
local FIXTURES = path.join(os.scriptdir(), "sdk_fixture")

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local sdk = import("gen.sdk", {rootdir = TOOLS, anonymous = true})

    local good = sdk.discover(path.join(FIXTURES, "good"))
    check(good.name == "iphoneos9.9", "CanonicalName is the name: " .. tostring(good.name))
    check(good.version == "9.9", "Version is the version: " .. tostring(good.version))
    check(good.triple == "arm64e-apple-ios9.9", "the triple is built from DefaultDeploymentTarget: " .. tostring(good.triple))
    check(good.path == path.join(FIXTURES, "good"), "the path is the one given")

    local function failure_of(folder)
        local message = nil
        try {
            function ()
                sdk.discover(folder)
            end,
            catch {
                function (errors)
                    message = tostring(errors)
                end
            }
        }
        return message
    end
    local message = failure_of(path.join(FIXTURES, "no-version"))
    check(message ~= nil and string.find(message, "no Version in", 1, true) ~= nil, "a missing Version fails naming the file: " .. tostring(message))
    message = failure_of(path.join(FIXTURES, "absent"))
    check(message ~= nil and string.find(message, "not an SDK folder", 1, true) ~= nil, "a folder with no SDKSettings.json fails as not an SDK: " .. tostring(message))

    print("sdk test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)) .. " (" .. count .. " checks)")
    if failures > 0 then
        os.exit(1)
    end
end
