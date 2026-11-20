// The emoji clusters of a text: the stretches the emoji font typesets whole (UAX #29 extended grapheme clusters over a pictographic), found
// without a list of sequences. The emoji font's cmap is replaced by a coverage predicate that, like the real font, also covers the joiner, the
// variation selectors, the modifiers, the tags, the regional indicators and the keycap base characters.
#import "../Foundation/check.h"
#import "revenant_emoji_clusters.h"

static int lookups;

static BOOL covered(UTF32Char c, void *context)
{
    lookups++;
    return (c >= 0x2190 && c <= 0x2BFF) || c == 0xA9 || c == 0xAE || c == 0x2122 || c == 0x203C ||
           (c >= 0x1F000 && c <= 0x1FAFF) || c == REVENANT_ZWJ || c == REVENANT_VS15 || c == REVENANT_VS16 || c == REVENANT_KEYCAP ||
           (c >= 0xE0020 && c <= 0xE007F) || (c >= '0' && c <= '9') || c == '#' || c == '*';
}

typedef struct {
    CFRange ranges[16];
    int count;
} Found;

static void record(CFRange cluster, void *context)
{
    Found *found = (Found *)context;
    if (found->count < 16)
        found->ranges[found->count] = cluster;
    found->count++;
}

// A text from code points (UTF-16 encoded), the clusters found as "[at+length]..." or "none".
static NSString *clusters(const UTF32Char *points, int count)
{
    UniChar chars[64];
    CFIndex length = 0;
    for (int index = 0; index < count; index++) {
        UTF32Char c = points[index];
        if (c >= 0x10000) {
            chars[length++] = (UniChar)(0xD800 + ((c - 0x10000) >> 10));
            chars[length++] = (UniChar)(0xDC00 + ((c - 0x10000) & 0x3FF));
        } else {
            chars[length++] = (UniChar)c;
        }
    }
    Found found = {0};
    revenant_emoji_clusters(chars, length, covered, NULL, record, &found);
    if (found.count == 0)
        return @"none";
    NSMutableString *text = [NSMutableString string];
    for (int index = 0; index < found.count && index < 16; index++)
        [text appendFormat:@"[%ld+%ld]", (long)found.ranges[index].location, (long)found.ranges[index].length];
    return text;
}

#define CLUSTERS(...) clusters((const UTF32Char[]){__VA_ARGS__}, (int)(sizeof((const UTF32Char[]){__VA_ARGS__}) / sizeof(UTF32Char)))

