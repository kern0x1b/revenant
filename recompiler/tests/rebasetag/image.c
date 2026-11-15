struct tagged {
    char before[8];
    unsigned long long word;
    char after[8];
};

static const char text[] = "a literal longer than fifteen bytes";

struct tagged tagged_word = {
    {'M', 'A', 'R', 'K', 'E', 'R', '_', 'A'},
    (unsigned long long)text + 0x8000000000000000ull,
    {'M', 'A', 'R', 'K', 'E', 'R', '_', 'B'},
};

unsigned long long tagged_top(void)
{
    return tagged_word.word >> 56;
}
