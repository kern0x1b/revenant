local DEFAULT_IMAGE = "RecaptchaEnterprise"

local GUEST_IMAGES = {
    {0x0000000, "the SDK"},
    {0x0200000, "libswiftCore"},
    {0x0800000, "libc++"},
    {0x0a00000, "CoreFoundation"},
    {0x0f00000, "Foundation overlay"},
    {0x1600000, "libxl-guest stubs"},
}
local GUEST_IMAGE_ALIGNMENT = 0x100000

local function guest_image(address, symbols)
    local found = "?"
    for _, entry in ipairs(symbols.images or GUEST_IMAGES) do
        if address >= (symbols.images and 0 or symbols.base) + entry[1] then
            found = entry[2]
        end
    end
    return found
end

local function load_images(lines)
    local images = {}
    for line in lines do
        local low, name = line:match("^(%x+) %x+ (.+)$")
        if low then
            table.insert(images, {tonumber(low, 16), name})
        end
    end
    table.sort(images, function(a, b) return a[1] < b[1] end)
    return images
end

local function load_symbols(lines)
    local addresses, names = {}, {}
    for line in lines do
        local address, kind, name = line:match("^(%x%x%x%x%x%x%x%x) (%a) (%S+)$")
        if address and (kind == "t" or kind == "T") then
            table.insert(addresses, tonumber(address, 16))
            table.insert(names, name)
        end
    end
    local order = {}
    for index = 1, #addresses do
        order[index] = index
    end
    table.sort(order, function(a, b) return addresses[a] < addresses[b] end)
    local sorted_addresses, sorted_names = {}, {}
    local lowest
    for index, original in ipairs(order) do
        sorted_addresses[index] = addresses[original]
        sorted_names[index] = names[original]
        local guest = tonumber(names[original]:match("^_sub_(%x+)$") or "", 16)
        if guest and (not lowest or guest < lowest) then
            lowest = guest
        end
    end
    return {addresses = sorted_addresses, names = sorted_names, base = lowest and lowest - lowest % GUEST_IMAGE_ALIGNMENT or 0}
end

local function resolve(symbols, offset)
    local low, high, best = 1, #symbols.addresses, nil
    while low <= high do
        local middle = (low + high) // 2
        if symbols.addresses[middle] <= offset then
            best = middle
            low = middle + 1
        else
            high = middle - 1
        end
    end
    if not best then
        return nil
    end
    return symbols.names[best], offset - symbols.addresses[best]
end

local function describe(symbols, image, offset, symbol)
    local name, distance = resolve(symbols, offset)
    if not name then
        return string.format("%s+0x%x", image, offset), image .. " (unresolved)"
    end
    local guest = name:match("^_sub_(%x+)")
    local where = guest and string.format("guest 0x%s (%s)", guest, guest_image(tonumber(guest, 16), symbols)) or "host code of the library"
    return string.format("%s+0x%x  %s", name, distance, where), name
end

local function read_profile(lines, symbols, image_pattern)
    local windows, current = {}, nil
    for line in lines do
        local samples, messages, dynamic, routing, call =
            line:match("xlate: profile: (%d+) samples of running threads in 5 s, (%d+) messages %((%d+) dynamic%), routing (%d+) us, host call of the dynamic ones (%d+) us")
        if samples then
            current = {samples = tonumber(samples), messages = tonumber(messages), dynamic = tonumber(dynamic),
                       routing = tonumber(routing), call = tonumber(call), buckets = {}, sent = {}}
            table.insert(windows, current)
        else
            local name, times, us = line:match("xlate:%s+sent ([+-]%[%S+ %S+%]) (%d+) times, (%d+) us")
            if name and current then
                table.insert(current.sent, {name = name, times = tonumber(times), us = tonumber(us)})
            end
            local count, address, inside = line:match("xlate:%s+(%d+) samples at 0x(%x+) %((.-)%)")
            if count and current then
                local image, offset, rest = inside:match("^([^%s+]+)%+0x(%x+)%s*(.*)$")
                local entry = {count = tonumber(count), address = tonumber(address, 16), image = image or "?", symbol = rest or ""}
                if image and image:find(image_pattern, 1, true) then
                    entry.text, entry.function_name = describe(symbols, image, tonumber(offset, 16), rest)
                else
                    entry.text = string.format("%s+0x%s %s", image or "?", offset or "0", rest or "")
                    entry.function_name = (image or "?") .. " " .. (rest or "")
                end
                table.insert(current.buckets, entry)
            end
        end
    end
    return windows
end

local function report(windows)
    local out, totals = {}, {}
    for index, window in ipairs(windows) do
        table.insert(out, string.format("window %d: %d samples, %d messages (%d dynamic), routing %d us, host call %d us",
                                        index, window.samples, window.messages, window.dynamic, window.routing, window.call))
        for _, bucket in ipairs(window.buckets) do
            table.insert(out, string.format("  %5d  %s", bucket.count, bucket.text))
            totals[bucket.function_name] = (totals[bucket.function_name] or 0) + bucket.count
        end
        for _, sent in ipairs(window.sent) do
            table.insert(out, string.format("  %7d sent %s, %d us", sent.times, sent.name, sent.us))
        end
    end
    local ranked = {}
    for name, count in pairs(totals) do
        table.insert(ranked, {name = name, count = count})
    end
    table.sort(ranked, function(a, b) return a.count > b.count end)
    table.insert(out, "")
    table.insert(out, "by function over all windows:")
    for index, item in ipairs(ranked) do
        if index > 15 then
            break
        end
        table.insert(out, string.format("  %5d  %s", item.count, item.name))
    end
    return table.concat(out, "\n")
