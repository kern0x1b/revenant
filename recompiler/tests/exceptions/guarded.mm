extern "C" void xl_level3(int mode);

namespace {

int destroyed;
int unwound;

struct Guard {
    int *counter;
    explicit Guard(int *c) : counter(c) {}
    ~Guard() { ++*counter; }
};

}

extern "C" int xl_destroyed(void) { return destroyed; }

extern "C" int xl_unwound(void) { return unwound; }

extern "C" __attribute__((noinline)) void xl_guarded(int mode)
{
    Guard outer(&destroyed);
    {
        Guard inner(&destroyed);
        xl_level3(mode);
    }
}

extern "C" __attribute__((noinline)) int xl_catch_all(int mode)
{
    Guard guard(&destroyed);
    try {
        xl_level3(mode);
    } catch (...) {
        ++unwound;
        return 1;
    }
    return 0;
}
