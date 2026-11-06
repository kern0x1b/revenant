import("fixtures")

local REFERENCE = [[
	.syntax unified
	.section __TEXT,__text,regular,pure_instructions
	.thumb
	.thumb_func
_target_fn:
	bx lr
	.section __TEXT,__swift5_typeref,regular,no_dead_strip
pair_lbl:
	.byte 0
field_lbl:
	.long _target_fn - pair_lbl - 1
]]

local CONTROL = [[
	.syntax unified
	.section __TEXT,__text,regular,pure_instructions
	.thumb
	.thumb_func
_target_fn:
	bx lr
	.section __TEXT,__swift5_typeref,regular,no_dead_strip
pair_lbl:
	.byte 0, 0
field_lbl:
	.long _target_fn - pair_lbl - 2
]]

local function section_address(folder, binary, segment, section)
    local listing = fixtures.run(folder, "xcrun", {"otool", "-l", binary})
    for block in (listing .. "Section"):gmatch("(.-)Section") do
        if block:match("sectname%s+" .. section .. "%s") and block:match("segname%s+" .. segment .. "%s") then
            return tonumber(block:match("addr%s+0x(%x+)"), 16)
        end
    end
    raise("%s has no %s,%s", binary, segment, section)
end

local function reference_failures(folder, ld64, name, source, pair_distance)
    io.writefile(path.join(folder, name .. ".s"), source)
    local library = fixtures.link(folder, ld64, "lib" .. name .. ".dylib", "armv7-apple-ios6.0", name .. ".s", {"-dynamiclib"})
    local listing = fixtures.run(folder, "xcrun", {"nm", "-arch", "armv7", "-m", library})
    local target = listing:match("(%x+)%s+%(__TEXT,__text%)%s+non%-external%s+%[Thumb%]%s+_target_fn")
    if not target then
        return {string.format("%s: _target_fn is not a Thumb function in the linked image: %s", name, listing)}
    end
    target = tonumber(target, 16)
    local field_offset = fixtures.section_offset(folder, library, "__TEXT", "__swift5_typeref") + pair_distance
    local field_address = section_address(folder, library, "__TEXT", "__swift5_typeref") + pair_distance
    local decoded = (field_address + fixtures.slot(library, field_offset)) & 0xffffffff
    local expected = target | 1
    if decoded ~= expected then
        return {string.format("%s: the reference at %#x decodes to %#x, expected %#x (the Thumb function _target_fn at %#x with bit 0 set)",
                              name, field_address, decoded, expected, target)}
    end
    return {}
end

function failures(opt)
    local folder = fixtures.scratch()
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    local found = {}
    table.join2(found, reference_failures(folder, opt.ld64, "pair_before_field", REFERENCE, 1))
    table.join2(found, reference_failures(folder, opt.ld64, "pair_two_before_field", CONTROL, 2))
    os.tryrm(folder)
    return found
end
