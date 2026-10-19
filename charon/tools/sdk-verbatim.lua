-- xmake l tools/sdk-verbatim.lua [--words N] SDKROOT FILE...
--
-- Finds the comment text of FILE... that occurs verbatim among the comments of the SDK at SDKROOT.
-- A comment copied from an SDK header is Apple's expression in our tree, which the workspace rule keeps
-- out of a repository (2026-10-12). This is the mechanical half of that rule: it names each hit by file
-- and line, and a person decides whether the line is a fact (a declaration, a measured value) or prose.
--
-- A comment run is the text one comment holds on a source line: the part of `//` or `///` after the
-- marker, or the part of a `/* */` comment on the line, outside string and character literals. Both sides
-- are read the same way: the comment markers (`/`, `!`, `*`) and a trailing `*/` are dropped, whitespace
-- runs collapse to one space, the text is trimmed and lower-cased. Declarations are not comment text and
-- are not read: a signature is a fact, and a port comment that repeats one is not a copy of Apple's prose.
--
-- Two modes run on every call:
--   run     one of our comment runs equals one of the SDK's. Compared when it has a letter or digit and is
--           at least 19 characters OR at least 4 words: the floor is "19 characters or 4 words", so a run of
--           four words is compared at any length, and a run of up to three words only at 19 characters or
--           more. Shorter runs are too common to mean a copy, and a ruler is a shape.
--   wordsN  N consecutive words of our comment text occur inside the SDK's comment text, N being --words N
--           (8 by default; the report and its hit labels say which). Comment text is
--           read in blocks here: the maximal run of consecutive comment lines of one file, joined by one
--           space, so a sentence that Apple wraps over several lines still matches. The windows are exact
--           Lua strings, not hashes, so there is no collision to count; the summary prints how many distinct
--           windows our files have.
--
-- Exit status (status()): 2 when an input cannot be read (the SDK root, one of our files, one SDK header);
-- otherwise 1 when a mode hit, whatever else the scan did, because a hit is never an error; otherwise 2 when
-- a mode compared nothing on either side, since a run that compared nothing is not a pass; otherwise 0.
-- The text of a hit is not printed, only its places.
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local MIN_CHARS, MIN_WORDS = 19, 4
local DEFAULT_WORDS = 8
local SDK_DIRS = {"System/Library/Frameworks", "usr/include"}

local function normalise(text)
    text = text:gsub("%s*%*/%s*$", "")
    text = text:gsub("^%s*[/!*]+", "")
    text = text:gsub("%s+", " ")
    text = text:gsub("^ ", ""):gsub(" $", "")
    return text:lower()
end

