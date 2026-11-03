function failures(opt)
    local root = path.join(path.directory(opt.modules), "..")
    local loud = import("loud_provider", {rootdir = path.join(root, "frameworks", "ReactNative", "tools"), anonymous = true})
    local found = {}

    local generated = table.concat({
        '#import "RCTThirdPartyComponentsProvider.h"',
        '#import <React/RCTComponentViewProtocol.h>',
        '+ (id)thirdPartyFabricComponents',
        '{',
        '  static id thirdPartyComponents = nil;',
        '  dispatch_once(&token, ^{',
        '    thirdPartyComponents = @{',
        '\t\t@"A": NSClassFromString(@"AView"), // pkg-a',
        '\t\t@"B": NSClassFromString(@"BView"), // pkg-b',
        '    };',
        '  });',
        '}',
        ''
    }, "\n")
    local text, count = loud.transform(generated, "B")
    if count ~= 2 then
        table.insert(found, "both components must be rewritten, got " .. tostring(count))
    end
    if text:find("NSClassFromString(@\"AView\")", 1, true) or not text:find('RNHOST_ADD(@"A", @"AView") // pkg-a', 1, true) then
        table.insert(found, "an entry must go through RNHOST_ADD and keep its comment")
    end
    if not text:find('@"B" componentsSeparatedByString', 1, true) and not text:find('setWithArray:[@"B" componentsSeparatedByString:@","]', 1, true) then
        table.insert(found, "the optional components must be listed")
    end
    if not text:find("MISSING COMPONENT %@", 1, true) or not text:find("RCTLogError", 1, true) then
        table.insert(found, "a missing component must be logged and reported as a React Native error")
    end
    if not text:find("    thirdPartyComponents = mutableComponents;", 1, true) or text:find("\n    };\n", 1, true) then
        table.insert(found, "the dictionary literal must be replaced by the mutable dictionary")
    end
    if not text:find('#import "RCTThirdPartyComponentsProvider.h"\n#import <React/RCTLog.h>\n', 1, true) then
        table.insert(found, "RCTLog.h must be imported after the provider header")
    end
    local refused = false
    try {
        function ()
            loud.transform("no dictionary here", "")
        end,
        catch {
            function ()
                refused = true
            end
        }
    }
    if not refused then
        table.insert(found, "a file without the dictionary literal must be refused")
    end
    return found
end
