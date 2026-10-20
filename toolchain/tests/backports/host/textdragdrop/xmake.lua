set_project("textdragdrop")
set_version("0.0.1")
local root = os.getenv("DDR_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("revenant " .. root)
add_addons("revenant v0.8.14")
set_config("apple_minimum", "6.1.3")
includes("@addon/revenant/apple-ios")
includes("@addon/revenant/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

local ui = os.getenv("DDR_UIKIT") or path.join(root, "packages/frameworks/apple-backports/UIKit")
target("textdragdrop")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(root, "tests/backports/device/textdragdrop.m"),
              path.join(root, "tests/backports/device/check.m"),
              path.join(ui, "ViewDragDropRouting11.m"),
              path.join(ui, "RevenantDropSequence11.m"),
              path.join(ui, "RevenantDropCoordinatorObjects.m"),
              path.join(ui, "UIDropCoordinators.m"),
              path.join(ui, "UIDropSession.m"),
              path.join(ui, "UIDropProposal.m"),
              path.join(ui, "UIDropInteraction.m"),
              path.join(ui, "UIDragInteraction.m"),
              path.join(ui, "UIDragItem.m"),
              path.join(ui, "UITextView+TextDragDrop11.m"),
              path.join(ui, "UITextDragPreviewRenderer11.m"),
              path.join(ui, "RevenantDragDrop.m"),
              path.join(ui, "UIView+Interactions.m"),
              path.join(ui, "UICollectionView+DragDrop.m"),
              path.join(ui, "UITableView+DragDrop.m"),
              path.join(ui, "UICollectionViewDragDropIntegration.m"),
              path.join(ui, "UITableViewDragDropIntegration.m"))
    add_includedirs(path.join(root, "tests/backports/device"))
    add_includedirs(ui)
    add_mflags("-fobjc-arc", "-fvisibility=hidden", "-Wno-deprecated-declarations")
    add_ldflags("-fobjc-arc")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore")
    set_values("revenant.version", "1.0")
    set_values("revenant.control", "control")
    set_values("revenant.waive.weak-imports",
        "measurement harness, not a released image: the iOS 11 types it names are each used behind a class test")
