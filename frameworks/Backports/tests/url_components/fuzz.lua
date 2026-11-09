local SCHEMES = {"http", "https", "ftp", "file", "mailto", "tel", "a", "HTTP", "x+y-z.w", "1x", "x_y", "-a", "a b", "", "javascript", "data", "ws", "imap",
                 "addressbook", "http+unix", "h\195\169llo", "a:b"}
local USERS = {"", "u", "user", "us er", "u%40", "u:p", "u:p:q", "\195\169", "u@x", "%", "%4", "%zz", "a/b", "a?b", "a#b", "p@ss", "[x]"}
local HOSTS = {"example.com", "EXAMPLE.com", "ex ample.com", "exa_mple.com", "a..b", "-a.com", "a-.com", "xn--abc.com", "xn--80ak6aa92e.com",
               "\228\190\139\229\173\144.\230\181\139\232\175\149", "b\195\188cher.de", "\195\159.de", "\199\134.com", "a%20b.com", "a%2e.com", "%", "[::1]", "[::1", "::1]",
               "[v1.x]", "[fe80::1%25en0]", "[fe80::1%en0]", "[::1]x", "1.2.3.4", "256.1.1.1", "", "a.b.c.d.e.f", "UPPER", "a\226\128\139b.com",
               "a\226\128\141b.com", "\240\159\152\128.com", "\239\189\129\239\189\130\239\189\131.com", "a.com.", ".", "..", string.rep("a", 70) .. ".com",
               "a<b.com", "a\"b", "a\\b", "a^b", "a{b}", "a|b", "a`b", "a[b", "a]b", "a!b$c&d'e(f)g*h+i,j;k=l", "\204\129a.com", "xn--", "xn--a.com",
               "\208\191\209\128\208\184\208\188\208\181\209\128.\209\128\209\132", "\216\167\216\174\216\170\216\168\216\167\216\177.com", "caf\195\169.com", "CAF\195\137.com"}
local PORTS = {"", "0", "80", "8080", "99999", "65536", "12345678901234567890", "a", "8a", "-1", "+1", " 1", "\239\188\144", "1:2"}
local PATHS = {"", "/", "/a", "/a/b/", "/a b", "/a%20b", "/a%2", "/a%zz", "/\195\169", "a", "a:b", ":", "/..", "/a;b=c", "/%E2%82%AC", "/\\", "/a|b", "/[x]",
               "//", "/\240\159\152\128", "/a%", "%", "/a%%41", "/\127", "/\t", "/a%41%", "/%4", "/a\"b<c>", "/{}", "/^`", "a/b:c", "/a:b", "/@", "/a@b"}
local QUERIES = {"", "a=b", "a=b&c=d", "a b", "a=%", "\195\169=\195\188", "a[]=1", "a=b?c", "?", "%", "q=%41", "q=\"x\"", "{}", "a=b#", "a%zz", "\240\159\152\128"}
local FRAGMENTS = {"", "f", "a b", "%", "%41", "f?g", "f#g", "\195\169", "[x]", "\"x\"", "a%2", "{}"}
local POOL = {"a", "b", "z", "A", "0", "9", ":", "/", "?", "#", "[", "]", "@", "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "=", "%", "-", ".", "_", "~",
              " ", "\"", "<", ">", "\\", "^", "`", "{", "|", "}", "\195\169", "\228\190\139", "\240\159\152\128", "\t", "\1", "\127", "%4", "%41", "%zz", "//", "http:",
              "xn--", "%25", ".."}

local function generator(seed)
    local state = seed
    local function pick(limit)
        state = (state * 69069 + 1) % 4294967296
        return math.floor(state / 65536) % limit + 1
    end
    local function choose(list)
        return list[pick(#list)]
    end
    local function composed()
        local parts = {}
        if pick(4) > 1 then
            table.insert(parts, choose(SCHEMES) .. ":")
        end
        if pick(3) > 1 then
            local authority = "//"
            if pick(3) == 1 then
                authority = authority .. choose(USERS)
                if pick(2) == 1 then
                    authority = authority .. ":" .. choose(USERS)
                end
                authority = authority .. "@"
            end
            authority = authority .. choose(HOSTS)
            if pick(3) == 1 then
                authority = authority .. ":" .. choose(PORTS)
            end
            table.insert(parts, authority)
        end
        table.insert(parts, choose(PATHS))
        if pick(3) == 1 then
            table.insert(parts, "?" .. choose(QUERIES))
        end
        if pick(3) == 1 then
            table.insert(parts, "#" .. choose(FRAGMENTS))
        end
        local text = table.concat(parts)
        return text == "" and "<empty>" or text
    end
    local function random()
        local pieces = {}
        for _ = 1, pick(14) do
            table.insert(pieces, choose(POOL))
        end
        return table.concat(pieces)
    end
    return {composed = composed, random = random}
end

function lines(count, seed)
    local make = generator(seed)
    local seen, out = {}, {}
    while #out < count do
        local line = #out % 2 == 0 and make.composed() or make.random()
        if not seen[line] and not line:find("[\n\0]") then
            seen[line] = true
            table.insert(out, line)
        end
    end
    return out
end
