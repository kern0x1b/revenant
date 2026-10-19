-- Port of make-object-fixtures.py: the fixtures whose pages carry DICTIONARY OBJECTS, written with every
-- xref offset and /Length measured from the bytes as they are written.
--
--   xmake l make-object-fixtures.lua <directory>
--
-- Border (/Border and /BS), appearance characteristics (/MK), destinations (/Dest), actions (/A),
-- outlines (/Outlines), widgets, colours and button states.  Files are written in the order the Python
-- writes them, and the same "  wrote ..." lines are printed.

local FONT = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
local TEXT = "BT /F1 12 Tf 72 720 Td (outlined) Tj ET\n"
local MERGED_TEXT = "BT /F1 12 Tf 72 720 Td (merged) Tj ET\n"

-- Definitions are kept in one table, C, so the chunk stays under Lua's per-function local limit.
local C = {}

-- ---- helpers ------------------------------------------------------------------------------------

local function plus(a, b)
  local out = {}
  for _, v in ipairs(a) do out[#out + 1] = v end
  for _, v in ipairs(b) do out[#out + 1] = v end
  return out
end

-- One annotation dictionary as a string.  `extra` is a list of {key, value}; the key is written as
-- " /" .. key exactly as given (so a key that already starts with "/" yields "//", as the Python does).
local function annot(kind, extra, name)
  local body = "<< /Type /Annot /Subtype /" .. kind
  for _, pair in ipairs(extra) do
    body = body .. " /" .. pair[1] .. " " .. pair[2]
  end
  if name ~= nil then
    body = body .. " /NM (" .. name .. ")"
  end
  return body .. " >>"
end

local function widget(extra, field, rect, name)
  field = field or "/Tx"
  rect = rect or "[40 40 240 70]"
  local pairs_ = { { "Rect", rect }, { "F", "4" }, { "FT", field } }
  for _, pair in ipairs(extra) do pairs_[#pairs_ + 1] = pair end
  return annot("Widget", pairs_, name)
end

-- The body is ONE dictionary ending in " >>"; the /NM is written into it.
local function named(name, body)
  if body:sub(-3) ~= " >>" then
    raise("named: body does not end with ' >>'")
  end
  return body:sub(1, #body - 3) .. " /NM (" .. name .. ") >>"
end

local function square(extra)
  return annot("Square", plus({ { "Rect", "[40 40 240 140]" }, { "Contents", "(square)" }, { "F", "4" } }, extra))
end

local function link(extra)
  return annot("Link", plus({ { "Rect", "[20 700 220 720]" }, { "Contents", "(link)" }, { "F", "4" } }, extra))
end

-- The four-character-free slug the Python builds: strip("/") then lower().
local function slug(s)
  local t = s:gsub("^/+", ""):gsub("/+$", "")
  return t:lower()
end

-- Python posixpath.join for a directory and one name.
local function join(directory, name)
  if directory == "" or directory:sub(-1) == "/" then
    return directory .. name
  end
  return directory .. "/" .. name
end

local function write_file(path, data)
  local handle, err = io.open(path, "wb")
  if handle == nil then
    raise("cannot write " .. path .. ": " .. tostring(err))
  end
  handle:write(data)
  handle:close()
end

-- The file image: header, every object, the xref with each offset measured, the trailer.
-- Python's "%%EOF" in a literal is not %-formatted, so it stays two percent signs.
local function assemble(objects)
  local header = "%PDF-1.4\n"
  local parts = { header }
  local size = #header
  local offsets = {}
  for number, body in ipairs(objects) do
    offsets[number] = size
    local piece = number .. " 0 obj\n" .. body .. "\nendobj\n"
    parts[#parts + 1] = piece
    size = size + #piece
  end
  local start = size
  parts[#parts + 1] = "xref\n0 " .. (#objects + 1) .. "\n0000000000 65535 f \n"
  for _, offset in ipairs(offsets) do
    parts[#parts + 1] = string.format("%010d 00000 n \n", offset)
  end
  parts[#parts + 1] = "trailer\n<< /Size " .. (#objects + 1) .. " /Root 1 0 R >>\nstartxref\n"
    .. start .. "\n%%EOF\n"
  return table.concat(parts)
end

-- 1 catalog, 1 pages, `page_count` pages, their content streams, the annotations, the font, then the
-- extra indirect objects.  extra_objects is a list of {name, body}.  Returns the object count.
local function build(path, annotations, extra_objects, catalog_extra, page_count)
  extra_objects = extra_objects or {}
  catalog_extra = catalog_extra or ""
  page_count = page_count or 1
  local objects = { "<< /Type /Catalog /Pages 2 0 R" .. catalog_extra .. " >>", false }
  for _ = 1, page_count do objects[#objects + 1] = false end
  for _ = 1, page_count do
    objects[#objects + 1] = "<< /Length " .. #TEXT .. " >>\nstream\n" .. TEXT .. "\nendstream"
  end
  local annotation_numbers = {}
  for _, body in ipairs(annotations) do
    objects[#objects + 1] = body
    annotation_numbers[#annotation_numbers + 1] = #objects
  end
  local font_number = #objects + 1
  objects[#objects + 1] = FONT
  for _, pair in ipairs(extra_objects) do
    objects[#objects + 1] = pair[2]
  end

  local annots = {}
  for i, n in ipairs(annotation_numbers) do annots[i] = n .. " 0 R" end
  annots = table.concat(annots, " ")
  local kids = {}
  local contents = {}
  for i = 0, page_count - 1 do
    kids[#kids + 1] = (3 + i) .. " 0 R"
    contents[#contents + 1] = (3 + page_count + i) .. " 0 R"
  end
  kids = table.concat(kids, " ")
  local resources = "<< /Font << /F1 " .. font_number .. " 0 R >> >>"
  objects[2] = "<< /Type /Pages /Kids [" .. kids .. "] /Count " .. page_count .. " >>"
  for i = 0, page_count - 1 do
    objects[3 + i] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [" .. annots
      .. "] /Resources " .. resources .. " /Contents " .. contents[i + 1] .. " >>"
  end
  write_file(path, assemble(objects))
  return #objects
end

-- One page whose /Annots holds a widget whose /Parent is a FIELD dictionary (object 7); the widget is
-- object 5 and the font object 6.  Returns the object count.
local function build_merged_field(directory, name, child_extra, field_extra, field_type, child_type)
  field_extra = field_extra or "/T (parent field)"
  field_type = field_type or "/Tx"
  local objects = {
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    false,
    "<< /Length " .. #MERGED_TEXT .. " >>\nstream\n" .. MERGED_TEXT .. "\nendstream",
    false,
    FONT,
    false,
  }
  local child_part = ""
  if child_type ~= nil then
    child_part = "/FT " .. child_type
  end
  objects[5] = "<< /Type /Annot /Subtype /Widget /Rect [40 40 240 70] /F 4 /Parent 7 0 R "
    .. child_part .. child_extra .. " >>"
  objects[7] = "<< /FT " .. field_type .. " /T " .. field_extra .. " /Kids [5 0 R] >>"
  objects[3] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [5 0 R] "
    .. "/Resources << /Font << /F1 6 0 R >> >> /Contents 4 0 R >>"
  write_file(join(directory, name), assemble(objects))
  return #objects
end

-- ---- /Border and /BS -----------------------------------------------------------------------------

C.BORDER_PLAIN = square({ { "Border", "[0 0 3]" } })
C.BORDER_RADII = square({ { "Border", "[5 7 2]" } })
C.BORDER_ZERO = square({ { "Border", "[0 0 0]" } })
C.BORDER_NEGATIVE = square({ { "Border", "[0 0 -2.5]" } })
C.BORDER_BS = square({ { "Border", "[0 0 1]" }, { "BS", "<< /Type /Border /W 4 /S /D /D [3 2] >>" } })
C.BORDER_SHORT = square({ { "Border", "[0 0]" } })
C.BORDER_LONG = square({ { "Border", "[1 2 3 4]" } })
C.BORDER_NONE = square({})
C.BORDER_LINK = annot("Link", { { "Rect", "[20 700 60 720]" }, { "Contents", "(link)" }, { "F", "4" } })

for _, letter in ipairs({ "S", "D", "B", "I", "U", "Q" }) do
  C["BS_" .. letter] = square({ { "BS", "<< /S /" .. letter .. " /W 2 >>" } })
end
C.BS_DASH_SOLID = square({ { "BS", "<< /S /S /W 2 /D [4 1] >>" } })
C.BS_NO_WIDTH = square({ { "BS", "<< /S /I >>" } })
C.BS_WIDTH_ONLY = square({ { "Border", "[0 0 7]" }, { "BS", "<< /W 5 >>" } })
C.BS_STYLE_ONLY = square({ { "Border", "[0 0 9]" }, { "BS", "<< /S /D /D [4 4] >>" } })
C.BS_DASH_CUSTOM = square({ { "BS", "<< /S /D /W 2 /D [7 5] >>" } })
C.BS_DASH_STRING = square({ { "BS", "<< /S /D /W 2 /D (not an array) >>" } })
C.BS_WIDTH_STRING = square({ { "BS", "<< /S /D /W (not a number) >>" } })

C.BORDER_ON_NONTYPE = {
  annot("Highlight", { { "Rect", "[0 0 200 30]" }, { "Contents", "(highlight)" }, { "F", "4" }, { "Border", "[0 0 6]" } }),
  annot("Text", { { "Rect", "[40 40 240 140]" }, { "Contents", "(text)" }, { "F", "4" }, { "Border", "[0 0 6]" } }),
  annot("Link", { { "Rect", "[20 700 60 720]" }, { "Contents", "(link)" }, { "F", "4" }, { "Border", "[0 0 6]" } }),
  annot("Stamp", { { "Rect", "[40 40 240 140]" }, { "Contents", "(stamp)" }, { "F", "4" }, { "Border", "[0 0 6]" } }),
  annot("Popup", { { "Rect", "[40 40 240 140]" }, { "Contents", "(popup)" }, { "F", "4" }, { "Border", "[0 0 6]" } }),
}
C.BS_ON_NONTYPE = {
  annot("Highlight", { { "Rect", "[0 0 200 30]" }, { "Contents", "(highlight)" }, { "F", "4" }, { "BS", "<< /W 6 /S /D >>" } }),
}
C.BORDER_RADII_ONLY = square({ { "Border", "[5 7]" } })

-- ---- the absent /Border, one fixture per subtype ------------------------------------------------

C.NOBORDER = {}
for _, kind in ipairs({ "Text", "FreeText", "Line", "Circle", "Highlight", "Underline", "StrikeOut", "Ink", "Stamp", "Popup" }) do
  C.NOBORDER[kind] = annot(kind, { { "Rect", "[40 40 240 140]" }, { "Contents", "(no border)" }, { "F", "4" } })
end
C.NOBORDER_Widget = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" } })
C.NOBORDER_WidgetT = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "T", "(a field)" } })
C.NOBORDER_WidgetBG = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "MK", "<< /BG [1 0 0] >>" } })
C.NOBORDER_WidgetBC = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "MK", "<< /BC [0 0 1] >>" } })
C.NOBORDER_WidgetBCgray = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "MK", "<< /BC [1] >>" } })
C.NOBORDER_WidgetEmptyBC = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "MK", "<< /BC [] >>" } })
C.NOBORDER_LineL = annot("Line", { { "Rect", "[40 40 240 140]" }, { "Contents", "(line)" }, { "F", "4" }, { "L", "[40 40 240 140]" } })
C.NOBORDER_WidgetTm = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "Tm", "(label)" } })

