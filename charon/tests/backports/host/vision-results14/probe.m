/* probe.m - the header-declared surface of the Vision classes named in stdin, as the runtime answers for each member: the
 * superclass of a class, the type encoding of an instance or class method (an inherited one included), and the attributes
 * of a declared property (the ivar name removed). stdin is surface.tsv, one member per line, "kind class name", with the
 * kinds super, instance, class and property; the members are the ones the SDK's headers declare, read from the IR
 * (see README.md). Compiled once against the host's Vision framework and once against the port's Vision sources, with no
 * framework linked on the port side. A member the class does not answer prints MISSING, and so does a class that is not
 * there. Output is one line per member; run.sh compares the two outputs line by line. */
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <objc/runtime.h>
#import <stdio.h>
#import <string.h>

int main(void)
{
    char line[1024];
    while (fgets(line, sizeof line, stdin)) {
        char kind[32], class_name[128], name[512];
        if (sscanf(line, "%31s %127s %511s", kind, class_name, name) != 3)
            continue;
        Class cls = NSClassFromString([NSString stringWithUTF8String:class_name]);
        if (cls == Nil) {
            printf("%s %s %s MISSING-CLASS\n", kind, class_name, name);
            continue;
        }
        if (strcmp(kind, "super") == 0) {
            Class parent = class_getSuperclass(cls);
            printf("super %s %s\n", class_name, parent ? class_getName(parent) : "-");
        } else if (strcmp(kind, "instance") == 0) {
            Method method = class_getInstanceMethod(cls, NSSelectorFromString([NSString stringWithUTF8String:name]));
            printf("instance %s %s %s\n", class_name, name, method ? method_getTypeEncoding(method) : "MISSING");
        } else if (strcmp(kind, "class") == 0) {
            Method method = class_getClassMethod(cls, NSSelectorFromString([NSString stringWithUTF8String:name]));
            printf("class %s %s %s\n", class_name, name, method ? method_getTypeEncoding(method) : "MISSING");
        } else if (strcmp(kind, "property") == 0) {
            objc_property_t property = class_getProperty(cls, name);
            char attributes[512] = "MISSING";
            if (property) {
                strlcpy(attributes, property_getAttributes(property), sizeof attributes);
                /* the attributes end in ,V<ivar>: the ivar's name is the port's choice, so it is left out */
                char *ivar = strrchr(attributes, ',');
                if (ivar && ivar[1] == 'V')
                    *ivar = '\0';
            }
            printf("property %s %s %s\n", class_name, name, attributes);
        }
    }
    return 0;
}
