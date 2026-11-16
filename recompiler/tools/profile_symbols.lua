local DEFAULT_IMAGE = "RecaptchaEnterprise"

local GUEST_IMAGES = {
    {0x18000000, "the SDK"},
    {0x18200000, "libswiftCore"},
    {0x18800000, "libc++"},
    {0x18a00000, "CoreFoundation"},
    {0x18f00000, "Foundation overlay"},
    {0x19600000, "libxl-guest stubs"},
}

local function guest_image(address)
    local found = "?"
    for _, entry in ipairs(GUEST_IMAGES) do
        if address >= entry[1] then
            found = entry[2]
        end
    end
    return found
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
    for index, original in ipairs(order) do
        sorted_addresses[index] = addresses[original]
        sorted_names[index] = names[original]
    end
    return {addresses = sorted_addresses, names = sorted_names}
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
    local where = guest and string.format("guest 0x%s (%s)", guest, guest_image(tonumber(guest, 16))) or "host code of the library"
    return string.format("%s+0x%x  %s", name, distance, where), name
end

local function read_profile(lines, symbols, image_pattern)
    local windows, current = {}, nil
    for line in lines do
        local samples, messages, dynamic, routing, call =
            line:match("xlate: profile: (%d+) samples of running threads in 5 s, (%d+) messages %((%d+) dynamic%), routing (%d+) us, host call of the dynamic ones (%d+) us")
        if samples then
            current = {samples = tonumber(samples), messages = tonumber(messages), dynamic = tonumber(dynamic),
                       routing = tonumber(routing), call = tonumber(call), buckets = {}}
            table.insert(windows, current)
        else
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
        "xlate: profile: 10 samples of running threads in 5 s, 5 messages (0 dynamic), routing 60 us, host call of the dynamic ones 0 us",
        "xlate:      10 samples at 0x10fb2040 (RecaptchaEnterprise.dylib+0x2040) [the library]",
    }), symbols, DEFAULT_IMAGE)
    local function expect(condition, message)
        if not condition then
            raise("profile_symbols self-test: " .. message)
        end
    end
    expect(#windows == 2, "two windows")
    expect(windows[1].buckets[1].function_name == "_sub_18200200", "an offset inside _sub_18200200 resolves to it, got " .. tostring(windows[1].buckets[1].function_name))
    expect(windows[1].buckets[1].text:find("libswiftCore", 1, true), "guest 0x18200200 is in libswiftCore")
    expect(windows[1].buckets[2].function_name == "_sub_18200200", "the next bucket is the same function")
    expect(windows[1].buckets[3].function_name == "libobjc.A.dylib objc_msgSend", "a system image is named, not resolved")
    expect(windows[2].buckets[1].function_name == "_xl_library_init", "a host symbol of the library resolves to its name")
    expect(report(windows):find("   220  _sub_18200200", 1, true), "the report adds the buckets of one function")
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
    local windows = read_profile(io.lines(stderr_file), symbols, image_pattern)
    if #windows == 0 then
        raise("no 'xlate: profile:' lines in %s (was the flag /private/var/revenant/xl-stats there before the process started?)", stderr_file)
    end
    print("%s", report(windows))
end
