import UIKit

// The swipe actions of later iOS (UIContextualAction, UISwipeActionsConfiguration) are not in iOS 6, but the backports
// carry them and hand them to the table's delegate like the release does. They are looked up by name at run time, so
// the module still builds and runs on a phone without the backports, where the native Delete button is used instead.
enum SwipeActionsBridge {
    static var available: Bool {
        NSClassFromString("UISwipeActionsConfiguration") != nil && NSClassFromString("UIContextualAction") != nil
    }

    typealias Completion = @convention(block) (Bool) -> Void
    typealias Handler = @convention(block) (AnyObject, AnyObject, Completion) -> Void

    static func configuration(for buttons: [SwipeButton], fullSwipe: Bool) -> AnyObject? {
        guard available, !buttons.isEmpty,
              let actionClass = NSClassFromString("UIContextualAction") as? NSObject.Type,
              let configurationClass = NSClassFromString("UISwipeActionsConfiguration") as? NSObject.Type else { return nil }
        typealias MakeAction = @convention(c) (AnyClass, Selector, Int, NSString, AnyObject) -> Unmanaged<AnyObject>?
        typealias MakeConfiguration = @convention(c) (AnyClass, Selector, NSArray) -> Unmanaged<AnyObject>?
        let makeAction = NSSelectorFromString("contextualActionWithStyle:title:handler:")
        let makeConfiguration = NSSelectorFromString("configurationWithActions:")
        guard actionClass.responds(to: makeAction), configurationClass.responds(to: makeConfiguration) else { return nil }
        let actionMaker = unsafeBitCast(actionClass.method(for: makeAction), to: MakeAction.self)
        let configurationMaker = unsafeBitCast(configurationClass.method(for: makeConfiguration), to: MakeConfiguration.self)

        var actions: [AnyObject] = []
        for button in buttons {
            let handler: Handler = { _, _, completion in
                button.action()
                completion(true)
            }
            guard let action = actionMaker(actionClass, makeAction, button.destructive ? 1 : 0, button.title as NSString,
                                           unsafeBitCast(handler, to: AnyObject.self))?.takeUnretainedValue() else { continue }
            let color = button.tint ?? (button.destructive ? UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1) : UIColor(white: 0.6, alpha: 1))
            (action as? NSObject)?.setValue(color, forKey: "backgroundColor")
            actions.append(action)
        }
        guard !actions.isEmpty, let configuration = configurationMaker(configurationClass, makeConfiguration, actions as NSArray)?.takeUnretainedValue() else { return nil }
        (configuration as? NSObject)?.setValue(NSNumber(value: fullSwipe), forKey: "performsFirstActionWithFullSwipe")
        return configuration
    }
}

// The delegate methods are added to the controller at run time: the SDK declares them with types of iOS 11, which this
// module cannot name, and the backports look for them by selector.
extension ListController {
    nonisolated(unsafe) private static var registered = false
    nonisolated(unsafe) static var swipeQueries: [String] = []

    static func registerSwipeActions() {
        guard !registered, SwipeActionsBridge.available else { return }
        registered = true
        typealias Method = @convention(block) (AnyObject, AnyObject, NSIndexPath) -> AnyObject?
        let trailing: Method = { controller, _, path in
            ListController.swipeQueries.append("trailing \(path.row)")
            guard let controller = controller as? ListController, let row = controller.node?.row(at: path as IndexPath),
                  let buttons = row.traits.trailingSwipe else { return nil }
            return SwipeActionsBridge.configuration(for: buttons, fullSwipe: row.traits.trailingFullSwipe)
        }
        let leading: Method = { controller, _, path in
            ListController.swipeQueries.append("leading \(path.row)")
            guard let controller = controller as? ListController, let row = controller.node?.row(at: path as IndexPath),
                  let buttons = row.traits.leadingSwipe else { return nil }
            return SwipeActionsBridge.configuration(for: buttons, fullSwipe: row.traits.leadingFullSwipe)
        }
        for (name, method) in [("tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:", trailing),
                               ("tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:", leading)] {
            class_addMethod(ListController.self, NSSelectorFromString(name), imp_implementationWithBlock(unsafeBitCast(method, to: AnyObject.self)), "@@:@@")
        }
    }
}
