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
                char *ivar = strrchr(attributes, ',');
                if (ivar && ivar[1] == 'V')
                    *ivar = '\0';
            }
            printf("property %s %s %s\n", class_name, name, attributes);
        }
    }
    return 0;
}