-- The SKIPPED shapes, on one fixture.
C.DROPS = {
  annot("Line", { { "Contents", "(Line no L)" } }),
  annot("Line", { { "Rect", "[40 40 240 140]" }, { "Contents", "(Line L)" }, { "L", "[40 40 240 140]" } }),
  annot("Line", { { "Contents", "(Line L no Rect)" }, { "L", "[40 40 240 140]" } }),
  annot("Square", { { "Contents", "(Square no Rect)" } }),
  annot("Text", { { "Contents", "(Text no Rect)" } }),
  annot("Widget", { { "Rect", "[40 40 140 70]" }, { "Contents", "(Widget no FT)" } }),
  annot("Widget", { { "Rect", "[40 40 140 70]" }, { "Contents", "(Widget FT)" }, { "FT", "/Tx" } }),
  annot("Popup", { { "Contents", "(Popup no Rect)" } }),
  annot("Ink", { { "Contents", "(Ink no InkList)" } }),
  annot("Circle", { { "Contents", "(Circle no Rect)" } }),
  annot("FreeText", { { "Contents", "(FreeText no Rect)" } }),
  annot("Stamp", { { "Contents", "(Stamp no Rect)" } }),
  annot("Link", { { "Contents", "(Link no Rect)" } }),
}

-- ---- /MK ------------------------------------------------------------------------------------------

C.MK_FULL = annot("Widget", {
  { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "T", "(a field)" },
  { "MK", "<< /BG [1 0 0] /BC [0 0 1] /R 90 /CA (caption) /RC (rollover) /AC (down) >>" },
  { "FT", "/Btn" }, { "Tm", "(label)" },
})
C.MK_BARE = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "MK", "<< /CA (only a caption) >>" }, { "FT", "/Btn" } })
C.MK_NONE = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" } })
C.MK_GRAY = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "MK", "<< /BG [0.5] /BC [0] >>" }, { "FT", "/Btn" } })
C.MK_CMYK = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "MK", "<< /BG [0.1 0.2 0.3 0.4] >>" }, { "FT", "/Btn" } })
C.MK_NONE_C = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "MK", "<< /BG [0 0 0 0] /BC [1] >>" }, { "FT", "/Btn" } })
C.MK_TWO = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "MK", "<< /BG [1 0] /BC [0.25 0.5] >>" }, { "FT", "/Btn" } })
C.MK_ROT_REAL = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "MK", "<< /R 90.5 /CA 7 >>" }, { "FT", "/Btn" } })
C.MK_R_ZERO = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "MK", "<< /R 0 >>" }, { "FT", "/Btn" } })

-- ---- the /BC component count -----------------------------------------------------------------------

C.BC_CMYK = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "MK", "<< /BC [0 0 0 1] >>" } })
C.BC_STRING = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "MK", "<< /BC (a string) >>" } })
C.BC_NUMBER = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "MK", "<< /BC 0.5 >>" } })
C.BC_RGB = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "MK", "<< /BC [0.25 0.5 0.75] >>" } })

-- ---- /Popup flags, and the name keys --------------------------------------------------------------

C.POPUP_F4 = annot("Popup", { { "Rect", "[40 40 140 140]" }, { "F", "4" }, { "Contents", "(f4)" } })
C.POPUP_F0 = annot("Popup", { { "Rect", "[40 40 140 140]" }, { "F", "0" }, { "Contents", "(f0)" } })
C.POPUP_F2 = annot("Popup", { { "Rect", "[40 40 140 140]" }, { "F", "2" }, { "Contents", "(f2)" } })
C.POPUP_NOF = annot("Popup", { { "Rect", "[40 40 140 140]" }, { "Contents", "(no F)" } })
C.SQUARE_F4 = annot("Square", { { "Rect", "[40 40 140 140]" }, { "F", "4" }, { "Contents", "(square f4)" } })
C.STAMP_F4 = annot("Stamp", { { "Rect", "[40 40 140 140]" }, { "F", "4" }, { "Contents", "(stamp f4)" } })

