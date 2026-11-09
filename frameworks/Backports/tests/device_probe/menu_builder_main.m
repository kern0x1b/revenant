#import <UIKit/UIKit.h>
#import "check.h"
#import "../../src/UIKit/RevenantMenus.h"

extern const UIMenuIdentifier __revenant_fb_UIMenuReplace;
extern const UIMenuIdentifier __revenant_fb_UIMenuLookup;
extern const UIMenuIdentifier __revenant_fb_UIMenuShare;
extern const UIMenuIdentifier __revenant_fb_UIMenuRoot;

static NSString *revenant_titles(NSArray<UIMenuElement *> *elements)
{
    NSMutableArray *titles = [NSMutableArray array];
    for (UIMenuElement *element in elements)
        [titles addObject:element.title];
    return [titles componentsJoinedByString:@","];
}

static UIMenu *revenant_menu(NSString *title, NSString *identifier, NSArray<UIMenuElement *> *children)
{
    return [UIMenu menuWithTitle:title image:nil identifier:identifier options:0 children:children];
}

static UIAction *revenant_action(NSString *title, NSString *identifier)
{
    return [UIAction actionWithTitle:title image:nil identifier:identifier handler:^(UIAction *fired) {}];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        UIAction *cut = revenant_action(@"Cut", @"org.test.cut");
        UIAction *copy = revenant_action(@"Copy", @"org.test.copy");
        UIMenu *edit = revenant_menu(@"Edit", @"org.test.edit", @[cut, copy]);
        UIMenu *replace = revenant_menu(@"Replace", __revenant_fb_UIMenuReplace, @[]);
        UIMenu *lookup = revenant_menu(@"Lookup", __revenant_fb_UIMenuLookup, @[revenant_action(@"Define", @"org.test.define")]);
        UIMenu *share = revenant_menu(@"Share", __revenant_fb_UIMenuShare, @[]);
        UICommand *command = [UICommand commandWithTitle:@"Paste" image:nil action:@selector(description) propertyList:@"list" alternates:@[]];

        RevenantMenuBuilder *builder = [[RevenantMenuBuilder alloc] initWithSystem:[UIMenuSystem mainSystem] menus:@[edit, replace, lookup, share, command]];
        revenant_check((builder.system == [UIMenuSystem mainSystem] && [builder.root.identifier isEqualToString:__revenant_fb_UIMenuRoot] && [revenant_titles(builder.root.children) isEqualToString:@"Edit,Replace,Lookup,Share,Paste"]) != revenant_negative,
                       "a builder starts with the menus it is given under the root", revenant_titles(builder.root.children));
        revenant_check(([builder menuForIdentifier:__revenant_fb_UIMenuLookup].title != nil && [builder menuForIdentifier:@"org.test.none"] == nil && [builder menuForIdentifier:__revenant_fb_UIMenuRoot] == builder.root) != revenant_negative,
                       "a menu is found by identifier at any depth, the root by its own, and a missing one is nil", @"");
        revenant_check(([builder actionForIdentifier:@"org.test.define"] != nil && [builder actionForIdentifier:@"org.test.none"] == nil
                        && [builder commandForAction:@selector(description) propertyList:@"list"] == command && [builder commandForAction:@selector(description) propertyList:@"other"] == nil) != revenant_negative,
                       "an action is found by identifier inside a menu and a command by action and property list", @"");

        [builder removeMenuForIdentifier:__revenant_fb_UIMenuReplace];
        [builder removeMenuForIdentifier:__revenant_fb_UIMenuLookup];
        [builder removeMenuForIdentifier:__revenant_fb_UIMenuShare];
        revenant_check(([revenant_titles(builder.root.children) isEqualToString:@"Edit,Paste"] && [builder actionForIdentifier:@"org.test.define"] == nil) != revenant_negative,
                       "removing menus takes them and what they hold out of the tree", revenant_titles(builder.root.children));

        [builder removeActionForIdentifier:@"org.test.cut"];
        revenant_check(([revenant_titles([builder menuForIdentifier:@"org.test.edit"].children) isEqualToString:@"Copy"] && [[builder menuForIdentifier:@"org.test.edit"].identifier isEqualToString:@"org.test.edit"]) != revenant_negative,
                       "removing an action takes it out of its parent, which keeps its identity", revenant_titles([builder menuForIdentifier:@"org.test.edit"].children));

        [builder insertSiblingMenu:revenant_menu(@"Before", @"org.test.before", @[]) beforeMenuForIdentifier:@"org.test.edit"];
        [builder insertSiblingMenu:revenant_menu(@"After", @"org.test.after", @[]) afterMenuForIdentifier:@"org.test.edit"];
        revenant_check(([revenant_titles(builder.root.children) isEqualToString:@"Before,Edit,After,Paste"]) != revenant_negative, "sibling menus go before and after an identified menu", revenant_titles(builder.root.children));

        [builder insertChildMenu:revenant_menu(@"First", @"org.test.first", @[]) atStartOfMenuForIdentifier:@"org.test.edit"];
        [builder insertChildMenu:revenant_menu(@"Last", @"org.test.last", @[]) atEndOfMenuForIdentifier:@"org.test.edit"];
        revenant_check(([revenant_titles([builder menuForIdentifier:@"org.test.edit"].children) isEqualToString:@"First,Copy,Last"]) != revenant_negative, "child menus go at the start and at the end of an identified menu", revenant_titles([builder menuForIdentifier:@"org.test.edit"].children));

        [builder insertElements:@[revenant_action(@"Mid", @"org.test.mid")] afterActionForIdentifier:@"org.test.copy"];
        [builder replaceChildrenOfMenuForIdentifier:@"org.test.after" fromChildrenBlock:^NSArray<UIMenuElement *> *(NSArray<UIMenuElement *> *old) {
            return [old arrayByAddingObject:revenant_action(@"Added", @"org.test.added")];
        }];
        revenant_check(([revenant_titles([builder menuForIdentifier:@"org.test.edit"].children) isEqualToString:@"First,Copy,Mid,Last"] && [revenant_titles([builder menuForIdentifier:@"org.test.after"].children) isEqualToString:@"Added"]) != revenant_negative,
                       "elements go after an identified action, and a menu's children are replaced from its old ones", revenant_titles([builder menuForIdentifier:@"org.test.edit"].children));

        [builder replaceMenuForIdentifier:@"org.test.before" withMenu:revenant_menu(@"Swapped", @"org.test.swapped", @[])];
        [builder insertElements:@[revenant_action(@"Head", @"org.test.head")] atStartOfMenuForIdentifier:__revenant_fb_UIMenuRoot];
        [builder removeCommandForAction:@selector(description) propertyList:@"list"];
        revenant_check(([revenant_titles(builder.root.children) isEqualToString:@"Head,Swapped,Edit,After"]) != revenant_negative, "a menu is replaced in place, elements go at the start of the root, and a command is removed", revenant_titles(builder.root.children));

        UIMenu *before = builder.root;
        [builder removeMenuForIdentifier:@"org.test.none"];
        revenant_check((builder.root == before) != revenant_negative, "removing a menu that is not there leaves the tree as it is", @"");
    }
    return revenant_finish();
}