local function words_of(text)
    local list = {}
    for w in text:gmatch("%S+") do list[#list + 1] = w end
    return list
end

-- A ruler (a line of dashes or stars) has no letter or digit and is not compared: it is a shape, not prose.
local function compared(text)
    if not text:find("%w") then return false end
    return #text >= MIN_CHARS or #words_of(text) >= MIN_WORDS
end

-- The comment runs of one line, given whether the line starts inside a block comment. Returns the runs
-- and whether the line ends inside a block comment. String and character literals are skipped, so a
-- `//` inside a string is not read as a comment.
local function comment_runs(line, in_block)
    local runs, i, n = {}, 1, #line
    while i <= n do
        if in_block then
            local close = line:find("*/", i, true)
            runs[#runs + 1] = line:sub(i, close and close - 1 or n)
            if not close then return runs, true end
            in_block = false
            i = close + 2
        else
            local one, two = line:sub(i, i), line:sub(i, i + 1)
            if one == '"' or one == "'" then
                local j = i + 1
                while j <= n and line:sub(j, j) ~= one do
                    if line:sub(j, j) == "\\" then j = j + 1 end
                    j = j + 1
                end
                i = j + 1
            elseif two == "//" then
                runs[#runs + 1] = line:sub(i + 2)
                return runs, false
            elseif two == "/*" then
                in_block = true
                i = i + 2
            else
                i = i + 1
            end
        end
    end
    return runs, in_block
end

-- Reads one file: on_run(text, line) for each comment run that has a letter or digit, and
-- on_block(text, first, last) for each block of consecutive comment lines, after its last line.
-- Returns false when the file cannot be read.
local function read_comments(file, on_run, on_block)
    local handle = io.open(file, "r")
    if not handle then return false end
    local in_block, block, first, last, n = false, {}, nil, nil, 0
    local function flush()
        if first then on_block(table.concat(block, " "), first, last) end
        block, first, last = {}, nil, nil
    end
    for line in handle:lines() do
        n = n + 1
        local runs
        runs, in_block = comment_runs(line, in_block)
        local got = false
        for _, run in ipairs(runs) do
            local text = normalise(run)
            if text:find("%w") then
                got = true
                on_run(text, n)
                block[#block + 1] = text
            end
        end
        if got then
            first = first or n
            last = n
        else
            flush()
        end
    end
    flush()
    handle:close()
    return true
end

-- Our side: the comment runs and the 8-word windows of every file, with the places each occurs.
local function read_ours(files, report, window)
    local runs, windows = {}, {}
    for _, file in ipairs(files) do
        local ok = read_comments(file,
            function(text, line)
                if compared(text) then
                    report.run_ours = report.run_ours + 1
                    runs[text] = runs[text] or {}
                    table.insert(runs[text], file .. ":" .. line)
                end
            end,
            function(text, first, last)
                local words = words_of(text)
                for i = 1, #words - window + 1 do
                    local gram = table.concat(words, " ", i, i + window - 1)
                    report.words_ours = report.words_ours + 1
                    windows[gram] = windows[gram] or {}
                    table.insert(windows[gram], file .. ":" .. first .. "-" .. last)
                end
            end)
        if ok then
            report.files = report.files + 1
        else
            table.insert(report.errors, "cannot read " .. file)
        end
    end
    return runs, windows
end

function scan(root, files, window)
    window = window or DEFAULT_WORDS
    local report = {errors = {}, empty = {}, hits = {}, files = 0, run_ours = 0, run_sdk = 0, words_ours = 0,
        words_sdk = 0, keys_ours = 0, sdk_headers = 0, window = window}
    local frameworks = path.join(root, SDK_DIRS[1])
    if not os.isdir(frameworks) then
        table.insert(report.errors, "SDK root unreadable: no " .. frameworks)
        return report
    end

    local runs, windows = read_ours(files, report, window)
    for _ in pairs(windows) do report.keys_ours = report.keys_ours + 1 end
    local run_hits, words_hits = {}, {}

    -- The SDK's comment runs and 8-word windows, each header read once.
    local headers = {}
    for _, dir in ipairs(SDK_DIRS) do
        for _, header in ipairs(os.files(path.join(root, dir, "**.h"))) do headers[#headers + 1] = header end
    end
    byteorder.sort(headers)
    for _, header in ipairs(headers) do
        local where = header:sub(#root + 2)
        report.sdk_headers = report.sdk_headers + 1
        local ok = read_comments(header,
            function(text, line)
                if compared(text) then report.run_sdk = report.run_sdk + 1 end
                if runs[text] then run_hits[text] = run_hits[text] or where .. ":" .. line end
            end,
            function(text, first, last)
                local words = words_of(text)
                for i = 1, #words - window + 1 do
                    local gram = table.concat(words, " ", i, i + window - 1)
                    report.words_sdk = report.words_sdk + 1
                    if windows[gram] then
                        for _, ours in ipairs(windows[gram]) do
                            words_hits[ours] = words_hits[ours] or (where .. ":" .. first .. "-" .. last)
                        end
                    end
                end
            end)
        if not ok then table.insert(report.errors, "cannot read SDK header " .. header) end
    end

    for text, sdk in pairs(run_hits) do
        for _, ours in ipairs(runs[text]) do
            table.insert(report.hits, "run " .. ours .. " " .. sdk)
        end
    end
    for ours, sdk in pairs(words_hits) do
        table.insert(report.hits, "words" .. window .. " " .. ours .. " " .. sdk)
    end
    byteorder.sort(report.hits)
    if report.run_ours == 0 or report.run_sdk == 0 then table.insert(report.empty, "run mode compared nothing") end
    if report.words_ours == 0 or report.words_sdk == 0 then
        table.insert(report.empty, "words" .. window .. " mode compared nothing")
    end
    return report
end

-- The exit status of a report (see the header): a hit is 1 even when a mode compared nothing, and an input
-- that could not be read is 2 even when there is a hit.
function status(report)
    if #report.errors > 0 then return 2 end
    if #report.hits > 0 then return 1 end
    if #report.empty > 0 then return 2 end
    return 0
end

function main(...)
    -- --words N may come anywhere before the files; the first argument left is the SDK root.
    local args, rest, window, i = {...}, {}, DEFAULT_WORDS, 1
    while i <= #args do
        if args[i] == "--words" then
            window = tonumber(args[i + 1] or "")
            if not window or window < 1 or window % 1 ~= 0 then
                print("sdk-verbatim: FAIL --words needs a whole number of 1 or more")
                os.exit(2)
            end
            i = i + 2
        else
            table.insert(rest, args[i])
            i = i + 1
        end
    end
    local root = table.remove(rest, 1)
    local files = rest
    if not root or #files == 0 then
        print("usage: xmake l tools/sdk-verbatim.lua [--words N] SDKROOT FILE...")
        os.exit(2)
    end
    local report = scan(root, files, window)
    for _, e in ipairs(report.errors) do print("sdk-verbatim: FAIL " .. e) end
    for _, e in ipairs(report.empty) do print("sdk-verbatim: " .. (#report.hits > 0 and "NOTE " or "FAIL ") .. e) end
    print(string.format("sdk-verbatim: compared %d comment run(s) of %d file(s) with %d SDK comment run(s) of %d header(s) (run mode); %d %d-word window(s) with %d of the SDK's (words%d mode, exact keys, no hash; %d distinct window(s) of ours)",
        report.run_ours, report.files, report.run_sdk, report.sdk_headers, report.words_ours, window, report.words_sdk, window, report.keys_ours))
    for _, hit in ipairs(report.hits) do print("HIT " .. hit) end
    print(string.format("sdk-verbatim: %d hit(s)", #report.hits))
    os.exit(status(report))
end
