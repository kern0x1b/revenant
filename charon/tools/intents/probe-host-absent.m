//
//  probe-host-absent.m
//  Intents
//
//  What the host's own Intents answers for every row of a registry file that says `absent`, and
//  what it answers for a control of rows that file says `implemented`.
//
//  The claim an `absent` row makes is about the release, and the release that carries Intents is
//  the system's own framework - the one Siri and Shortcuts are built on. So this binds
//  /System/Library/Frameworks/Intents.framework and asks it, once, for every row.
//
//  A header mark is not a runtime fact. `- (instancetype)init NS_UNAVAILABLE` is a compile-time
//  attribute: the compiler reads it and the runtime never sees it, so the class keeps the
//  selector it inherits. This probe is what tells the two apart. For each row it prints:
//
//      found      NSClassFromString, or the runtime's own protocol list, answered a name
//      answers    the class - or its metaclass, for a +[...] row - answers the selector, which
//                 is what respondsToSelector: sees
//      declared   the first class up the chain whose OWN method list holds it. This is the column
//                 that separates a body the class has from one it inherits: NSObject's -init
//                 answers every class, and a row that says the class does not implement a
//                 selector it answers through its superclass is a row about the wrong thing.
//      init       for an instance -init row, what [[cls alloc] init] returned: an object, a nil,
//                 or the exception the class itself raised
//
//  A property row is asked the way a caller asks - by the getter its declaration names, since
//  INPerson's contactSuggestion is declared getter=isContactSuggestion - and a protocol row is
//  looked up in the runtime's own protocol list under both spellings, because a protocol is not
//  in any class's method list and a name the runtime does not hold is a different claim from one
//  no header declares.
//
//  Every row arrives as "file<TAB>kind<TAB>api" from the runner, which reads the file and the
//  kind out of the registry itself. The probe never guesses a row's kind from its spelling, and a
//  row it cannot parse is printed as `unparsed` rather than dropped, so a blind reader cannot
//  pass for a quiet one.
//

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>

/* What each row was worth, tallied as it is printed: a run that saw nothing cannot tell a zero on
   one row from a zero on every row, so the control - the implemented rows of the same file - is
   counted here beside the rows under test. */
static int tally_found, tally_answered, tally_inherited;

/* The file a row came from, printed beside every line: the runner probes several registry files in
   one process, so a line without it could not be traced back to the one that asked. */
static const char *current_file = "-";
static NSString *where(NSString *api)
{
    /* A tab, not spaces: a name longer than a fixed width would push the columns of that line
       right and every reader that took a column by offset would read the wrong field. */
    return [NSString stringWithFormat:@"%-14s %@\t", current_file, api];
}

/* The first class up the chain whose own method list holds the selector. class_getInstanceMethod
   answers YES for an inherited method, which is what respondsToSelector: sees; this walks the
   chain itself, so the row can name whose body answers. */
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

/* [[cls alloc] init] for a row whose selector is init. A data class answers an object and the
   description of one is the same class, so "object" is the whole of the claim; a class that
   raises is that, verbatim, because the class's own refusal is an answer and not a defect. */
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
    /* A +[...] row sends to the metaclass, so that is what answers for it. */
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
    /* The getter the declaration names, and the one a caller sends: INPerson's contactSuggestion
       is declared getter=isContactSuggestion, and asking for the property's own name is a
       question no caller asks. */
    NSString *getter = property;
    objc_property_t found = NULL;
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    for (unsigned int i = 0; i < count && !found; i++)
        if (!strcmp(property_getName(properties[i]), property.UTF8String))
            found = properties[i];
    if (found) {
        const char *custom = property_getAttributes(found);
        /* G starts a payload: GgetterName, and the name is what follows the G. */
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
    /* A Swift refinement's protocol is registered with the leading underscore the attribute puts
       in front of it, so both spellings of the same row are looked up. */
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

/* A constant row names a symbol, not a name of the runtime's own object graph, so it is asked
   of the image the process is running in - which is the framework under test, linked into this
   binary, and so the same library the other columns are read from. */
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
