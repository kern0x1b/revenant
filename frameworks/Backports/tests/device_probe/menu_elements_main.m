#import <UIKit/UIKit.h>
#import "check.h"

static NSString *revenant_describe(id value)
{
    return [NSString stringWithFormat:@"%@", value];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        UIImage *image = [[UIImage alloc] init];
        UIImage *selected = [[UIImage alloc] init];

        UIAction *action = [UIAction actionWithTitle:@"Quote" image:image identifier:@"org.test.quote" handler:^(UIAction *fired) {}];
        action.subtitle = @"Format";
        action.discoverabilityTitle = @"Quote text";
        revenant_check(([action.subtitle isEqualToString:@"Format"] && action.selectedImage == nil) != revenant_negative, "an action keeps its subtitle and has no selected image at first", revenant_describe(action.subtitle));
        [action setSelectedImage:selected];
        UIAction *action_copy = [action copy];
        revenant_check(([action_copy.subtitle isEqualToString:@"Format"] && action_copy.selectedImage == selected && [action_copy.discoverabilityTitle isEqualToString:@"Quote text"]
                        && [action_copy.identifier isEqualToString:@"org.test.quote"]) != revenant_negative,
                       "a copied action keeps its subtitle, selected image, discoverability title and identifier", revenant_describe(action_copy.subtitle));

        UIMenu *menu = [UIMenu menuWithTitle:@"Replace" image:image identifier:@"org.test.replace" options:UIMenuOptionsDisplayInline children:@[action]];
        revenant_check((menu.subtitle == nil && menu.preferredElementSize == UIMenuElementSizeAutomatic) != revenant_negative, "a menu has no subtitle and the automatic element size at first", revenant_describe(@(menu.preferredElementSize)));
        menu.subtitle = @"Choices";
        menu.preferredElementSize = UIMenuElementSizeSmall;
        UIMenu *replaced = [menu menuByReplacingChildren:@[]];
        UIMenu *menu_copy = [menu copy];
        revenant_check(([replaced.subtitle isEqualToString:@"Choices"] && replaced.preferredElementSize == UIMenuElementSizeSmall && replaced.children.count == 0
                        && [replaced.identifier isEqualToString:@"org.test.replace"] && replaced.options == UIMenuOptionsDisplayInline) != revenant_negative,
                       "a menu with replaced children keeps its subtitle, element size, identifier and options", revenant_describe(replaced.subtitle));
        revenant_check(([menu_copy.subtitle isEqualToString:@"Choices"] && menu_copy.preferredElementSize == UIMenuElementSizeSmall && menu_copy.children.count == 1) != revenant_negative,
                       "a copied menu keeps its subtitle, element size and children", revenant_describe(menu_copy.subtitle));

        UICommand *command = [UICommand commandWithTitle:@"Bold" image:image action:@selector(description) propertyList:nil alternates:@[]];
        command.subtitle = @"Style";
        [command setSelectedImage:selected];
        UICommand *command_copy = [command copy];
        revenant_check(([command_copy.subtitle isEqualToString:@"Style"] && command_copy.selectedImage == selected && command_copy.action == @selector(description)) != revenant_negative,
                       "a copied command keeps its subtitle, selected image and action", revenant_describe(command_copy.subtitle));

        UIKeyCommand *key = [UIKeyCommand commandWithTitle:@"Italic" image:image action:@selector(description) input:@"i" modifierFlags:UIKeyModifierCommand propertyList:nil alternates:@[]];
        revenant_check(([key.input isEqualToString:@"i"] && key.modifierFlags == UIKeyModifierCommand && [key.title isEqualToString:@"Italic"] && key.action == @selector(description)) != revenant_negative,
                       "a key command made with a title keeps its input, modifier flags, title and action", revenant_describe(key.input));
        UIKeyCommand *key_copy = [key copy];
        revenant_check(([key_copy.input isEqualToString:@"i"] && key_copy.modifierFlags == UIKeyModifierCommand) != revenant_negative, "a copied key command keeps its input and modifier flags", revenant_describe(key_copy.input));
        UIKeyCommand *plain = [UIKeyCommand keyCommandWithInput:@"b" modifierFlags:UIKeyModifierShift action:@selector(description)];
        revenant_check(([plain.input isEqualToString:@"b"] && plain.modifierFlags == UIKeyModifierShift) != revenant_negative, "a key command made from an input keeps it", revenant_describe(plain.input));
    }
    return revenant_finish();
}
