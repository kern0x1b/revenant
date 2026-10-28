local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function line_with(text, needle)
    for line in text:gmatch("[^\n]+") do
        if line:find(needle, 1, true) then
            return line
        end
    end
    assert(false, needle .. " is not in the lowered header")
end

local function refusal(sdk, out, modules)
    local message = nil
    try {
        function () lowered.overlay(sdk, out, nil, nil, modules) end,
        catch {
            function (errors) message = tostring(errors) end
        }
    }
    return message
end

function main()
    local sdk = workspace.sdk()
    local input = path.join(os.projectdir(), "build", "tests", "lowered-modules-input", "AsyncDisplayKit")
    os.rm(input)
    os.mkdir(input)
    io.writefile(path.join(input, "ASDisplayNode.h"), table.concat({
        "#import <UIKit/UIKit.h>",
        "",
        "@protocol ASGestureRecognizerDelegate <NSObject>",
        "@optional",
        "- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer API_AVAILABLE(ios(7.0));",
        "- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer API_AVAILABLE(ios(7.0));",
        "- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveEvent:(UIEvent *)event API_AVAILABLE(ios(13.4));",
        "@end",
        "",
        "@protocol ASScrollViewDelegate <NSObject>",
        "@optional",
        "- (void)scrollViewDidChangeAdjustedContentInset:(UIScrollView *)scrollView API_AVAILABLE(ios(11.0));",
        "- (NSAttributedString *)accessibilityAttributedScrollStatusForScrollView:(UIScrollView *)scrollView API_AVAILABLE(ios(11.0));",
        "@end",
        "",
    }, "\n"))
    local out = path.join(os.projectdir(), "build", "tests", "lowered-modules")
    os.rm(out)
    local vfs = io.readfile(lowered.overlay(sdk, out, nil, nil, {AsyncDisplayKit = input}))
    local copy = path.join(out, "modules", "AsyncDisplayKit", "ASDisplayNode.h")
    assert(vfs:find('"name": "' .. input .. '", "type": "directory"', 1, true), "the overlay does not map the AsyncDisplayKit directory, so the placed header is not served to the compiler")
    assert(vfs:find('{"name": "ASDisplayNode.h", "type": "file", "external-contents": "' .. copy .. '"}', 1, true), "the overlay does not map ASDisplayNode.h to its lowered copy")
    assert(os.isfile(copy), "the lowered copy of ASDisplayNode.h is not in the overlay")
    local header = io.readfile(copy)
    assert(not line_with(header, "shouldRequireFailureOfGestureRecognizer:"):find("API_AVAILABLE", 1, true), "shouldRequireFailureOfGestureRecognizer: is consulted by the backports, so its iOS 7 availability must be lowered")
    assert(not line_with(header, "shouldBeRequiredToFailByGestureRecognizer:"):find("API_AVAILABLE", 1, true), "shouldBeRequiredToFailByGestureRecognizer: is consulted by the backports, so its iOS 7 availability must be lowered")
    assert(not line_with(header, "scrollViewDidChangeAdjustedContentInset:"):find("API_AVAILABLE", 1, true), "scrollViewDidChangeAdjustedContentInset: is consulted by the backports, so its iOS 11 availability must be lowered")
    assert(line_with(header, "shouldReceiveEvent:"):find("API_AVAILABLE(ios(13.4))", 1, true), "shouldReceiveEvent: is not consulted by the backports, so its availability must stay")
    assert(line_with(header, "accessibilityAttributedScrollStatusForScrollView:"):find("API_AVAILABLE(ios(11.0))", 1, true), "accessibilityAttributedScrollStatusForScrollView: has no backport that consults it, so its availability must stay")
    local unnamed = refusal(sdk, out, {NotAModule = input})
    assert(unnamed and unnamed:find("is not a lowered third-party module", 1, true), "an unnamed module is accepted by the overlay")
    local missing = path.join(os.projectdir(), "build", "tests", "lowered-modules-empty")
    os.rm(missing)
    os.mkdir(missing)
    local absent = refusal(sdk, out, {AsyncDisplayKit = missing})
    assert(absent and absent:find("has no header", 1, true), "a module without its named header is accepted by the overlay")
    local parsed = lowered.third_party_modules("AsyncDisplayKit=" .. input .. "; ")
    assert(parsed.AsyncDisplayKit == input, "apple_lowered_modules does not parse name=directory entries")
    assert(#table.orderkeys(lowered.third_party_modules(nil)) == 0, "an unset apple_lowered_modules places modules")
end
