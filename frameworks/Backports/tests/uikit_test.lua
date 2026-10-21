local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local implemented = import("implemented", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local workspace = import("workspace", {rootdir = path.absolute(path.join(os.scriptdir(), "..", "..", "..", "toolchain", "modules")), anonymous = true})

local AREAS = {
    {
        name = "text tabs, constraint identifiers and screen snapshots",
        sources = {"NSTextTab.m", "NSLayoutConstraint+Identifier7.m", "UIScreen+Snapshot7.m"},
        members = {
            "-[NSTextTab initWithTextAlignment:location:options:]", "-[NSTextTab alignment]", "-[NSTextTab location]", "-[NSTextTab options]",
            "-[NSLayoutConstraint identifier]", "-[UIScreen snapshotViewAfterScreenUpdates:]",
        },
    },
    {
        name = "background fetch, dynamic type and state restoration",
        sources = {"UIApplication+BackgroundFetch7.m", "UIApplication+ContentSize7.m", "UIApplication+StateRestoration7.m", "UIViewController+StateRestoration7.m"},
        members = {
            "-[UIApplication setMinimumBackgroundFetchInterval:]", "-[UIApplication backgroundRefreshStatus]", "-[UIApplication preferredContentSizeCategory]",
            "+[UIApplication registerObjectForStateRestoration:restorationIdentifier:]", "-[UIViewController applicationFinishedRestoringState]",
        },
    },
    {
        name = "bar positions, tab bar layout and the iOS 7 bar members",
        sources = {"RevenantWeak.m", "UINavigationBar+BarPosition7.m", "UISearchBar+BarPosition7.m", "UIToolbar+BarPosition7.m", "UITabBar+Layout7.m", "UITabBarItem+SelectedImage7.m"},
        members = {
            "-[UINavigationBar setBackgroundImage:forBarPosition:barMetrics:]", "-[UINavigationBar backgroundImageForBarPosition:barMetrics:]",
            "-[UISearchBar setBackgroundImage:forBarPosition:barMetrics:]", "-[UISearchBar backgroundImageForBarPosition:barMetrics:]",
            "-[UIToolbar delegate]", "-[UITabBar itemPositioning]", "-[UITabBar itemWidth]", "-[UITabBar itemSpacing]", "-[UITabBar barStyle]",
            "-[UITabBar translucent]", "-[UITabBarItem initWithTitle:image:selectedImage:]",
        },
    },
    {
        name = "text, accessibility, print and gesture members of iOS 7",
        sources = {"NSAttributedString+FileURL7.m", "NSObject+AccessibilityPath7.m", "UIGestureRecognizer+Failure7.m", "UIPrintInteractionController+Options7.m",
                   "UIResponder+TextInput7.m", "UISearchDisplayController+NavigationBar7.m", "UISimpleTextPrintFormatter+Attributed7.m"},
        members = {
            "-[NSAttributedString initWithFileURL:options:documentAttributes:error:]", "-[NSMutableAttributedString readFromFileURL:options:documentAttributes:error:]",
            "-[NSObject accessibilityPath]", "-[UIGestureRecognizer shouldRequireFailureOfGestureRecognizer:]",
            "-[UIGestureRecognizer shouldBeRequiredToFailByGestureRecognizer:]", "-[UIPrintInteractionController showsNumberOfCopies]",
            "-[UIResponder textInputMode]", "-[UIResponder textInputContextIdentifier]", "+[UIResponder clearTextInputContextIdentifier:]",
            "-[UISearchDisplayController displaysSearchBarInNavigationBar]", "-[UISearchDisplayController navigationItem]",
            "-[UISimpleTextPrintFormatter initWithAttributedText:]", "-[UISimpleTextPrintFormatter attributedText]",
        },
    },
}

local function key_of(member)
    local sign, class, selector = member:match("^([%+%-])%[(%S+) ([^%]]+)%]$")
    assert(sign, "not a member: " .. member)
    return (sign == "+" and "class method" or "instance method") .. "|" .. class .. "|" .. selector
end

function main()
    local sdk = os.getenv("REVENANT_GEN_SDK")
    if not sdk or sdk == "" then
        sdk = sdkfiles.sdk_folder()
    end
    local sources = path.absolute(path.join(os.scriptdir(), "..", "src", "UIKit"))
    local root = path.join(workspace.home(), "cache", "uikit-test")
    os.tryrm(root)
    local objects, total = 0, 0
    for _, area in ipairs(AREAS) do
        for _, name in ipairs(area.sources) do
            local object = path.join(root, "UIKit", "src", "UIKit", name .. ".o")
            os.mkdir(path.directory(object))
            os.vrunv("clang", {"-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-fobjc-arc", "-Os", "-w", "-c", "-o", object,
                path.join(sources, name)})
            objects = objects + 1
        end
    end
    local keys = implemented.from_objects(root).UIKit or {}
    local missing = {}
    for _, area in ipairs(AREAS) do
        for _, member in ipairs(area.members) do
            total = total + 1
            if not keys[key_of(member)] then
                table.insert(missing, area.name .. ": " .. member)
            end
        end
    end
    assert(#missing == 0, "members not implemented by the compiled UIKit objects:\n" .. table.concat(missing, "\n"))
    os.tryrm(root)
    print("uikit tests passed: " .. total .. " members implemented by " .. objects .. " objects in " .. #AREAS .. " areas")
end
