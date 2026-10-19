-- The TOML reader the Charon driver reads charon.toml with, checked on planted cases whose expected values come from
-- the TOML rules, not from any other reader. failures() returns the list of what did not hold.
function failures(opts)
    local toml = import("toml", {rootdir = opts.driver, anonymous = true})
    local found = {}

    local function check(condition, message)
        if not condition then
            table.insert(found, message)
        end
    end

    local function refused(text)
        local message = nil
        try { function () toml.parse(text, "planted.toml") end, catch { function (e) message = tostring(e) end } }
        return message
    end

    local function same_list(got, want)
        if #got ~= #want then
            return false
        end
        for index = 1, #want do
            if got[index] ~= want[index] then
                return false
            end
        end
        return true
    end

    local scalars = toml.parse([==[
a = 1
b = 1.5
c = "x\ty"
d = 'lit\n'
e = true
f = 1_000
g = 0x1F
h = -7
i = """
line1
line2"""
j = '''
first
second'''
k = "tab\u0041\U0001F600"
l = """one \
    two"""
]==], "scalars")
    check(scalars.a == 1 and math.type(scalars.a) == "integer", "an integer must read as an integer")
    check(scalars.b == 1.5, "a float must read as a float")
    check(scalars.c == "x\ty", "a basic string must take its escapes")
    check(scalars.d == "lit\\n", "a literal string must take no escapes")
    check(scalars.e == true, "true must read as a boolean")
    check(scalars.f == 1000, "underscores in an integer must be ignored")
    check(scalars.g == 31, "a hexadecimal integer must read in base 16")
    check(scalars.h == -7, "a negative integer must read as one")
    check(scalars.i == "line1\nline2", "a multi-line basic string must drop its opening newline")
    check(scalars.j == "first\nsecond", "a multi-line literal string must keep its newlines")
    check(scalars.k == "tabA\u{1F600}", "unicode escapes must read as the code point they name")
    check(scalars.l == "one two", "a backslash at a line end must join the next line without the blanks")

    local tables = toml.parse([==[
p.q.r = 3
"user.example:thing" = "why"
[t]
x = 1

[t.u]
y = 2

[[arr]]
a = 1
b.c = 5

[[arr]]
a = 2
]==], "tables")
    check(tables.t.x == 1 and tables.t.u.y == 2, "a table header must nest under its name")
    check(#tables.arr == 2 and tables.arr[2].a == 2, "[[name]] must append an element to an array of tables")
    check(tables.arr[1].b.c == 5, "keys after a [[header]] belong to that element")
    check(tables.p.q.r == 3, "a dotted key must create the tables it names")
    check(tables["user.example:thing"] == "why", "a quoted key must keep its dots and colons")

    local arrays = toml.parse([==[
x = [
  1, # one
  2,
]
empty = []
inline = { a = 1, "b" = "x", c.d = 2 }
mixed = [ "s", 'l', [ 3 ] ]
]==], "arrays")
    check(same_list(arrays.x, {1, 2}), "a multi-line array with comments and a trailing comma must read whole")
    check(toml.is_array(arrays.empty) and #arrays.empty == 0, "an empty [] must read as an empty array")
    check(arrays.inline.a == 1 and arrays.inline.b == "x" and arrays.inline.c.d == 2,
          "an inline table must take its keys, quoted and dotted")
    check(arrays.mixed[3][1] == 3 and #arrays.mixed == 3, "nested arrays must read in place")

    local ordered = toml.parse("z = 1\na = 2\nm = 3\n", "order")
    check(same_list(toml.keys(ordered), {"z", "a", "m"}), "keys must come back in the order the file wrote them")

    local header_order = toml.parse("[zeta]\nx = 1\n[alpha]\ny = 2\n", "order2")
    check(same_list(toml.keys(header_order), {"zeta", "alpha"}), "tables must keep their header order")

    check(toml.is_table(toml.parse("[empty]\n", "e").empty), "an empty [header] must read as a table")

    local crlf = toml.parse("a = 1\r\nb = 2\r\n", "crlf")
    check(crlf.a == 1 and crlf.b == 2, "CRLF line ends must read like LF")

    local commented = toml.parse("# leading\na = \"# not a comment\" # a comment\n", "comment")
    check(commented.a == "# not a comment", "a # inside a string must not start a comment")

    local copied = toml.copy(ordered)
    check(copied.z == 1 and same_list(toml.keys(copied), {"z", "a", "m"}), "a copy must keep values and order")
    local merged = toml.merge(ordered, {a = 9, n = 4})
    check(merged.a == 9 and merged.n == 4 and merged.z == 1 and same_list(toml.keys(merged), {"z", "a", "m", "n"}),
          "a merge must take the over-values, keep the base order, and append the new keys")
    check(ordered.a == 2, "a merge must not change its base table")

    local refusals = {
        {"duplicate key", "a = 1\na = 2\n"},
        {"table defined twice", "[t]\n[t]\n"},
        {"unterminated string", 'a = "open\n'},
        {"a date", "d = 1979-05-27\n"},
        {"no value", "a = \n"},
        {"trailing text", "a = 1 b = 2\n"},
        {"trailing comma in an inline table", "a = { b = 1, }\n"},
        {"unknown escape", 'a = "\\q"\n'},
        {"a key with no equals", "lonely\n"},
        {"a value under a table name", "t = 1\n[t]\nx = 2\n"},
    }
    for _, case in ipairs(refusals) do
        check(refused(case[2]) ~= nil, "must refuse " .. case[1])
    end
    local line_refusal = refused("a = 1\nb = 2\nc = \n")
    check(line_refusal ~= nil and line_refusal:find("planted.toml:3", 1, true) ~= nil,
          "a refusal must name the file and the line it found")

    return found
end
