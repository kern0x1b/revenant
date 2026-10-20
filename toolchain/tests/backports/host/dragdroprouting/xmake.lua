set_project("dragdroprouting")
set_version("0.0.1")
local root = os.getenv("DDR_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("revenant " .. root)
add_addons("revenant v0.8.13")
set_config("apple_minimum", "6.1.3")
includes("@addon/revenant/apple-ios")
includes("@addon/revenant/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

if os.getenv("DDR_ROOT") and os.getenv("DDR_ROOT") ~= "" then root = os.getenv("DDR_ROOT") end
local ui = os.getenv("DDR_UIKIT") or path.join(root, "packages/frameworks/apple-backports/UIKit")
target("dragdroprouting")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(ui, "ViewDragDropRouting11.m"),
              path.join(ui, "UIView+Interactions.m"),
              path.join(ui, "RevenantDropSequence11.m"),
              path.join(ui, "RevenantDropCoordinatorObjects.m"),
              path.join(ui, "UIDropCoordinators.m"),
              path.join(ui, "RevenantDragDrop.m"),
              path.join(ui, "UIDragItem.m"),
              path.join(ui, "UIDropSession.m"),
              path.join(ui, "UIDropProposal.m"),
              path.join(ui, "UIDropInteraction.m"),
              path.join(ui, "UIDragInteraction.m"),
              path.join(ui, "UICollectionView+DragDrop.m"),
              path.join(ui, "UITableView+DragDrop.m"),
              path.join(ui, "UICollectionViewDragDropIntegration.m"),
              path.join(ui, "UITableViewDragDropIntegration.m"),
              path.join(root, "tests/backports/device/dragdroprouting.m"),
              path.join(root, "tests/backports/device/check.m"))
    add_includedirs(path.join(root, "tests/backports/device"))
    add_includedirs(ui)
    add_mflags("-fobjc-arc", "-fvisibility=hidden", "-Wno-deprecated-declarations")
    add_ldflags("-fobjc-arc")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore")
    set_values("revenant.version", "1.0")
    set_values("revenant.control", "control")
    set_values("revenant.waive.weak-imports",
        "measurement harness, not a released image: UIPreviewParameters, UIPreviewTarget, UITargetedPreview and NSItemProvider are each used only behind a class test, in the port's own preview code")
