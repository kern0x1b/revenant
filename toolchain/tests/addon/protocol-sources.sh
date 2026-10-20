#!/bin/sh
set -u
SDK=$1
OUT=$2
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CLANG=${CLANG:-$HOME/.xmake/packages/l/llvm/23.1.1/6a8c97aaa69241df9ed69ac86f13a045/bin/clang}
[ -x "$CLANG" ] || { echo "protocol-sources: no clang at $CLANG; set CLANG to the pinned one"; exit 2; }
rm -rf "$OUT"; mkdir -p "$OUT/src" "$OUT/obj"
xmake lua --stdin _ "$ROOT" "$OUT" <<'LUA'
import("core.base.json")
local root, out = ...
-- Lua's `<` on strings follows the locale; byteorder sorts by bytes, as Python's sorted() did.
import("byteorder", {rootdir = path.join(root, "modules")})
-- The dotted versions compare as tuples of numbers: 7.0 < 7.0.1 < 10.0, never as strings.
local function version_key(text)
    local key = {}
    for part in text:gmatch("[^%.]+") do
        table.insert(key, tonumber(part))
    end
    return key
end
local function version_less(a, b)
    local x, y = version_key(a), version_key(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or -1, y[i] or -1
        if p ~= q then
            return p < q
        end
    end
    return false
end
local registry = path.join(root, "packages", "frameworks", "apple-backports", "registry")
local libraries = {}
for line in io.lines(path.join(root, "modules", "apple", "backports.lua")) do
    local name, folder = line:match('name = "([A-Za-z]+Backports)", folder = "([A-Za-z]+)"')
    if name then
        table.insert(libraries, {name = name, folder = folder})
    end
end
local plan = {}
local folders = {}
for _, lib in ipairs(libraries) do
    local folder = lib.folder
    local files = {}
    local d = path.join(registry, folder)
    if os.isdir(d) then
        files = os.files(path.join(d, "*.json"))
        byteorder.sort(files)
    end
    local single = path.join(registry, folder .. ".json")
    if os.isfile(single) then
        table.insert(files, single)
    end
    local bands, floors = {}, {}
    for _, f in ipairs(files) do
        local held = json.decode(io.readfile(f))
        for _, e in ipairs(held.entries or held) do
            if e.kind == "protocol" and e.status == "implemented" then
                local intro = e.introduced
                if intro == nil or intro == "" then
                    intro = "0"
                end
                if e.api == nil then
                    raise("%s: a protocol row has no api", f)
                end
                bands[intro] = bands[intro] or {}
                table.insert(bands[intro], e.api)
                local m = e.minimum
                if m ~= nil and m ~= "" and (floors[intro] == nil or version_less(floors[intro], m)) then
                    floors[intro] = m
                end
            end
        end
    end
    local intros = {}
    for intro in pairs(bands) do
        table.insert(intros, intro)
    end
    table.sort(intros, version_less)
    for _, intro in ipairs(intros) do
        local names = bands[intro]
        byteorder.sort(names)
        local target = path.join(out, "src", lib.name .. "Protocols" .. intro .. ".m")
        local body = {
            string.format("// %sProtocols%s.m - written by modules/apple/backports.lua, not by hand.", lib.name, intro),
            string.format('#import "Revenant%sProtocols.h"', folder), "",
            string.format("static void revenant_%s_protocols(void) __attribute__((used));", lib.name),
            string.format("static void revenant_%s_protocols(void)", lib.name), "{"
        }
        for _, n in ipairs(names) do
            table.insert(body, string.format("    (void)@protocol(%s);", n))
        end
        table.insert(body, "}")
        table.insert(body, "")
        io.writefile(target, table.concat(body, "\n"))
        table.insert(plan, table.concat({target, folder, floors[intro] or "6.0", lib.name}, "\t"))
        folders[folder] = true
    end
end
io.writefile(path.join(out, "plan.txt"), #plan > 0 and table.concat(plan, "\n") .. "\n" or "")
local count = 0
for _ in pairs(folders) do
    count = count + 1
end
print(string.format("%d protocol sources over %d libraries", #plan, count))
LUA
fail=0
examined=0
while IFS='	' read -r file folder minimum name; do
  base=$(basename "$file" .m)
  target="armv7-apple-ios${minimum}"
  if [ ! -f "$OUT/hdr/$folder/Revenant${folder}Protocols.h" ]; then
    mkdir -p "$OUT/hdr/$folder"
    xmake l "$ROOT/tools/gen.lua" protocolheaders --tree "$ROOT" --framework "$folder" --out "$OUT/hdr/$folder" \
      > /dev/null 2> "$OUT/hdr/$folder.err" \
      || echo "protocol-sources: tools/gen could not write the header of $folder: $(tail -1 "$OUT/hdr/$folder.err")"
  fi
  if "$CLANG" -target "$target" -isysroot "$SDK" -fobjc-arc -Os -g0 -Wall \
       -Wno-unguarded-availability-new -Wno-unguarded-availability \
       -I"$OUT/hdr/$folder" -I"$ROOT/packages/frameworks/apple-backports/$folder" \
       -c "$file" -o "$OUT/obj/$base.o" 2> "$OUT/obj/$base.diag"; then
    examined=$((examined+1))
  else
    examined=$((examined+1))
    echo "FAIL $base.m ($target, $folder): $(grep -m1 'error:' "$OUT/obj/$base.diag")"
    fail=$((fail+1))
  fi
done < "$OUT/plan.txt"
if [ "$examined" -eq 0 ] && [ "$fail" -eq 0 ]; then
    echo "protocol-sources: FAIL - 0 protocol sources examined, so nothing was compiled; the registry is"
    echo "  $ROOT/packages/frameworks/apple-backports/registry and the libraries are read from"
    echo "  $ROOT/modules/apple/backports.lua"
    exit 2
fi
libraries=$(cut -f2 "$OUT/plan.txt" | sort -u | wc -l | tr -d ' ')
noun=library; [ "$libraries" != "1" ] && noun=libraries
echo "examined: $examined protocol sources over $libraries $noun, each at the triple of its rows' minimum"
if [ "$fail" -eq 0 ]; then
    echo "protocol-sources: OK - $examined of $examined protocol sources compile for armv7 against the 16.4 SDK"
    exit 0
fi
echo "protocol-sources: FAIL - $fail of $examined protocol sources do not compile"
exit $fail