C.WIDGET_T = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Btn" }, { "T", "(T only)" }, { "MK", "<< /BC [0 0 1] >>" } })
C.WIDGET_T_NOFT = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "T", "(T no FT)" }, { "MK", "<< /BC [0 0 1] >>" } })
C.WIDGET_T_TX = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Tx" }, { "T", "(T tx)" }, { "MK", "<< /BC [0 0 1] >>" } })
C.WIDGET_TU_TX = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Tx" }, { "TU", "(TU tx)" }, { "MK", "<< /BC [0 0 1] >>" } })
C.WIDGET_NO_T = annot("Widget", { { "Rect", "[40 40 140 70]" }, { "F", "4" }, { "FT", "/Tx" }, { "MK", "<< /BC [0 0 1] >>" } })
C.SQUARE_T = annot("Square", { { "Rect", "[40 40 140 140]" }, { "F", "4" }, { "T", "(square T)" }, { "MK", "<< /BC [0 0 1] >>" } })

-- ---- the widget dictionary, one fixture per group of keys ----------------------------------------

-- Each /Ff bit on an annotation of its own (Table 8.39), named for its bit.
local WIDGET_FLAG_BITS = {
  1, 2, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 1048576, 2097152, 16777216, 33554432,
}
C.WIDGET_FLAGS = {}
for _, bits in ipairs(WIDGET_FLAG_BITS) do
  C.WIDGET_FLAGS[#C.WIDGET_FLAGS + 1] = widget({
    { "Ff", string.format("%d", bits) }, { "V", "(value)" }, { "DV", "(default)" }, { "AS", "/Yes" },
  })
end
C.WIDGET_NO_FLAGS = { widget({ { "V", "(value)" }, { "DV", "(default)" }, { "AS", "/Yes" } }) }
-- every bit at once: 1+2+4096+8192+16384+32768+65536+131072+262144+1048576+2097152+16777216+33554432
C.WIDGET_ALL_FLAGS = { widget({
  { "Ff", string.format("%d", 1 + 2 + 4096 + 8192 + 16384 + 32768 + 65536 + 131072 + 262144 + 1048576 + 2097152 + 16777216 + 33554432) },
}) }

