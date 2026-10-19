-- Test of the functions command's header rules: a nested framework's folder is inside its outer framework's Frameworks folder, and a
-- function an umbrella's nested target declares is read from that target's headers (Accelerate's vImage and vecLib), any other from the
-- umbrella's. The header rules are top-level functions of tools/gen/cmd_functions.lua; the folder rule is sdk_modules.discover, read from a
-- fixture folder the test builds. Run: xmake l tests/gen/functions_test.lua (exits 1 on any failure).

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local functions = import("gen.cmd_functions", {rootdir = TOOLS, anonymous = true})
local sdk_modules = import("gen.sdk_modules", {rootdir = TOOLS, anonymous = true})

local failures = 0
local function check(ok, label)
    if not ok then
        failures = failures + 1
        print("FAIL " .. label)
    end
end

-- A two-level framework folder built under the git-ignored .agent-work, so the SDK's own folder rule is read from real folders
local SDK = path.normalize(path.join(os.scriptdir(), "..", "..", ".agent-work", "functions-test", "sdk"))
local FRAMEWORKS = path.join(SDK, "System", "Library", "Frameworks")
os.tryrm(SDK)
os.mkdir(path.join(FRAMEWORKS, "Accelerate.framework", "Frameworks", "vImage.framework"))
local found = sdk_modules.discover(SDK).modules
check(found["Accelerate"] ~= nil and found["Accelerate"].root == path.join(FRAMEWORKS, "Accelerate.framework"),
      "a top-level framework is in the SDK's Frameworks folder")
check(found["Accelerate/vImage"] ~= nil
      and found["Accelerate/vImage"].root == path.join(FRAMEWORKS, "Accelerate.framework", "Frameworks", "vImage.framework"),
      "a nested framework is in its outer framework's Frameworks folder")

local nested = {
    {text = "VIMAGE", functions = {vImageScale = {type = "int"}}},
    {text = "VECLIB", functions = {vDSP_sve = {type = "int"}}},
}
check(functions.declaring_text(nested, "UMBRELLA", "vImageScale") == "VIMAGE", "a function vImage declares is read from vImage's headers")
check(functions.declaring_text(nested, "UMBRELLA", "vDSP_sve") == "VECLIB", "a function vecLib declares is read from vecLib's headers")
check(functions.declaring_text(nested, "UMBRELLA", "NoSuchFunction") == "UMBRELLA", "a function no nested target declares is read from the umbrella's headers")
check(functions.declaring_text({}, "UMBRELLA", "vImageScale") == "UMBRELLA", "an umbrella with no nested target reads its own headers")

print("functions test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
if failures > 0 then
    os.exit(1)
end
