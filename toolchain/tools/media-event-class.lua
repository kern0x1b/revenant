local LIBRARY = {"packages", "frameworks", "apple-backports", "MediaPlayer"}
local HOST = {"tests", "backports", "host", "mediaplayeritem"}
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true})

local USAGE = "usage: xmake l tools/media-event-class.lua <Class> <member> <type> <release> <value> [--carried]"

local function fill(template, values)
    local out = {}
    local i = 1
    while i <= #template do
        local c = template:sub(i, i)
        local nxt = template:sub(i + 1, i + 1)
        if c == "{" and nxt == "{" then
            table.insert(out, "{")
            i = i + 2
        elseif c == "}" and nxt == "}" then
            table.insert(out, "}")
            i = i + 2
        elseif c == "{" then
            local close = template:find("}", i, true)
            local key = template:sub(i + 1, close - 1)
            if values[key] == nil then
                raise("template field %s has no value", key)
            end
            table.insert(out, values[key])
            i = close + 1
        else
            table.insert(out, c)
            i = i + 1
        end
    end
    return table.concat(out)
end

local CLASS = [==[// {klass}, the {release} command event, and the one property its header declares.
//
// Carried, and for the same reason as its siblings: measured with tools/mach32_methods.py against the
// 6.1.3 cache, no class whose name holds 'CommandEvent' exists in any of its 236 classes and none of its
// 41 categories, with a nonsense selector absent as the control. A class the release does not have is new
// code and cannot shadow anything, so there is nothing native for it to be. `absent` is for a member
// whose answer needs hardware the device lacks, and none of this family needs any.
//
// New code over the base MPRemoteCommandCenter71.m already carries. The header line it implements:
//
//   @property (nonatomic, readonly) {type} {member};
//
// at MP_API(ios({release})). The AST says the header declares exactly {member} for this class, and the
// port declares exactly that and its setter, so a header member the port would not have is none.
//
// Readwrite in the port where the header has it readonly: an event the port builds has to be able to
// carry the {what} it is an event *about*. The accessor is written out rather than left to the
// synthesiser, so what a caller reads is the port's own code and mutating it changes what a caller reads
// rather than only the bytes.

#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface {klass} : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) {type} {member};
@end

@implementation {klass}
@synthesize {member} = _{member};

- ({type}){member} {{
    return _{member};
}}

@end
]==]

local CHECK = [==[// {klass}'s contract: the class is a kind of the base the port carries, the base's command answers what
// the event was built with, the property reads back what was set, and an event nothing set answers the
// type's zero. The mutation's verdict is printed on both sides, because mutate.lua cannot enforce that.
#import "MPMediaItemStandin.h"

@implementation MPRemoteCommandEvent
{{
    MPRemoteCommand *_command;
}}
- (instancetype)initWithCommand:(MPRemoteCommand *)command {{
    self = [super init];
    if (self) {{ _command = command; }}
    return self;
}}
- (MPRemoteCommand *)command {{ return _command; }}
- (NSTimeInterval)timestamp {{ return 0; }}
@end

@implementation MPRemoteCommand
@end

// The stand-in declares the 9.0 event's option type, which the 8.0 and 7.1 headers pull in; it is unused
// here and has to exist for the link.
@implementation MPNowPlayingInfoLanguageOption
@end

#define REVENANT_MEDIAPLAYER_STANDIN 1
#include "{source}"

static int failures = 0;

static void check(const char *what, int held, const char *got) {{
    if (held) {{ printf("  ok   %s: %s\n", what, got); }}
    else {{ printf("  RED  %s: %s\n", what, got); failures++; }}
}}

int main(void) {{
    MPRemoteCommand *sent = [[MPRemoteCommand alloc] init];
    {klass} *event = [[{klass} alloc] initWithCommand:sent];
    check("the event is a kind of the base the port carries",
          [event isKindOfClass:[MPRemoteCommandEvent class]],
          [event isKindOfClass:[MPRemoteCommandEvent class]] ? "an MPRemoteCommandEvent" : "not");
    check("the base's command is what the event was built with", event.command == sent,
          event.command == sent ? "the command" : "other");
    event.{member} = {value};
    check("{member} reads back what was set", event.{member} == {value},
          event.{member} == {value} ? "{shown}" : "other");
    {klass} *untouched = [[{klass} alloc] initWithCommand:sent];
    check("an event nothing set answers the type's zero", untouched.{member} == 0,
          untouched.{member} == 0 ? "0" : "other");
    if (failures) {{ printf("{tag}: %d RED\n", failures); return 1; }}
    printf("{tag}: OK (0 failures)\n");
    return 0;
}}
]==]

