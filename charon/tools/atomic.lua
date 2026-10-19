-- The one atomic writer of the generators: tools/gen (through emit.lua) and tools/found (ir.lua) write their files through it
-- (design-spec-driven.md D2). A file is compared with the bytes on disk and written only when they differ, so an unchanged tree
-- writes nothing and keeps its mtimes. A changed file is written to a sibling in the same directory and renamed over the target: a
-- reader sees the old file or the new one, never a partial one, and the sibling never outlives a failed write. The sibling's name is
-- the target path, the process id and a counter, and a name a file already holds is skipped, so writers of one tree never share a
-- sibling. A failed write raises.
--
-- What it does not do: it does not fsync. The file object of xmake's Lua has no fsync (measured on xmake 3.1.1: its methods are new,
-- close, flush, read, write, seek, size, lines and the like), and a process per file would cost more than the whole run. The handle is
-- closed (which flushes it to the kernel) before the rename, so a reader and a killed process see the old file or the new one; only a
-- loss of power between the rename and the disk can leave a file the disk has not taken yet. Every file written here is regenerated
-- by the next run or is under version control. A process killed between the open and the rename leaves its sibling
-- <name>.charon-new.<pid>.<n>: its name is never reused (the process id and the counter), nothing reads it, and .gitignore hides it.

local counter = 0

local function read_bytes(filepath)
    if not os.isfile(filepath) then
        return nil
    end
    local handle = assert(io.open(filepath, "rb"))
    local data = handle:read("a")
    handle:close()
    return data
end

-- A sibling name of filepath that no file holds yet.
local function sibling_of(filepath)
    while true do
        counter = counter + 1
        local sibling = string.format("%s.charon-new.%d.%d", filepath, os.getpid(), counter)
        if not os.exists(sibling) then
            return sibling
        end
    end
end

-- Writes text to filepath when the file does not hold it already. Returns true when the file was written.
function write(filepath, text)
    if read_bytes(filepath) == text then
        return false
    end
    os.mkdir(path.directory(filepath))
    local sibling = sibling_of(filepath)
    try {
        function()
            local handle = assert(io.open(sibling, "wb"))
            handle:write(text)
            assert(handle:close())
            os.mv(sibling, filepath)
        end,
        catch {
            function(err)
                os.tryrm(sibling)
                raise("%s", err)
            end
        }
    }
    return true
end
