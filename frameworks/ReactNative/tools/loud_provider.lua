local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/loud_provider.lua --source RCTThirdPartyComponentsProvider.mm --output FILE [--optional A,B]
  writes a copy of the RCTThirdPartyComponentsProvider.mm that React Native's codegen made, which does not stop the application at start
  and is not silent either. The generated file builds a dictionary literal and raises on a component class that is not linked (nil).
  The copy skips such a component, writes "MISSING COMPONENT <name>: the class <class> is not linked into this host" with NSLog (so it is
  in the host's log) and reports a React Native error with the same words. Only the components named in --optional, the ones the
  application declares optional, may be missing without a word.]]

local ADD_MACRO = '#define RNHOST_ADD(key, name) { Class c = NSClassFromString(name); if (c) { mutableComponents[key] = c; } else if (![optionalComponents containsObject:key]) { NSLog(@"rn-host: MISSING COMPONENT %@: the class %@ is not linked into this host", key, name); RCTLogError(@"Fabric component %@ is not linked into this host (class %@ is missing), so views of it do not render", key, name); } }'

function transform(text, optional)
    local start = text:find("thirdPartyComponents = @{", 1, true)
    if not start then
        raise("the provider has no thirdPartyComponents dictionary literal")
    end
    local result = text:gsub("thirdPartyComponents = @{", function ()
        return "NSMutableDictionary *mutableComponents = [NSMutableDictionary dictionary];\n"
            .. "    NSSet *optionalComponents = [NSSet setWithArray:[@\"" .. (optional or "") .. "\" componentsSeparatedByString:@\",\"]];\n"
            .. ADD_MACRO
    end, 1)
    local count
    result, count = result:gsub('@"([^"]+)": NSClassFromString%(@"([^"]+)"%),', function (key, class)
        return 'RNHOST_ADD(@"' .. key .. '", @"' .. class .. '")'
    end)
    result = result:gsub("\n    };\n", "\n    thirdPartyComponents = mutableComponents;\n", 1)
    result = result:gsub('(#import "RCTThirdPartyComponentsProvider.h"\n)', function (line)
        return line .. "#import <React/RCTLog.h>\n"
    end, 1)
    return result, count
end

function main(...)
    local shared = import("@addon.revenant.member", {anonymous = true})
    local given, words = shared.arguments({...}, {source = "value", output = "value", optional = "value", help = "switch"})
    if given.help or #words ~= 0 or not given.source or not given.output then
        print(USAGE)
        return
    end
    local result, count = transform(io.readfile(path.absolute(given.source)), given.optional)
    if count == 0 then
        raise("%s names no component, so the copy would make none", given.source)
    end
    os.mkdir(path.directory(path.absolute(given.output)))
    io.writefile(path.absolute(given.output), result)
    print(string.format("wrote %s with %d components", path.absolute(given.output), count))
end