local function run(program, args, scratch)
    local out, err = path.join(scratch, "run.out"), path.join(scratch, "run.err")
    local status = os.execv(program, args, {try = true, stdout = out, stderr = err})
    local stdout, stderr = io.readfile(out), io.readfile(err)
    os.rm(out)
    os.rm(err)
    return status, stdout, stderr
end

local function strip(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function replace_all(text, from, to)
    local out, at = {}, 1
    while true do
        local first, last = text:find(from, at, true)
        if first == nil then
            table.insert(out, text:sub(at))
            break
        end
        table.insert(out, text:sub(at, first - 1))
        table.insert(out, to)
        at = last + 1
    end
    return table.concat(out)
end

function main(...)
    local positional, carried = {}, false
    for _, argument in ipairs({...}) do
        if argument == "--carried" then
            carried = true
        else
            table.insert(positional, argument)
        end
    end
    if #positional < 5 then
        raise(USAGE)
    end
    local klass, member, kind, release, value = positional[1], positional[2], positional[3], positional[4], positional[5]
    local shown = value
    local tag = klass:lower()
    local root = path.absolute(path.join(os.scriptdir(), ".."))
    local library = path.join(root, table.unpack(LIBRARY))
    local host = path.join(root, table.unpack(HOST))
    local runs = workspace.run("mutate")
    local source = carried and "MPRemoteCommandCenter71.m" or (klass .. ".m")
    local what = member:gsub("Time", ""):gsub("Rate", ""):gsub("Type", ""):lower()
    if what == "" then
        what = "value"
    end

    if not carried then
        io.writefile(path.join(library, source), fill(CLASS, {klass = klass, member = member, type = kind,
                                                               release = release, what = what}))
    end
    local check_path = path.join(host, tag .. "check.m")
    local check_text = fill(CHECK, {klass = klass, member = member, value = value, shown = shown,
                                    source = source, tag = tag})
    io.writefile(check_path, check_text)

    local baseline = path.join(runs, tag .. "-base")
    local status, _, stderr = run("xcrun", {"clang", "-fobjc-arc", "-framework", "Foundation",
                                            "-I", host, "-I", library, "-o", baseline, check_path}, runs)
    if status ~= 0 then
        raise(strip(stderr))
    end
    local _, baseline_out = run(baseline, {}, runs)
    print("### the check, WITHOUT the mutation:")
    print(strip(baseline_out))

    local scratch = path.join(runs, tag .. "-mutant")
    local mutate_status, mutate_out, mutate_err = run("xmake", {"l", path.join(host, "mutate.lua"), source,
                                                                "return _" .. member .. ";", "return 0;", scratch}, runs)
    if mutate_status ~= 0 then
        raise(strip(mutate_err))
    end
    print(strip(mutate_out))
    for _, file in ipairs(os.files(path.join(library, "*.h"))) do
        os.cp(file, path.join(scratch, path.filename(file)))
    end
    local mutant_check = path.join(scratch, tag .. "check-mutant.m")
    io.writefile(mutant_check, replace_all(check_text, '"' .. source .. '"', '"' .. scratch .. "/" .. source .. '"'))
    local mutant_binary = path.join(runs, tag .. "-mut")
    status, _, stderr = run("xcrun", {"clang", "-fobjc-arc", "-framework", "Foundation", "-I", host,
                                      "-I", scratch, "-o", mutant_binary, mutant_check}, runs)
    if status ~= 0 then
        raise(strip(stderr))
    end
    local _, mutant_out = run(mutant_binary, {}, runs)
    print("### the check, WITH the mutation:")
    print(strip(mutant_out))
    if strip(baseline_out) == strip(mutant_out) then
        raise("the two verdicts are the same, so the check does not see this mutation")
    end
    print("### the two verdicts above differ, so it is a real mutant")
end
