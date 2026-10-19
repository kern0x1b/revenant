-- xmake l tools/cache-index/names.lua SOURCE [ARCHITECTURE]
--
local dyld = import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local macho = import("apple.macho", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
--
-- Every name one rung of the dyld ladder carries, one per line on stdout, for
-- tools/cache-index/build.lua to sort, compress and key. SOURCE is what dyld.held_source() names for
-- the release: the file dyld_shared_cache_<arch>, or a libraries_<arch> folder beside it.
--
-- WHY THIS EXISTS: the first held rung of a name was found by running
--     strings -a CACHE | grep -xF NAME
-- over every rung, once per name, per slice, per author. That reads the whole cache per name
-- (measured 6 ms per MB: 0.42 s at 80 MB, 1.38 s at 233 MB, 6.04 s at 1002 MB, so ~148 s for one
-- name over the whole 24.6 GB ladder). Reading each cache ONCE and answering from an index is the
-- whole point; this script is that one read.
--
-- WHAT IS REUSED, not reimplemented: every byte of Mach-O and shared-cache parsing comes from
-- modules/apple/dyld.lua (open_cache, load, and the export-trie and symtab readers it exports) and
-- modules/apple/macho.lua (read, images, image() -- which is what fills .sections/.symtab/.strtab).
-- The new code is two loops: one that walks .sections and takes the NUL runs, which is the walk
-- modules/apple/macho.lua's text_literals() already does for a __TEXT,__cstring of a plain binary,
-- and one that takes a whole symbol table, which is the walk dyld.lua's own cached_library() already
-- does over the EXTERNAL range only. Neither is a second parser: both call the code above them.
-- text_literals() is not called because it takes a binary path and reads the whole file as one
-- image, which is not what a shared cache is (its header is dyld_v1, and its images sit at the
-- addresses the image table names).
--
-- WHAT IS INDEXED, and why each -- together a superset of what `strings -a | grep -xF` reports for
-- any real name, which is the property the self-test checks:
--   __TEXT,__objc_methname   every registered selector, which is where a selector name lives
--   __TEXT,__objc_classname  every class name, private ones included
--   __TEXT,__objc_methtype   type encodings, which authors grep when a name is a type
--   __TEXT,__cstring         C string literals: a selector built by sel_registerName() from a
--                            literal lives here, not in methname, and this is what strings read
--   the export trie          every EXPORTED symbol, through dyld.load()'s own reading, so the symbol
--                            half of a public name is the same reading tools/release-split.lua makes
--                            (export trie where there is one, external symtab otherwise, re-exports
--                            resolved)
--   the whole symbol table   every DEFINED symbol, public or private. This is not redundant with
--                            the trie: a private class is not exported, and measured on the armv7
--                            cache of 6.1.3 the trie alone misses 37313 _OBJC_ symbols that
--                            `strings -a` does report, among them _OBJC_CLASS_$_APKeychainUtilities
--                            and _OBJC_CLASS_$_APNetworksController. An index that answered NONE for
--                            those would be worse than the scan it replaces, so the symtab is read
--                            over its whole range and not only its external one.
--
-- BOTH SPELLINGS of an ObjC name are emitted, because authors ask for either: the mangled
-- _OBJC_CLASS_$_Foo and the bare Foo. One is the symbol a client binds, the other is the name in the
-- facts, and a lookup that answered only one would send someone to the other.

-- The sections a name can be written in, keyed by section name only: a cache carries one of each and
-- it is in __TEXT, and matching on the segment as well would silently skip a toolchain that moves one.
local WANTED = {__objc_methname = true, __objc_classname = true, __objc_methtype = true, __cstring = true}

function main(source, architecture)
    assert(source, "usage: xmake l tools/cache-index/names.lua SOURCE [ARCHITECTURE]")

    -- The bytes that may not be in a name. Written as numbers on purpose: Lua reads \37 as the byte
    -- 37 and \31 as the byte 31, and a class spelled 1-37 swallows the space (32) and every
    -- punctuation byte up to it, which silently dropped every name containing one -- 128818 of them
    -- in the cache of 6.1.3, measured. 0 is %z, 1 to 31 are the C0 controls, 127 is DEL.
    local CONTROL = "[%z\1-\31\127]"

    local names, counted, rejected, whitespace = {}, 0, 0, 0

    -- A name is a line in the index and a key in a lookup, so three things are not names: an empty
    -- run (the terminator between two), a run carrying a control byte (a literal with an embedded
    -- newline -- strings splits that into two or more too, and splitting only on NUL would put two
    -- entries in the index that are neither of them a name; 18868 of them in the cache of 6.1.3),
    -- and a run of nothing but spaces (padding inside a data section; 9627 in the same cache, every
    -- one of which `strings -a` reports as part of a longer run rather than as a name).
    local function keep(name)
        if #name > 0 then
            if name:find(CONTROL) then
                rejected = rejected + 1
            elseif name:find("^ +$") then
                whitespace = whitespace + 1
            elseif not names[name] then
                names[name] = true
                counted = counted + 1
            end
        end
    end

    local function take_runs(bytes)
        for run in bytes:gmatch("([^%z]+)") do
            keep(run)
        end
    end

    -- Every NUL run of a class name section, and the two mangled spellings that go with it. This is
    -- what puts _OBJC_CLASS_$_Foo in the index for a class the export trie never names.
    local function take_class_runs(bytes)
        for run in bytes:gmatch("([^%z]+)") do
            keep(run)
            keep("_OBJC_CLASS_$_" .. run)
            keep("_OBJC_METACLASS_$_" .. run)
        end
    end

    -- A NUL-terminated string at a file offset, one byte at a time through the same fetch the
    -- symtab uses, so one code path serves a cache's address space and a file's offsets.
    local function fetch_string(fetch, offset)
        local pieces, at = {}, offset
        while true do
            local byte = fetch(at, 1):byte(1)
            if not byte or byte == 0 then
                break
            end
            pieces[#pieces + 1] = string.char(byte)
            at = at + 1
        end
        return table.concat(pieces)
    end

    -- Every DEFINED symbol of a symbol table: N_EXT set, and any type but undefined. The external
    -- range dyld.lua reads is the tail of the same table, so this is that reader with first/last
    -- widened to the whole thing rather than a new one. symtab/stroff are __LINKEDIT FILE OFFSETS,
    -- so they are turned into addresses through the segment first, which is what dyld.lua's own
    -- linkedit_address() does before it reads the same two numbers.
    local function take_symtab(fetch, image)
        if not image.symtab then
            return
        end
        local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
        if not nsyms or nsyms <= 0 or not stroff or not symoff then
            return
        end
        local linkedit
        for _, segment in ipairs(image.segments) do
            if segment.name == "__LINKEDIT" then
                linkedit = segment
            end
        end
        if not linkedit then
            return
        end
        local at = function (offset) return linkedit.vmaddr + (offset - linkedit.fileoff) end
        local entry = image.wide and 16 or 12
        local table_bytes = fetch(at(symoff), nsyms * entry)
        for index = 0, nsyms - 1 do
            local strx, kind = string.unpack("<I4B", table_bytes, index * entry + 1)
            if strx ~= 0 and kind & 0xE0 == 0 and kind & 0x01 ~= 0 and kind & 0x0E ~= 0 then
                keep(fetch_string(fetch, at(stroff + strx)))
            end
        end
    end


    local function sections_of(image, fetch)
        for _, section in ipairs(image.sections) do
            if WANTED[section.name] then
                local bytes = fetch(section.addr, section.size)
                if section.name == "__objc_classname" then
                    take_class_runs(bytes)
                else
                    take_runs(bytes)
                end
            end
        end
    end

    if os.isdir(source) then
        -- A libraries_<arch> folder: plain Mach-O files, one slice each. A file's addresses become
        -- file offsets through its own segments, which is the one thing that differs from a cache's.
        for _, binary in ipairs(macho.binaries_under(source)) do
            local data = macho.read(binary)
            for _, found in ipairs(macho.images(data)) do
                if not architecture or found.architecture == architecture then
                    local function fetch(address, size)
                        for _, segment in ipairs(found.segments) do
                            if segment.vmaddr <= address and address + size <= segment.vmaddr + segment.vmsize then
                                local at = found.base + segment.fileoff + (address - segment.vmaddr)
                                return data:sub(at + 1, at + size)
                            end
                        end
                    end
                    sections_of(found, fetch)
                    take_symtab(fetch, found)
                end
            end
        end
    else
        local cache = dyld.open_cache(source)
        local function fetch(address, size)
            return cache.read_address(address, size)
        end
        for _, entry in ipairs(cache.images) do
            sections_of(entry.image, fetch)
            take_symtab(fetch, entry.image)
        end
        cache.close()
    end

    -- The exported symbols, through the same reading tools/release-split.lua makes, so a public
    -- symbol's answer rests on dyld.lua and not on a second opinion of the trie.
    for name in pairs(dyld.load(source).exports) do
        keep(name)
    end

    -- io.write, NOT print: print is a format call, and a name that holds a conversion -- "%'",
    -- "%s", or the "%@" an Objective-C format string is full of -- is rewritten or split by it.
    -- Measured on the armv7 cache of 6.1.3: print wrote the name "'%" as two lines, "'" and "%'",
    -- so 30235 lines carried a conversion and the index lost the names behind them. A name is data.
    local sorted = table.keys(names)
    byteorder.sort(sorted)
    for _, name in ipairs(sorted) do
        io.write(name, "\n")
    end
    -- The counts on stderr: stdout is the index, and a line of numbers in it would be an entry.
    io.stderr:write(string.format("names.lua: %d names (%d runs with a control byte, %d runs of spaces, neither a name) from %s\n",
                                  counted, rejected, whitespace, source))
end