C.WIDGET_FIELD_TYPES = {}
for _, ft in ipairs({ "/Btn", "/Tx", "/Ch", "/Sig" }) do
  C.WIDGET_FIELD_TYPES[#C.WIDGET_FIELD_TYPES + 1] = widget({}, ft)
end
C.WIDGET_STATES = {}
for _, state in ipairs({ "/Yes", "/Off", "/On" }) do
  C.WIDGET_STATES[#C.WIDGET_STATES + 1] = widget({ { "FT", "/Btn" }, { "V", "(off)" }, { "AS", state } })
end

C.WIDGET_VALUES = {
  widget({
    { "V", "(typed)" }, { "DV", "(preset)" }, { "MaxLen", "7" }, { "Q", "2" },
    { "Opt", "[(one) (two) (three)]" }, { "T", "(the field)" }, { "TU", "(alternate)" },
    { "DA", "(/Helv 12 Tf 0 g)" },
  }),
  widget({
    { "V", "7" }, { "DV", "[1 2]" }, { "MaxLen", "(seven)" }, { "Q", "(two)" }, { "Opt", "(not an array)" },
  }),
  widget({}),
}

-- /T plus one more key, one annotation per fixture; the key "/Opt" is written as given.
C.T_WITH_ONE_MORE_NAMES = { "nothing", "DAstring", "TU", "Opt", "Q", "MaxLen", "V", "DV", "F" }
C.T_WITH_ONE_MORE = {}
for _, extra in ipairs({
  {},
  { { "DA", "(/Helv 12 Tf 0 g)" } },
  { { "TU", "(alternate)" } },
  { { "/Opt", "[(one)]" } },
  { { "Q", "2" } },
  { { "MaxLen", "7" } },
  { { "V", "(typed)" } },
  { { "DV", "(preset)" } },
  { { "F", "4" } },
}) do
  C.T_WITH_ONE_MORE[#C.T_WITH_ONE_MORE + 1] = { widget(plus({ { "T", "(the field)" } }, extra)) }
end

C.WIDGET_MIXED = {
  annot("Link", { { "Rect", "[20 700 60 720]" }, { "F", "4" }, { "Contents", "(a link)" } }),
  annot("Square", { { "Rect", "[40 40 140 140]" }, { "F", "4" }, { "Contents", "(a square)" } }),
  widget({}),
  annot("Popup", { { "Rect", "[60 60 160 160]" }, { "F", "4" }, { "Contents", "(a popup)" } }),
  widget({}),
}

C.SYNTH_COUNT_WIDGETS_ONLY = { widget({}), widget({}), widget({}) }
C.SYNTH_COUNT_LINK_FIRST = {
  annot("Link", { { "Rect", "[20 700 60 720]" }, { "F", "4" } }),
  widget({}), widget({}),
}
C.SYNTH_COUNT_LINK_MIDDLE = {
  widget({}),
  annot("Link", { { "Rect", "[20 700 60 720]" }, { "F", "4" } }),
  widget({}),
}

-- /AS and /V, one state each, and the /Btn field types ----------------------------------------------

C.BTN_STATES = { false, "/Off", "/On", "/Yes" }

-- the (key, value) pairs for one state key; a nil state (false here) gives none
local function as_pairs(state, key)
  key = key or "AS"
  if not state then return {} end
  return { { key, state } }
end

-- the same one key as the merged writer's bytes: " /AS /On", or "" for no state
local function as_bytes(state, key)
  key = key or "AS"
  if not state then return "" end
  return " /" .. key .. " " .. state
end

C.BUTTON_AS_ALONE = {}
C.BUTTON_AS_AND_V = {}
C.TEXT_AS = {}
C.BUTTON_V_ONLY = {}
C.BUTTON_AS_YES_V_OFF = {}
for _, state in ipairs(C.BTN_STATES) do
  C.BUTTON_AS_ALONE[#C.BUTTON_AS_ALONE + 1] = widget(as_pairs(state), "/Btn")
  C.BUTTON_AS_AND_V[#C.BUTTON_AS_AND_V + 1] = widget(plus(as_pairs(state), as_pairs(state, "V")), "/Btn")
  C.TEXT_AS[#C.TEXT_AS + 1] = widget(as_pairs(state))
  C.BUTTON_V_ONLY[#C.BUTTON_V_ONLY + 1] = widget(as_pairs(state, "V"), "/Btn")
  C.BUTTON_AS_YES_V_OFF[#C.BUTTON_AS_YES_V_OFF + 1] = widget(plus(as_pairs("/Yes"), as_pairs(state, "V")), "/Btn")
end

C.BUTTON_AP_STATES = {
  widget({ { "AS", "/Off" }, { "AP", "<< /N << /On << >> /Off << >> >> >>" } }, "/Btn"),
  widget({ { "AS", "/On" }, { "AP", "<< /N << /On << >> /Off << >> >> >>" } }, "/Btn"),
  widget({ { "AS", "/Yes" }, { "AP", "<< /N << /Yes << >> /Off << >> >> >>" } }, "/Btn"),
  widget({ { "AS", "/Yes" }, { "AP", "<< /N << /Marked << >> /Off << >> >> >>" } }, "/Btn"),
  widget({ { "AS", "/Marked" }, { "AP", "<< /N << /Marked << >> /Off << >> >> >>" } }, "/Btn"),
}

C.BUTTON_AS_OFF_V_ON = {
  widget({ { "AS", "/Off" }, { "V", "/On" } }, "/Btn"),
  widget({ { "AS", "/On" }, { "V", "/Off" } }, "/Btn"),
  widget({ { "AS", "/Yes" }, { "V", "/On" } }, "/Btn"),
  widget({ { "AS", "/On" }, { "V", "/Yes" } }, "/Btn"),
}

-- ---- colours and the font, one annotation per key, each with its own /NM ------------------------

C.COLOUR_SHAPES = {
  -- -backgroundColor, off /MK /BG, one annotation per component count of Table 8.40
  named("bg-rgb", widget({ { "MK", "<< /BG [1 0 0] >>" } }, "/Tx")),
  named("bg-gray", widget({ { "MK", "<< /BG [0.5] >>" } }, "/Tx")),
  named("bg-cmyk-none", widget({ { "MK", "<< /BG [0 0 0 0] >>" } }, "/Tx")),
  named("bg-cmyk", widget({ { "MK", "<< /BG [0.1 0.2 0.3 0.4] >>" } }, "/Tx")),
  named("bg-notarray", widget({ { "MK", "<< /BG (a string) >>" } }, "/Tx")),
  named("bg-btn", widget({ { "MK", "<< /BG [0 0 1] >>" } }, "/Btn")),
  named("bg-ch-noopt", widget({ { "MK", "<< /BG [0 0 1] >>" } }, "/Ch")),
  named("bg-bc-beside", widget({ { "MK", "<< /BC [1 0 0] /BG [0 1 0] >>" } }, "/Tx")),
  -- -interiorColor, off a geometry annotation's own /IC
  named("ic-square-rgb", annot("Square", { { "Rect", "[40 40 240 140]" }, { "F", "4" }, { "IC", "[0 1 0]" } })),
  named("ic-square-gray", annot("Square", { { "Rect", "[40 40 240 140]" }, { "F", "4" }, { "IC", "[0.25]" } })),
  named("ic-square-none", annot("Square", { { "Rect", "[40 40 240 140]" }, { "F", "4" } })),
  named("ic-circle-cmyk", annot("Circle", { { "Rect", "[40 40 240 140]" }, { "F", "4" }, { "IC", "[0.1 0.2 0.3 0.4]" } })),
  named("ic-link", annot("Link", { { "Rect", "[20 700 60 720]" }, { "F", "4" }, { "IC", "[1 0 0]" } })),
  named("ic-widget", annot("Widget", { { "Rect", "[40 40 240 70]" }, { "F", "4" }, { "FT", "/Tx" }, { "IC", "[1 0 0]" } })),
  -- -fontColor off the FILL operands
  named("da-fill-gray-0", widget({ { "DA", "(/Helv 12 Tf 0 g)" } })),
  named("da-fill-gray-1", widget({ { "DA", "(/Helv 12 Tf 1 g)" } })),
  named("da-fill-rgb", widget({ { "DA", "(/Helv 12 Tf 1 0 0 rg)" } })),
  named("da-fill-cmyk-red", widget({ { "DA", "(/Helv 12 Tf 0 1 1 0 k)" } })),
  named("da-fill-cmyk-cyan", widget({ { "DA", "(/Helv 12 Tf 1 0 0 0 k)" } })),
  named("da-stroke-rg", widget({ { "DA", "(/Helv 12 Tf 0 1 0 RG)" } })),
  named("da-stroke-k", widget({ { "DA", "(/Helv 12 Tf 0 1 0 K)" } })),
  named("da-stroke-g", widget({ { "DA", "(/Helv 12 Tf 0 1 0 G)" } })),
  named("da-nooperand", widget({ { "DA", "(/Helv 12 Tf)" } })),
  named("da-fill-gray-then-rgb", widget({ { "DA", "(/Helv 12 Tf 0.5 g 1 0 0 rg)" } })),
  named("da-fill-rgb-then-gray", widget({ { "DA", "(/Helv 12 Tf 1 0 0 rg 0.5 g)" } })),
  named("da-fill-gray-twice", widget({ { "DA", "(/Helv 12 Tf 1 g 0.25 g)" } })),
  named("da-fill-badcount", widget({ { "DA", "(/Helv 12 Tf 0.5 0.25 g)" } })),
  -- -font's shapes
  named("font-courier-7", widget({ { "DA", "(/Courier 7 Tf 0 g)" } })),
  named("font-size-only", widget({ { "DA", "(12 Tf 0 g)" } })),
  named("font-name-only", widget({ { "DA", "(/Helv Tf 0 g)" } })),
  named("font-unknown", widget({ { "DA", "(/Nonexistent 9 Tf 0 g)" } })),
  -- the standard fourteen's abbreviations, one per face
  named("font-abbrev-helv", widget({ { "DA", "(/Helv 21 Tf 0 g)" } })),
  named("font-abbrev-hebo", widget({ { "DA", "(/HeBo 11 Tf 0 g)" } })),
  named("font-abbrev-heob", widget({ { "DA", "(/HeOb 12 Tf 0 g)" } })),
  named("font-abbrev-hebo-bi", widget({ { "DA", "(/HeBO 13 Tf 0 g)" } })),
  named("font-abbrev-cour", widget({ { "DA", "(/Cour 14 Tf 0 g)" } })),
  named("font-abbrev-cobo", widget({ { "DA", "(/CoBo 15 Tf 0 g)" } })),
  named("font-abbrev-coob", widget({ { "DA", "(/CoOb 16 Tf 0 g)" } })),
  named("font-abbrev-cbo-bi", widget({ { "DA", "(/CBO 17 Tf 0 g)" } })),
  named("font-abbrev-tiro", widget({ { "DA", "(/TiRo 18 Tf 0 g)" } })),
  named("font-abbrev-tibo", widget({ { "DA", "(/TiBo 19 Tf 0 g)" } })),
  named("font-abbrev-tiit", widget({ { "DA", "(/TiIt 20 Tf 0 g)" } })),
  named("font-abbrev-tibi", widget({ { "DA", "(/TiBI 22 Tf 0 g)" } })),
  named("font-abbrev-symb", widget({ { "DA", "(/Symb 23 Tf 0 g)" } })),
  named("font-abbrev-zadb", widget({ { "DA", "(/ZaDb 24 Tf 0 g)" } })),
  -- a face spelled the way PostScript spells it
  named("font-full-oblique", widget({ { "DA", "(/Helvetica-Oblique 25 Tf 0 g)" } })),
  named("font-full-roman", widget({ { "DA", "(/Times-Roman 26 Tf 0 g)" } })),
  -- the shape of the lookup: prefix, case and exact
  named("font-prefix-h", widget({ { "DA", "(/H 27 Tf 0 g)" } })),
  named("font-prefix-co", widget({ { "DA", "(/Co 28 Tf 0 g)" } })),
  named("font-prefix-ti", widget({ { "DA", "(/Ti 29 Tf 0 g)" } })),
  named("font-case-upper", widget({ { "DA", "(/HELV 30 Tf 0 g)" } })),
  named("font-case-mixed", widget({ { "DA", "(/Hebo 31 Tf 0 g)" } })),
}

-- ---- /T spelled four ways ---------------------------------------------------------------------------

C.T_LITERAL = { widget({ { "T", "(the field)" } }) }
C.T_NAME = { widget({ { "T", "/TheField" } }) }
C.T_EMPTY = { widget({ { "T", "()" } }) }

-- ---- /Outlines: the linked tree of PDF 1.7 Table 8.2 -------------------------------------------------

-- A spec entry is {title, extra, children}: title is false for no /Title, and "" is an empty /Title.
local function visible_count(entries)
  local total = 0
  for _, entry in ipairs(entries) do
    total = total + 1
    if #entry[3] > 0 then
      total = total + visible_count(entry[3])
    end
  end
  return total
end

-- The bodies of every item, keyed by object number, and the top-level numbers.  Numbers are handed
-- out to a level's siblings first, then to each item's children as they are reached.
local function outline_items(spec, root_number, first_number, signs)
  local bodies = {}
  local number = first_number
  local function emit(entries, parent_number)
    local numbers = {}
    for i = 1, #entries do
      numbers[i] = number
      number = number + 1
    end
    for i, entry in ipairs(entries) do
      local title, extra, children = entry[1], entry[2], entry[3]
      local here = numbers[i]
      local body = "<< /Type /Annot /Subtype /Link /Rect [0 0 10 10]"
      if title ~= false then
        body = body .. " /Title (" .. title .. ")"
      end
      body = body .. " /Parent " .. parent_number .. " 0 R"
      if i > 1 then
        body = body .. " /Prev " .. numbers[i - 1] .. " 0 R"
      end
      if i < #entries then
        body = body .. " /Next " .. numbers[i + 1] .. " 0 R"
      end
      for _, pair in ipairs(extra) do
        body = body .. " /" .. pair[1] .. " " .. pair[2]
      end
      if #children > 0 then
        local child_numbers = emit(children, here)
        local sign = -1
        if title ~= false and signs[title] ~= nil then
          sign = signs[title]
        end
        body = body .. " /First " .. child_numbers[1] .. " 0 R /Last " .. child_numbers[#child_numbers]
          .. " 0 R /Count " .. (sign * visible_count(children))
      end
      bodies[here] = body .. " >>"
    end
    return numbers
  end
  local roots = emit(spec, root_number)
  return bodies, roots
end

local function build_outline(directory, name, spec, open_sign, page_count, signs, extra)
  local page_annotations = {}
  for _ = 1, extra do
    page_annotations[#page_annotations + 1] = annot("Square", {
      { "Rect", "[0 0 10 10]" }, { "F", "4" }, { "Contents", "(filler)" },
    })
  end
  local first = 3 + 2 * page_count + #page_annotations + 1
  local root_number = first
  local bodies, roots = outline_items(spec, root_number, first + 1, signs or {})
  local root_body = "<< /Type /Outlines /First " .. roots[1] .. " 0 R /Last " .. roots[#roots]
    .. " 0 R /Count " .. (open_sign * visible_count(spec)) .. " >>"
  local keys = {}
  for n in pairs(bodies) do keys[#keys + 1] = n end
  table.sort(keys)
  local extra_objects = { { "outline-root", root_body } }
  for _, n in ipairs(keys) do
    extra_objects[#extra_objects + 1] = { tostring(n), bodies[n] }
  end
  local catalog_extra = " /Outlines " .. root_number .. " 0 R"
  local count = build(join(directory, name), page_annotations, extra_objects, catalog_extra, page_count)
  return count, root_number, keys
end

C.OUTLINE_OPEN = {
  { "One", { { "F", "4" }, { "Dest", "[3 0 R /XYZ 11 22 0.5]" } }, {
    { "One One", { { "F", "4" } }, {
      { "One One One", { { "F", "4" } }, {} },
    } },
    { "One Two", { { "F", "4" } }, {} },
  } },
  { "Two", { { "F", "4" }, { "A", "<< /S /URI /URI (https://example.com/two) >>" } }, {
    { "Two One", { { "F", "4" }, { "Dest", "[3 0 R /Fit]" } }, {} },
  } },
}
C.OUTLINE_CLOSED = {
  { "One", { { "F", "4" } }, {
    { "One One", { { "F", "4" } }, {} },
  } },
}
C.OUTLINE_SIGNS = {
  { "Positive", { { "F", "4" } }, {
    { "Positive Child", { { "F", "4" } }, {} },
    { "Positive Child Two", { { "F", "4" } }, {} },
  } },
  { "Negative", { { "F", "4" } }, {
    { "Negative Child", { { "F", "4" } }, {} },
    { "Negative Child Two", { { "F", "4" } }, {} },
  } },
}
C.OUTLINE_SIGNS_SIGNS = { Positive = 1, Negative = -1 }
C.OUTLINE_NO_COUNT = {
  { "A", { { "F", "4" } }, {} },
  { "B", { { "F", "4" } }, {} },
  { "C", { { "F", "4" } }, {} },
  { "D", { { "F", "4" } }, {} },
}
C.OUTLINE_SHAPES = {
  { false, { { "F", "4" } }, {
    { "Child", { { "F", "4" }, { "Dest", "[3 0 R /XYZ 1 2 3]" }, { "A", "<< /S /GoTo /D [3 0 R /Fit] >>" } }, {} },
    { false, { { "F", "4" } }, {} },
  } },
  { "Closed", { { "F", "4" } }, {
    { "Closed Child", { { "F", "4" } }, {} },
  } },
  { "Named", { { "F", "4" }, { "Dest", "(chapter1)" } }, {} },
  { "Alone", { { "F", "4" } }, {} },
}
C.OUTLINE_ISOPEN = {
  { "P1", { { "F", "4" } }, {
    { "C1", { { "F", "4" }, { "Dest", "[3 0 R /Fit]" } }, {} },
    { "C2", { { "F", "4" } }, {} },
  } },
  { "P2", {}, {
    { "C3", { { "F", "4" } }, {} },
    { "C4", {}, {} },
  } },
  { "P3", { { "F", "4" } }, {
    { "C5", {}, {} },
    { "C6", { { "F", "4" }, { "A", "<< /S /URI /URI (https://example.com/c6) >>" } }, {} },
  } },
}
C.OUTLINE_UNTITLED = {
  { false, { { "F", "4" } }, {
    { false, { { "F", "4" } }, {
      { false, { { "F", "4" } }, {
        { false, { { "F", "4" } }, {} },
      } },
    } },
  } },
}
C.OUTLINE_TITLED = {
  { "T", { { "F", "4" } }, {
    { "U", { { "F", "4" } }, {
      { "V", { { "F", "4" } }, {
        { "W", { { "F", "4" } }, {} },
      } },
    } },
  } },
}
C.OUTLINE_TITLE_KEY = {
  { "None", { { "F", "4" } }, { { false, { { "F", "4" } }, {} } } },
  { "Empty", { { "F", "4" } }, { { "", { { "F", "4" } }, {} } } },
  { "Text", { { "F", "4" } }, { { "leaf", { { "F", "4" } }, {} } } },
  { "NoTitleNoF", {}, { { false, {}, {} } } },
  { "NoTitleWithDest", { { "F", "4" } }, { { false, { { "F", "4" }, { "Dest", "[3 0 R /Fit]" } }, {} } } },
}

-- ---- /A, the action dictionaries, and the /Dest spellings -------------------------------------------

C.ACT_GOTO_XYZ = link({ { "A", "<< /S /GoTo /D [3 0 R /XYZ 100 200 1.5] >>" } })
C.ACT_GOTO_FIT = link({ { "A", "<< /S /GoTo /D [3 0 R /Fit] >>" } })
C.ACT_GOTO_FITB = link({ { "A", "<< /S /GoTo /D [3 0 R /FitB 0 0 612 792] >>" } })
C.ACT_GOTO_FITH = link({ { "A", "<< /S /GoTo /D [3 0 R /FitH 700] >>" } })
C.ACT_GOTO_FITBH = link({ { "A", "<< /S /GoTo /D [3 0 R /FitBH 12 34] >>" } })
C.ACT_GOTO_FITBV = link({ { "A", "<< /S /GoTo /D [3 0 R /FitBV 56 78] >>" } })
C.ACT_GOTO_ZOOM_INT = link({ { "A", "<< /S /GoTo /D [3 0 R /XYZ 0 0 2] >>" } })
C.ACT_GOTO_PAGE2 = link({ { "A", "<< /S /GoTo /D [4 0 R /XYZ 0 0 1] >>" } })
C.ACT_GOTO_BAD_PAGE = link({ { "A", "<< /S /GoTo /D [99 0 R /Fit] >>" } })
C.ACT_GOTO_NAMED = link({ { "A", "<< /S /GoTo /D (chapter1) >>" } })
C.ACT_NO_S = link({ { "A", "<< /Type /Action /D [3 0 R /Fit] >>" } })
C.ACT_UNKNOWN_S = link({ { "A", "<< /S /Bogus /X 1 >>" } })
C.ACT_GOTO_NO_D = link({ { "A", "<< /S /GoTo >>" } })
C.ACT_NAMED_NEXT = link({ { "A", "<< /S /Named /N /NextPage >>" } })
C.ACT_NAMED_FIRST = link({ { "A", "<< /S /Named /N /FirstPage >>" } })
C.ACT_NAMED_ZOOMIN = link({ { "A", "<< /S /Named /N /ZoomIn >>" } })
C.ACT_NAMED_NONSENSE = link({ { "A", "<< /S /Named /N /NotAName >>" } })
C.ACT_URI = link({ { "A", "<< /S /URI /URI (https://example.com/a b) >>" } })
C.ACT_URI_NO_URI = link({ { "A", "<< /S /URI >>" } })
C.ACT_GOTOR = link({ { "A", "<< /S /GoToR /F (other.pdf) /D [3 0 R /XYZ 5 6 2] >>" } })
C.ACT_GOTOR_NO_F = link({ { "A", "<< /S /GoToR /D [3 0 R /Fit] >>" } })
C.ACT_GOTOR_F_DICT = link({ { "A", "<< /S /GoToR /F (other.pdf) /D << /D [3 0 R /XYZ 7 8 1] /S /XYZ >> >>" } })
C.ACT_RESET = link({ { "A", "<< /S /ResetForm /Fields [(f1) (f2)] >>" } })
C.ACT_RESET_NO_FIELDS = link({ { "A", "<< /S /ResetForm >>" } })
C.ACT_RESET_FLAGS = link({ { "A", "<< /S /ResetForm /Flags 1 /Fields [(f1)] >>" } })

C.ANN_DEST_ARRAY = link({ { "Dest", "[3 0 R /XYZ 11 22 0.5]" } })
C.ANN_DEST_DICT = link({ { "Dest", "<< /D [3 0 R /XYZ 33 44 2.5] /S /XYZ >>" } })
C.ANN_DEST_FIT = link({ { "Dest", "[3 0 R /Fit]" } })
C.ANN_DEST_NAMED = link({ { "Dest", "(chapter1)" } })
C.ANN_DEST_AND_A = link({ { "Dest", "[3 0 R /XYZ 1 2 3]" }, { "A", "<< /S /GoTo /D [3 0 R /Fit] >>" } })

C.ACT_GOTOR_PAGE2 = link({ { "A", "<< /S /GoToR /F (other.pdf) /D [4 0 R /Fit] >>" } })
C.ACT_GOTO_XYZ_TWO = link({ { "A", "<< /S /GoTo /D [3 0 R /XYZ 5 6] >>" } })
C.ACT_GOTO_XYZ_ONE = link({ { "A", "<< /S /GoTo /D [3 0 R /XYZ 7] >>" } })
C.ACT_GOTO_XYZ_ZERO = link({ { "A", "<< /S /GoTo /D [3 0 R /XYZ 0 0 0] >>" } })
C.ACT_GOTO_NO_PAGE_ARRAY = link({ { "A", "<< /S /GoTo /D [/XYZ 1 2 3] >>" } })
C.ACT_GOTO_D_NUMBER = link({ { "A", "<< /S /GoTo /D 3 >>" } })
C.ACT_GOTO_D_DICT = link({ { "A", "<< /S /GoTo /D << /D [3 0 R /XYZ 1 2 3] /S /XYZ >> >>" } })
C.ACT_GOTO_XYZ_NEGATIVE = link({ { "A", "<< /S /GoTo /D [3 0 R /XYZ -1 -2 -3] >>" } })
C.ACT_GOTO_UNKNOWN_NAME = link({ { "A", "<< /S /GoTo /D [3 0 R /Bogus 1 2] >>" } })
C.ACT_GOTO_NAME_ONLY = link({ { "A", "<< /S /GoTo /D [3 0 R /XYZ] >>" } })
C.ACT_GOTO_PAGE_ONLY = link({ { "A", "<< /S /GoTo /D [3 0 R] >>" } })
C.ACT_GOTO_WRONG_NAME = link({ { "A", "<< /S /GoTo /D [3 0 R /Zoom 3] >>" } })
C.ACT_GOTO_BADPAGE_XYZ = link({ { "A", "<< /S /GoTo /D [99 0 R /XYZ 1 2 3] >>" } })

-- the /Flags of a /ResetForm; flags and fields are false when absent
local function reset(flags, fields)
  local body = "<< /S /ResetForm"
  if flags then body = body .. " /Flags " .. flags end
  if fields then body = body .. " /Fields [(" .. fields .. ")]" end
  return link({ { "A", body .. " >>" } })
end

C.ACT_RESET_FLAG_TABLE = {
  reset(false, "f1"), reset(0, "f1"), reset(1, "f1"), reset(2, "f1"), reset(3, "f1"),
  reset(1, false), reset(2, false),
}
C.ACT_URI_RELATIVE = link({ { "A", "<< /S /URI /URI (relative/path.pdf) >>" } })
C.ACT_URI_FRAGMENT = link({ { "A", "<< /S /URI /URI (https://example.com/a#frag) >>" } })
C.ACT_GOTOR_HTTP = link({ { "A", "<< /S /GoToR /F (https://example.com/other.pdf) /D [3 0 R /Fit] >>" } })

C.DESTS_TREE = "<< /Names [(chapter1) [3 0 R /XYZ 77 88 0]] >>"
C.DESTS_DICT = "<< /chapter1 [3 0 R /XYZ 77 88 0] >>"

-- every name PDFActionNamed.h's enum declares, and one it does not; false is no /N at all
C.NAMED_NAMES = { false, "NextPage", "PreviousPage", "FirstPage", "LastPage", "GoBack", "GoForward",
  "GoToPage", "Find", "Print", "ZoomIn", "ZoomOut", "NotAName" }
C.NAMED_ACTIONS = {}
for _, name in ipairs(C.NAMED_NAMES) do
  C.NAMED_ACTIONS[#C.NAMED_ACTIONS + 1] = link({
    { "A", "<< /S /Named" .. (name and (" /N /" .. name) or "") .. " >>" },
  })
end

C.ACT_GOTOR_INDEX = link({ { "A", "<< /S /GoToR /F (other.pdf) /D 1 >>" } })
C.ACT_RESET_FLAGS_ONLY = link({ { "A", "<< /S /ResetForm /Flags 1 >>" } })
C.ACT_RESET_EXCLUDE = link({ { "A", "<< /S /ResetForm /Flags 2 /Fields [(f1)] >>" } })

-- ---- the lists, one per fixture file, in the Python's order -------------------------------------

C.WIDGET_BC_LIST = { C.BC_CMYK, C.BC_STRING, C.BC_NUMBER, C.BC_RGB }

-- the widget of every button-as-alone and button-merged shape is built above; the /Yes /Off merged
-- field values and states are the loops in main()

-- ---- main -------------------------------------------------------------------------------------------

local function shapes_list()
  local shapes = {
    { "border-plain.pdf", { C.BORDER_PLAIN } },
    { "border-radii.pdf", { C.BORDER_RADII } },
    { "border-zero.pdf", { C.BORDER_ZERO } },
    { "border-negative.pdf", { C.BORDER_NEGATIVE } },
    { "border-bs.pdf", { C.BORDER_BS } },
    { "border-short.pdf", { C.BORDER_SHORT } },
    { "border-long.pdf", { C.BORDER_LONG } },
    { "border-none.pdf", { C.BORDER_NONE } },
    { "border-link.pdf", { C.BORDER_LINK } },
    { "border-radii-only.pdf", { C.BORDER_RADII_ONLY } },
  }
  for _, letter in ipairs({ "S", "D", "B", "I", "U", "Q" }) do
    shapes[#shapes + 1] = { "bs-" .. letter:lower() .. ".pdf", { C["BS_" .. letter] } }
  end
  local rest = {
    { "bs-dash-solid.pdf", { C.BS_DASH_SOLID } },
    { "bs-no-width.pdf", { C.BS_NO_WIDTH } },
    { "bs-width-only.pdf", { C.BS_WIDTH_ONLY } },
    { "bs-style-only.pdf", { C.BS_STYLE_ONLY } },
    { "bs-dash-custom.pdf", { C.BS_DASH_CUSTOM } },
    { "bs-dash-string.pdf", { C.BS_DASH_STRING } },
    { "bs-width-string.pdf", { C.BS_WIDTH_STRING } },
  }
  for _, shape in ipairs(rest) do shapes[#shapes + 1] = shape end
  for _, kind in ipairs({ "Text", "FreeText", "Line", "Circle", "Highlight", "Underline", "StrikeOut", "Ink", "Stamp", "Popup" }) do
    shapes[#shapes + 1] = { "noborder-" .. kind:lower() .. ".pdf", { C.NOBORDER[kind] } }
  end
  local more = {
    { "noborder-widget.pdf", { C.NOBORDER_Widget } },
    { "noborder-widget-t.pdf", { C.NOBORDER_WidgetT } },
    { "noborder-widget-bg.pdf", { C.NOBORDER_WidgetBG } },
    { "noborder-widget-bc.pdf", { C.NOBORDER_WidgetBC } },
    { "noborder-widget-bc-gray.pdf", { C.NOBORDER_WidgetBCgray } },
    { "noborder-widget-bc-empty.pdf", { C.NOBORDER_WidgetEmptyBC } },
    { "noborder-line-l.pdf", { C.NOBORDER_LineL } },
    { "noborder-widget-tm.pdf", { C.NOBORDER_WidgetTm } },
    { "border-on-nontype.pdf", C.BORDER_ON_NONTYPE },
    { "bs-on-nontype.pdf", C.BS_ON_NONTYPE },
    { "act-goto-xyz.pdf", { C.ACT_GOTO_XYZ } },
    { "act-goto-fit.pdf", { C.ACT_GOTO_FIT } },
    { "act-goto-fitb.pdf", { C.ACT_GOTO_FITB } },
    { "act-goto-fith.pdf", { C.ACT_GOTO_FITH } },
    { "act-goto-fitbh.pdf", { C.ACT_GOTO_FITBH } },
    { "act-goto-fitbv.pdf", { C.ACT_GOTO_FITBV } },
    { "act-goto-zoom-int.pdf", { C.ACT_GOTO_ZOOM_INT } },
    { "act-goto-named.pdf", { C.ACT_GOTO_NAMED }, { { "dests", C.DESTS_TREE } }, " /Dests 8 0 R" },
    { "act-goto-named-dict.pdf", { C.ACT_GOTO_NAMED }, { { "dests", C.DESTS_DICT } }, " /Dests 8 0 R" },
    { "act-named-all.pdf", C.NAMED_ACTIONS },
    { "act-gotor-index.pdf", { C.ACT_GOTOR_INDEX, C.ACT_RESET_FLAGS_ONLY, C.ACT_RESET_EXCLUDE } },
    { "act-no-s.pdf", { C.ACT_NO_S } },
    { "act-unknown-s.pdf", { C.ACT_UNKNOWN_S } },
    { "act-goto-no-d.pdf", { C.ACT_GOTO_NO_D } },
    { "act-named.pdf", { C.ACT_NAMED_NEXT, C.ACT_NAMED_FIRST, C.ACT_NAMED_ZOOMIN, C.ACT_NAMED_NONSENSE } },
    { "act-uri.pdf", { C.ACT_URI, C.ACT_URI_NO_URI } },
    { "act-gotor.pdf", { C.ACT_GOTOR, C.ACT_GOTOR_NO_F, C.ACT_GOTOR_F_DICT } },
    { "act-reset.pdf", { C.ACT_RESET, C.ACT_RESET_NO_FIELDS, C.ACT_RESET_FLAGS } },
    { "act-goto-page2.pdf", { C.ACT_GOTO_PAGE2 }, {}, "", "", 2 },
    { "act-goto-bad-page.pdf", { C.ACT_GOTO_BAD_PAGE }, {}, "", "", 2 },
    { "act-goto-badpage-xyz.pdf", { C.ACT_GOTO_BADPAGE_XYZ } },
    { "act-goto-shapes.pdf", {
      C.ACT_GOTO_XYZ_TWO, C.ACT_GOTO_XYZ_ONE, C.ACT_GOTO_XYZ_ZERO,
      C.ACT_GOTO_NO_PAGE_ARRAY, C.ACT_GOTO_D_NUMBER, C.ACT_GOTO_D_DICT,
      C.ACT_GOTO_PAGE_ONLY, C.ACT_GOTO_WRONG_NAME,
      C.ACT_GOTO_XYZ_NEGATIVE, C.ACT_GOTO_UNKNOWN_NAME,
      C.ACT_GOTO_NAME_ONLY,
    } },
    { "act-goto-page2.pdf", { C.ACT_GOTOR_PAGE2 }, {}, "", "", 2 },
    { "act-reset-flags.pdf", C.ACT_RESET_FLAG_TABLE },
    { "act-uri-shapes.pdf", { C.ACT_URI_RELATIVE, C.ACT_URI_FRAGMENT } },
    { "act-gotor-http.pdf", { C.ACT_GOTOR_HTTP } },
    { "ann-dest-array.pdf", { C.ANN_DEST_ARRAY } },
    { "ann-dest-dict.pdf", { C.ANN_DEST_DICT } },
    { "ann-dest-fit.pdf", { C.ANN_DEST_FIT } },
    { "ann-dest-named.pdf", { C.ANN_DEST_NAMED }, { { "dests", C.DESTS_TREE } }, " /Dests 8 0 R" },
    { "ann-dest-named-dict.pdf", { C.ANN_DEST_NAMED }, { { "dests", C.DESTS_DICT } }, " /Dests 8 0 R" },
    { "ann-dest-and-a.pdf", { C.ANN_DEST_AND_A } },
    { "drops.pdf", C.DROPS },
    { "widget-bc.pdf", C.WIDGET_BC_LIST },
    { "popup-flags.pdf", { C.POPUP_F4, C.POPUP_F0, C.POPUP_F2, C.POPUP_NOF, C.SQUARE_F4, C.STAMP_F4 } },
    { "widget-names.pdf", { C.WIDGET_T, C.WIDGET_T_NOFT, C.WIDGET_T_TX, C.WIDGET_TU_TX, C.WIDGET_NO_T, C.SQUARE_T } },
    { "mk-full.pdf", { C.MK_FULL } },
    { "mk-bare.pdf", { C.MK_BARE } },
    { "mk-none.pdf", { C.MK_NONE } },
    { "mk-gray.pdf", { C.MK_GRAY } },
    { "mk-cmyk.pdf", { C.MK_CMYK } },
    { "mk-none-c.pdf", { C.MK_NONE_C } },
    { "mk-two.pdf", { C.MK_TWO } },
    { "mk-rot-real.pdf", { C.MK_ROT_REAL } },
    { "mk-r-zero.pdf", { C.MK_R_ZERO } },
  }
  for _, shape in ipairs(more) do shapes[#shapes + 1] = shape end
  return shapes
end

-- the outline fixtures: name, spec, sign of the root /Count, the signs by title, and the extra page annotations
local OUTLINE_FILES = {
  { "outline-collapsed.pdf", C.OUTLINE_OPEN, -1, false, 0 },
  { "outline-expanded.pdf", C.OUTLINE_CLOSED, 1, false, 0 },
  { "outline-shapes.pdf", C.OUTLINE_SHAPES, -1, false, 0 },
  { "outline-signs.pdf", C.OUTLINE_SIGNS, -1, C.OUTLINE_SIGNS_SIGNS, 0 },
  { "outline-nocount.pdf", C.OUTLINE_NO_COUNT, -1, false, 0 },
  { "outline-isopen.pdf", C.OUTLINE_ISOPEN, -1, false, 0 },
  -- the SAME shapes as outline-shapes.pdf with ONE annotation added to the page
  { "outline-shapes2.pdf", C.OUTLINE_SHAPES, -1, false, 1 },
  { "outline-untitled.pdf", C.OUTLINE_UNTITLED, -1, false, 0 },
  { "outline-titled.pdf", C.OUTLINE_TITLED, -1, false, 0 },
  { "outline-titlekey.pdf", C.OUTLINE_TITLE_KEY, -1, false, 0 },
}

function main(...)
  local directory = ...
  if directory == nil then
    io.stderr:write("usage: make-object-fixtures.lua <directory>\n")
    os.exit(2)
  end
  os.iorunv("/bin/mkdir", { "-p", directory })

  local function say(line)
    print(line)
  end

  -- annotation-colours.pdf
  do
    local name = "annotation-colours.pdf"
    local count = build(join(directory, name), C.COLOUR_SHAPES)
    say(string.format("  wrote %-20s %d objects, %d annotations", name, count, #C.COLOUR_SHAPES))
  end

  -- the button and text /AS and /V files
  local button_files = {
    { "button-asoff-von.pdf", C.BUTTON_AS_OFF_V_ON },
    { "button-v-only.pdf", C.BUTTON_V_ONLY },
    { "button-asyes-voff.pdf", C.BUTTON_AS_YES_V_OFF },
    { "button-ap-states.pdf", C.BUTTON_AP_STATES },
    { "button-as-alone.pdf", C.BUTTON_AS_ALONE },
    { "button-as-and-v.pdf", C.BUTTON_AS_AND_V },
    { "text-as.pdf", C.TEXT_AS },
  }
  for _, entry in ipairs(button_files) do
    local name, annotations = entry[1], entry[2]
    local count = build(join(directory, name), annotations)
    say(string.format("  wrote %-20s %d objects, %d annotations", name, count, #annotations))
  end

  -- the merged field shape: /V on the field, /AS on the widget
  for _, value in ipairs({ "/Yes", "/Off" }) do
    for _, state in ipairs({ "/Off", "/On", "/Yes" }) do
      local name = "button-merged-v" .. slug(value) .. "-as" .. slug(state) .. ".pdf"
      local count = build_merged_field(directory, name, as_bytes(state), "/V " .. value, "/Btn")
      say(string.format("  wrote %-20s %d objects, a /Btn field /V %s and a widget /AS %s",
        name, count, value, state))
    end
  end

  -- /T plus one more key
  for index, annotations in ipairs(C.T_WITH_ONE_MORE) do
    local name = "widget-t-extra-" .. C.T_WITH_ONE_MORE_NAMES[index] .. ".pdf"
    local count = build(join(directory, name), annotations)
    say(string.format("  wrote %-20s %d objects, /T plus one more key", name, count))
  end
  for _, entry in ipairs({
    { "widget-t-literal.pdf", C.T_LITERAL },
    { "widget-t-name.pdf", C.T_NAME },
    { "widget-t-empty.pdf", C.T_EMPTY },
  }) do
    local name, annotations = entry[1], entry[2]
    local count = build(join(directory, name), annotations)
    say(string.format("  wrote %-20s %d objects, %d annotations", name, count, #annotations))
  end
  for _, entry in ipairs({
    { "widget-t-merged.pdf", "" },
    { "widget-t-mergedname.pdf", " /T (child too)" },
  }) do
    local name, child_extra = entry[1], entry[2]
    local count = build_merged_field(directory, name, child_extra)
    say(string.format("  wrote %-20s %d objects, a widget whose /Parent is a field", name, count))
  end

  for _, entry in ipairs({
    { "widget-flags.pdf", C.WIDGET_FLAGS },
    { "widget-noflags.pdf", C.WIDGET_NO_FLAGS },
    { "widget-allflags.pdf", C.WIDGET_ALL_FLAGS },
    { "widget-fieldtypes.pdf", C.WIDGET_FIELD_TYPES },
    { "widget-states.pdf", C.WIDGET_STATES },
    { "widget-values.pdf", C.WIDGET_VALUES },
    { "widget-mixed.pdf", C.WIDGET_MIXED },
    { "synth-widgets.pdf", C.SYNTH_COUNT_WIDGETS_ONLY },
    { "synth-linkfirst.pdf", C.SYNTH_COUNT_LINK_FIRST },
    { "synth-linkmiddle.pdf", C.SYNTH_COUNT_LINK_MIDDLE },
  }) do
    local name, annotations = entry[1], entry[2]
    local count = build(join(directory, name), annotations)
    say(string.format("  wrote %-20s %d objects, %d annotations", name, count, #annotations))
  end

  -- one field type per file, numbered by position
  local field_type_one = {
    { "/Btn", { widget({}, "/Btn") } },
    { "/Tx", { widget({}, "/Tx") } },
    { "/Ch", { widget({}, "/Ch") } },
    { "/Sig", { widget({}, "/Sig") } },
    { "/Ch", { widget({ { "Opt", "[(one) (two)]" } }, "/Ch") } },
    { "/Ch", { widget({ { "Opt", "(not an array)" } }, "/Ch") } },
  }
  for position, entry in ipairs(field_type_one) do
    local field_type, annotations = entry[1], entry[2]
    local name = "widget-ft" .. slug(field_type) .. (position - 1) .. ".pdf"
    local count = build(join(directory, name), annotations)
    say(string.format("  wrote %-20s %d objects, %d annotations", name, count, #annotations))
  end

  for _, entry in ipairs(OUTLINE_FILES) do
    local name, spec, sign, signs, extra = entry[1], entry[2], entry[3], entry[4], entry[5]
    local count, root, items = build_outline(directory, name, spec, sign, 1, signs, extra)
    local item_names = {}
    for i, n in ipairs(items) do item_names[i] = tostring(n) end
    say(string.format("  wrote %-20s %d objects, outline root %d, items %s",
      name, count, root, table.concat(item_names, ",")))
  end

  -- the shapes, in order; a later entry of the same name overwrites an earlier one
  for _, shape in ipairs(shapes_list()) do
    local name, annotations = shape[1], shape[2]
    local extra = shape[3] or {}
    local catalog_extra = shape[4] or ""
    local page_count = shape[6] or 1
    local count = build(join(directory, name), annotations, extra, catalog_extra, page_count)
    say(string.format("  wrote %-20s %d objects", name, count))
  end
end