static void expect(const char *name, NSString *seen, NSString *expected)
{
    // The red run: the unfixed library finds no cluster, whatever the text.
    NSString *answer = revenant_negative ? @"none" : seen;
    revenant_check([answer isEqualToString:expected], name, [NSString stringWithFormat:@"%@, expected %@", answer, expected]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    expect("a family of three is one cluster", CLUSTERS(0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467), @"[0+8]");
    expect("a skin tone and a profession is one cluster", CLUSTERS(0x1F468, 0x1F3FB, 0x200D, 0x1F4BB), @"[0+7]");
    expect("a flag with a variation selector and a joiner is one cluster", CLUSTERS(0x1F3F3, 0xFE0F, 0x200D, 0x1F308), @"[0+6]");
    expect("a person with a tone, a joiner and a BMP sign with VS16 is one cluster", CLUSTERS(0x1F471, 0x1F3FC, 0x200D, 0x2642, 0xFE0F), @"[0+7]");
    expect("a text-default sign with VS16 is a cluster", CLUSTERS(0x2764, 0xFE0F), @"[0+2]");
    expect("a sign of the copyright class with VS16 is a cluster", CLUSTERS(0xA9, 0xFE0F), @"[0+2]");
    expect("a pictographic with a skin tone is a cluster", CLUSTERS(0x1F44D, 0x1F3FD), @"[0+4]");
    expect("a keycap with VS16", CLUSTERS('1', 0xFE0F, 0x20E3), @"[0+3]");
    expect("a keycap without VS16", CLUSTERS('#', 0x20E3), @"[0+2]");
    expect("a flag from a tag sequence is one cluster", CLUSTERS(0x1F3F4, 0xE0067, 0xE0062, 0xE0065, 0xE006E, 0xE0067, 0xE007F), @"[0+14]");
    expect("two regional indicators are one flag", CLUSTERS(0x1F1FA, 0x1F1F8), @"[0+4]");
    expect("three regional indicators are a flag and a lone indicator", CLUSTERS(0x1F1FA, 0x1F1F8, 0x1F1FA), @"[0+4]");
    expect("four regional indicators are two flags", CLUSTERS(0x1F1FA, 0x1F1F8, 0x1F1EB, 0x1F1F7), @"[0+4][4+4]");
    expect("the cluster in a text is found at its place", CLUSTERS('H', 'i', ' ', 0x1F468, 0x200D, 0x1F469, ' ', 'o', 'k'), @"[3+5]");
    expect("two clusters in a text", CLUSTERS(0x2764, 0xFE0F, ' ', 0x1F44D, 0x1F3FD, '!'), @"[0+2][3+4]");
    expect("a cluster after a cluster, no gap", CLUSTERS(0x2764, 0xFE0F, 0x1F468, 0x200D, 0x1F4BB), @"[0+2][2+5]");
    expect("a sequence of three joiners", CLUSTERS(0x1F469, 0x200D, 0x2764, 0xFE0F, 0x200D, 0x1F48B, 0x200D, 0x1F468), @"[0+11]");

    // What stays as it is.
    expect("Latin text has no cluster", CLUSTERS('H', 'e', 'l', 'l', 'o'), @"none");
    expect("Cyrillic text has no cluster", CLUSTERS(0x041F, 0x0440, 0x0438, 0x0432, 0x0435, 0x0442), @"none");
    expect("an Arabic joiner stays with the Arabic text", CLUSTERS(0x0628, 0x200D, 0x0627), @"none");
    expect("a Devanagari joiner stays with the Devanagari text", CLUSTERS(0x0915, 0x094D, 0x200D, 0x0937), @"none");
    expect("a lone sign of the copyright class stays", CLUSTERS(0xA9), @"none");
    expect("a copyright sign and a letter stay", CLUSTERS(0xA9, ' ', 'a'), @"none");
    expect("a digit stays", CLUSTERS('1', '2', '3'), @"none");
    expect("a hash and a star stay", CLUSTERS('#', '*', ' ', 'x'), @"none");
    expect("a digit with VS16 and no keycap stays", CLUSTERS('1', 0xFE0F), @"none");
    expect("a lone pictographic stays", CLUSTERS(0x1F600), @"none");
    expect("two pictographics side by side stay", CLUSTERS(0x1F468, 0x1F469), @"none");
    expect("a pictographic with VS15 (text style) stays", CLUSTERS(0x1F600, 0xFE0E), @"none");
    expect("a text-default sign with VS15 stays", CLUSTERS(0x2764, 0xFE0E), @"none");
    expect("a joiner followed by a letter does not join", CLUSTERS(0x1F468, 0x200D, 'a'), @"none");
    expect("a dangling joiner at the end does not join", CLUSTERS(0x1F468, 0x200D), @"none");
    expect("a joiner alone", CLUSTERS(0x200D), @"none");
    expect("a joiner followed by a joiner", CLUSTERS(0x1F468, 0x200D, 0x200D, 0x1F469), @"none");
    expect("a modifier alone stays", CLUSTERS(0x1F3FD), @"none");
    expect("VS16 after a letter stays", CLUSTERS('a', 0xFE0F), @"none");
    expect("VS16 after a Cyrillic letter stays", CLUSTERS(0x0436, 0xFE0F), @"none");
    expect("a keycap mark alone stays", CLUSTERS(0x20E3), @"none");
    expect("a regional indicator alone stays", CLUSTERS(0x1F1FA, ' ', 0x1F1F8), @"none");

    // A text that ends in half a surrogate pair is not read past its end.
    UniChar broken[] = {0x2764, 0xFE0F, 0xD83D};
    Found found = {0};
    revenant_emoji_clusters(broken, 3, covered, NULL, record, &found);
    revenant_check(revenant_negative ? NO : (found.count == 1 && found.ranges[0].location == 0 && found.ranges[0].length == 2),
                   "a lone high surrogate at the end is left alone", [NSString stringWithFormat:@"%d clusters", found.count]);
    UniChar broken_start[] = {0xD83D, 0x200D, 0x1F468 & 0xFFFF};
    found.count = 0;
    revenant_emoji_clusters(broken_start, 3, covered, NULL, record, &found);
    revenant_check(found.count == 0 || revenant_negative, "an unpaired surrogate starts no cluster", [NSString stringWithFormat:@"%d clusters", found.count]);

    // The lookup is asked next to a joiner or a mark only: a text without them never reaches it.
    lookups = 0;
    UniChar plain[] = {'H', 'i', ' ', 0x041F, 0x0440, 0x0438, 0x0432, 0x0435, 0x0442, ' ', 0xD83D, 0xDE00, 0xD83D, 0xDE00};
    revenant_emoji_clusters(plain, 14, covered, NULL, record, &found);
    revenant_check(lookups == 0, "Latin, Cyrillic and plain emoji never reach the lookup", [NSString stringWithFormat:@"%d lookups", lookups]);
    lookups = 0;
    UniChar zwj[] = {0xD83D, 0xDC68, 0x200D, 0xD83D, 0xDCBB};
    found.count = 0;
    revenant_emoji_clusters(zwj, 5, covered, NULL, record, &found);
    revenant_check((lookups > 0 && lookups <= 4 && found.count == 1) || revenant_negative, "a joined pair asks the lookup a few times",
                   [NSString stringWithFormat:@"%d lookups, %d clusters", lookups, found.count]);
    return revenant_finish();
}
