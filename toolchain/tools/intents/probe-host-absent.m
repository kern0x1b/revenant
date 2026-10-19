#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>

static int tally_found, tally_answered, tally_inherited;

static const char *current_file = "-";
static NSString *where(NSString *api)
{
    return [NSString stringWithFormat:@"%-14s %@\t", current_file, api];
}

static const char *owning_class(Class cls, SEL selector, BOOL classMethod)
{
    for (Class walk = classMethod ? object_getClass(cls) : cls; walk; walk = class_getSuperclass(walk)) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(walk, &count);
        const char *owner = NULL;
        for (unsigned int i = 0; i < count && !owner; i++)
            if (method_getName(methods[i]) == selector)
                owner = class_getName(walk);
        free(methods);
        if (owner)
            return owner;
    }
    return NULL;
}

static NSString *init_call(Class cls)
{
    id object = nil;
    @try {
        object = [[cls alloc] init];
    }
    @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@", exception.name];
    }
    if (!object)
        return @"nil";
    return [object class] == cls ? @"object" : [NSString stringWithFormat:@"%@", [object class]];
}

static void probe_class(NSString *api)
{
    Class cls = NSClassFromString(api);
    unsigned int methods = 0, properties = 0, protocols = 0;
    if (cls) {
        class_copyMethodList(cls, &methods);
        class_copyPropertyList(cls, &properties);
        class_copyProtocolList(cls, &protocols);
    }
    printf("%s kind=class      found=%-3s own-methods=%-4u own-properties=%-4u own-protocols=%-4u\n",
           where(api).UTF8String, cls ? "yes" : "NO", methods, properties, protocols);
    if (cls)
        tally_found++;
}

static void probe_method(NSString *api)
{
    NSRange open = [api rangeOfString:@"["];
    NSRange close = [api rangeOfString:@"]" options:NSBackwardsSearch];
    BOOL classMethod = [api hasPrefix:@"+"];
    NSString *inner = [api substringWithRange:NSMakeRange(open.location + 1,
                                     close.location - open.location - 1)];
    NSRange space = [inner rangeOfString:@" "];
    NSString *name = [inner substringToIndex:space.location];
    NSString *selector = [inner substringFromIndex:space.location + 1];
    Class cls = NSClassFromString(name);
    SEL asked = NSSelectorFromString(selector);
    BOOL answers = cls ? [classMethod ? object_getClass(cls) : cls respondsToSelector:asked] : NO;
    printf("%s kind=method     found=%-3s answers=%-3s declared-by=%-26s init=%s\n",
           where(api).UTF8String, cls ? "yes" : "NO", answers ? "yes" : "no",
           cls ? (owning_class(cls, asked, classMethod) ?: "-") : "-",
           (!classMethod && [selector isEqualToString:@"init"] && cls) ? init_call(cls).UTF8String : "-");
    if (cls)
        tally_found++;
    if (answers)
        tally_answered++;
    if (cls && !strcmp(owning_class(cls, asked, classMethod) ?: "", "NSObject"))
        tally_inherited++;
}

static void probe_property(NSString *api)
{
    NSRange dot = [api rangeOfString:@"."];
    NSString *name = [api substringToIndex:dot.location];
    NSString *property = [api substringFromIndex:dot.location + 1];
    Class cls = NSClassFromString(name);
    if (!cls) {
        printf("%s kind=property   found=NO\n", where(api).UTF8String);
        return;
    }
    tally_found++;
    NSString *getter = property;
    objc_property_t found = NULL;
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    for (unsigned int i = 0; i < count && !found; i++)
        if (!strcmp(property_getName(properties[i]), property.UTF8String))
            found = properties[i];
    if (found) {
        const char *custom = property_getAttributes(found);
        if (custom && strncmp(custom, "G", 1) == 0 && strlen(custom) > 1)
            getter = @(custom + 1);
    }
    free(properties);
    SEL read = NSSelectorFromString(getter);
    printf("%s kind=property   found=yes  answers=%-3s declared-by=%-26s getter=%s\n",
           where(api).UTF8String, [cls instancesRespondToSelector:read] ? "yes" : "no",
           owning_class(cls, read, NO) ?: "-", getter.UTF8String);
    if ([cls instancesRespondToSelector:read])
        tally_answered++;
}

static void probe_protocol(NSString *api)
{
    unsigned int count = 0;
    Protocol *__unsafe_unretained *protocols = objc_copyProtocolList(&count);
    NSString *wanted = [api hasPrefix:@"_"] ? [api substringFromIndex:1] : api;
    Protocol *found = NULL;
    for (unsigned int i = 0; i < count && !found; i++)
        if (!strcmp(protocol_getName(protocols[i]), wanted.UTF8String))
            found = protocols[i];
    free(protocols);
    printf("%s kind=protocol   found=%-3s\n", where(api).UTF8String, found ? "yes" : "NO");
    if (found)
        tally_found++;
}

static void probe_constant(NSString *api)
{
    NSString *symbol = [api hasSuffix:@"()"] ? [api substringToIndex:api.length - 2] : api;
    void *value = dlsym(RTLD_DEFAULT, symbol.UTF8String);
    printf("%s kind=constant   found=%-3s value=%s\n", where(api).UTF8String, value ? "yes" : "NO",
           value ? [[NSString stringWithFormat:@"%p", value] UTF8String] : "-");
    if (value)
        tally_found++;
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        int parsed = 0, unparsed = 0, rows = 0;
        for (int i = 1; i < argc; i++) {
            NSString *pair = [NSString stringWithUTF8String:argv[i]];
            NSArray *fields = [pair componentsSeparatedByString:@"\t"];
            if (fields.count != 3) {
                printf("%s unparsed: not file/kind/api\n", where(pair).UTF8String);
                unparsed++;
                continue;
            }
            current_file = [fields[0] UTF8String];
            NSString *kind = fields[1];
            NSString *api = fields[2];
            rows++;
            parsed++;
            if ([kind isEqualToString:@"class"])
                probe_class(api);
            else if ([kind isEqualToString:@"method"])
                probe_method(api);
            else if ([kind isEqualToString:@"property"])
                probe_property(api);
            else if ([kind isEqualToString:@"protocol"])
                probe_protocol(api);
            else if ([kind isEqualToString:@"constant"])
                probe_constant(api);
            else {
                printf("%s unparsed: kind %s\n", where(api).UTF8String, kind.UTF8String);
                parsed--;
                unparsed++;
                continue;
            }
        }
        printf("# rows=%d parsed=%d unparsed=%d found=%d answered=%d inherited-from-NSObject=%d\n",
               rows, parsed, unparsed, tally_found, tally_answered, tally_inherited);
    }
    return 0;
}