end

local function iterate(list)
    local index = 0
    return function()
        index = index + 1
        return list[index]
    end
end

local function self_test()
    local symbols = load_symbols(iterate({
        "         U _CC_SHA256",
        "00001000 t _sub_18000100",
        "00001400 t _sub_18200200",
        "00002000 T _xl_library_init",
        "00003000 t _sub_19600010",
    }))
    local windows = read_profile(iterate({
        "xlate: profile: 240 samples of running threads in 5 s, 1200 messages (30 dynamic), routing 15000 us, host call of the dynamic ones 400 us",
        "xlate:     180 samples at 0x10fb1440 (RecaptchaEnterprise.dylib+0x1440) [the library]",
        "xlate:      40 samples at 0x10fb1480 (RecaptchaEnterprise.dylib+0x1480) [the library]",
        "xlate:      20 samples at 0x3010aa40 (libobjc.A.dylib+0x6a40 objc_msgSend)",
        "xlate:   sent -[__NSCFString characterAtIndex:] 300000 times, 1800000 us",
        "xlate:   sent +[NSString stringWithUTF8String:] 40 times, 90 us",
        "xlate: profile: 10 samples of running threads in 5 s, 5 messages (0 dynamic), routing 60 us, host call of the dynamic ones 0 us",
        "xlate:      10 samples at 0x10fb2040 (RecaptchaEnterprise.dylib+0x2040) [the library]",
    }), symbols, DEFAULT_IMAGE)
    local function expect(condition, message)
        if not condition then
            raise("profile_symbols self-test: " .. message)
        end
    end
    expect(#windows == 2, "two windows")
    expect(#windows[1].sent == 2 and windows[1].sent[1].times == 300000 and windows[1].sent[1].name == "-[__NSCFString characterAtIndex:]",
           "the sent lines of a window are read")
    expect(#windows[2].sent == 0, "a window without sent lines has none")
    expect(windows[1].buckets[1].function_name == "_sub_18200200", "an offset inside _sub_18200200 resolves to it, got " .. tostring(windows[1].buckets[1].function_name))
    expect(windows[1].buckets[1].text:find("libswiftCore", 1, true), "guest 0x18200200 is in libswiftCore")
    expect(windows[1].buckets[2].function_name == "_sub_18200200", "the next bucket is the same function")
    expect(windows[1].buckets[3].function_name == "libobjc.A.dylib objc_msgSend", "a system image is named, not resolved")
    expect(windows[2].buckets[1].function_name == "_xl_library_init", "a host symbol of the library resolves to its name")
    expect(report(windows):find("   220  _sub_18200200", 1, true), "the report adds the buckets of one function")
    local moved = load_symbols(iterate({"00001000 t _sub_2e000100", "00001400 t _sub_2e800200", "00003000 t _sub_2f600010"}))
    expect(moved.base == 0x2e000000 and describe(moved, DEFAULT_IMAGE, 0x1440, ""):find("guest 0x2e800200 (libc++)", 1, true) and
           describe(moved, DEFAULT_IMAGE, 0x3000, ""):find("libxl-guest stubs", 1, true),
           "the images are found from the base of the symbols file, whatever XL_BASE the drop was translated with")
    moved.images = load_images(iterate({"2e000000 2e160000 RecaptchaEnterprise", "2e160000 2e6c0000 libswiftCore.dylib", "2e6c0000 2e7a0000 libc++.1.dylib"}))
    expect(describe(moved, DEFAULT_IMAGE, 0x1000, ""):find("guest 0x2e000100 (RecaptchaEnterprise)", 1, true) and
           describe(moved, DEFAULT_IMAGE, 0x1440, ""):find("guest 0x2e800200 (libc++.1.dylib)", 1, true),
           "with the images file of a drop the images are the ones the translator laid out, at their own addresses")
    print("%s", report(windows))
    print("ok: profile_symbols self-test")
end

function main(...)
    local arguments = {...}
    if arguments[1] == "--self-test" then
        return self_test()
    end
    local symbols_file, stderr_file = arguments[1], arguments[2]
    if not symbols_file or not stderr_file then
        raise("usage: profile_symbols.lua SYMBOLS.txt STDERR.txt [IMAGE-NAME-PART]   or   profile_symbols.lua --self-test")
    end
    local image_pattern = arguments[3] or DEFAULT_IMAGE
    local symbols = load_symbols(io.lines(symbols_file))
    if #symbols.addresses == 0 then
        raise("no text symbols in %s", symbols_file)
    end
    local images_file = symbols_file:gsub("%.symbols%.txt$", ".images.txt")
    if images_file ~= symbols_file and os.isfile(images_file) then
        symbols.images = load_images(io.lines(images_file))
    end
    local windows = read_profile(io.lines(stderr_file), symbols, image_pattern)
    if #windows == 0 then
        raise("no 'xlate: profile:' lines in %s (was the flag /private/var/revenant/xl-stats there before the process started?)", stderr_file)
    end
    print("%s", report(windows))
end
