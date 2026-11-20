local tools = path.join(os.scriptdir(), "..", "tools")
local ast = import("ast", {rootdir = tools, anonymous = true})
local facts = import("facts", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local DUMP = {
    "|-EnumDecl 0x1 </sdk/Photos.h:40:1, line:55:1> line:40:6 PHSubtype",
    "| |-EnumConstantDecl 0x2 <line:41:5, col:30> col:5 PHSubtypeLow 'int'",
    "| |-EnumConstantDecl 0x3 </sdk/Photos.h:47:5, <built-in>:72:22> /sdk/Photos.h:47:5 PHSubtypeAny 'NSInteger':'long'",
    "| | `-AvailabilityAttr 0x4 <line:1:45, col:78> ios 8.0 0 0 \"\" \"\" 0",
    "| |-EnumConstantDecl 0x5 <line:48:5, <scratch space>:4:1> line:48:5 PHSubtypePasted 'int'",
    "| |-EnumConstantDecl 0x6 <line:49:5, <command line>:2:1> line:49:5 PHSubtypeDefined 'int'",
    "| `-EnumConstantDecl 0x7 <<scratch space>:3:1, col:9> col:5 PHSubtypeLast 'int'",
    "`-VarDecl 0x8 <line:60:1, <built-in>:72:22> /sdk/Photos.h:60:19 PHCeiling 'const long' extern cinit",
}

local HEADER = table.concat({
    "#define FIXTURE_MAX __LONG_MAX__",
    "#define FIXTURE_PASTE(a, b) a##b",
    "typedef enum FixtureLimit {",
    "    FixtureLow = 1,",
    "    FixtureAny __attribute__((availability(ios, introduced=8.0))) = FIXTURE_MAX,",
    "    FixtureNext = FIXTURE_PASTE(1, 2),",
    "    FixtureLast = 3,",
    "} FixtureLimit;",
    "extern const long FixtureCeiling __attribute__((availability(ios, introduced=14.0))) = FIXTURE_MAX;",
    ""
}, "\n")

local function blocks_of(lines)
    local found = {}
    local index = 0
    local handle = {lines = function ()
        return function ()
            index = index + 1
            return lines[index]
        end
    end}
    ast.scan(handle, function (top)
        table.insert(found, top)
    end)
    return found
end

local function names(children)
    local out = {}
    for _, child in ipairs(children) do
        table.insert(out, tostring(child.name))
    end
    return table.concat(out, ",")
end

function main()
    local blocks = blocks_of(DUMP)
    assert(#blocks == 2, "the dump has two top-level declarations, the scan found " .. #blocks)
    local enum = blocks[1]
    assert(enum.kind == "EnumDecl" and enum.name == "PHSubtype", "the enum is " .. tostring(enum.kind) .. " " .. tostring(enum.name))
    local expected = "PHSubtypeLow,PHSubtypeAny,PHSubtypePasted,PHSubtypeDefined,PHSubtypeLast"
    assert(names(ast.children_of(enum, "EnumConstantDecl")) == expected, "enumerators named " .. names(ast.children_of(enum, "EnumConstantDecl")) .. ", expected " .. expected)
    assert(ast.ios_intro(ast.children_of(enum, "EnumConstantDecl")[2]) == 8000, "the intro of the enumerator that ends in a built-in macro is lost")
    assert(blocks[2].kind == "VarDecl" and blocks[2].name == "PHCeiling" and blocks[2].flags.extern, "the extern constant that ends in a built-in macro is " .. tostring(blocks[2].name))

    local original = os.getenv("REVENANT_CACHE")
    local base = workspace.fresh("ast-names-test")
    local sdk = path.join(base, "sdk")
    local header = path.join(sdk, "System", "Library", "Frameworks", "Fixture.framework", "Headers", "Fixture.h")
    os.mkdir(path.directory(header))
    io.writefile(path.join(sdk, "SDKSettings.json"), '{"Version": "99.9"}')
    io.writefile(header, HEADER)
    os.setenv("REVENANT_CACHE", path.join(base, "home"))
    local intros = facts.constant_intros(sdk)
    os.setenv("REVENANT_CACHE", original or "")
    for name, intro in pairs({FixtureLow = false, FixtureAny = 8000, FixtureNext = false, FixtureLast = false, FixtureCeiling = 14000}) do
        local found = intros[name]
        assert(found ~= nil, "clang's dump of the fixture lost the constant " .. name .. "; found " .. table.concat(table.keys(intros), ","))
        assert(found.intro == (intro or nil), name .. " has the intro " .. tostring(found.intro) .. ", expected " .. tostring(intro))
    end
    for name in pairs(intros) do
        assert(string.find(name, "^[%a_][%w_]*$"), "a constant is named " .. name)
    end
    os.tryrm(base)
    print("AST_NAMES_TEST passed")
end
