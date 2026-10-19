struct spring_case {
    const char *name;
    double mass;
    double stiffness;
    double damping;
    double velocity;
};

static const struct spring_case spring_cases[] = {
    {"default", 1, 100, 10, 0},
    {"underdamped/soft", 1, 100, 10, 3},
    {"underdamped/back", 1, 100, 10, -3},
    {"underdamped/thrown", 1, 100, 10, -50},
    {"underdamped/0.9", 1, 100, 18, 0},
    {"underdamped/0.95", 1, 100, 19, 0},
    {"underdamped/0.9875", 1, 100, 19.75, 0},
    {"underdamped/heavy", 3, 1000, 100, 0},
    {"underdamped/uikit", 3, 1000, 500, 0},
    {"underdamped/uikit thrown", 3, 1000, 500, 8},
    {"underdamped/light", 0.25, 40, 1.5, 2},
    {"underdamped/slow", 12, 7, 1, 0},
    {"underdamped/faint", 1, 100, 0.125, 0},
    {"underdamped/fainter", 1, 100, 0.0009765625, 0},
    {"critical", 1, 100, 20, 0},
    {"critical/thrown", 1, 100, 20, 6},
    {"critical/back", 1, 100, 20, -6},
    {"overdamped/1.25", 1, 100, 25, 0},
    {"overdamped/1.25 fast", 1, 100, 25, 9},
    {"overdamped/1.25 at omega", 1, 100, 25, 10},
    {"overdamped/1.25 past omega", 1, 100, 25, 15},
    {"overdamped/1.25 far past omega", 1, 100, 25, 50},
    {"overdamped/1.25 back", 1, 100, 25, -50},
    {"overdamped/5", 1, 100, 100, 0},
    {"overdamped/25", 1, 100, 500, 0},
    {"overdamped/25 thrown", 1, 100, 500, 6},
    {"overdamped/stiff", 1, 1000, 500, 1},
    {"overdamped/slow", 12, 7, 100, 0},
    {"overdamped/slow thrown", 12, 7, 100, 0.5},
    {"overdamped/tiny mass", 0.0625, 900, 30, 0},
    {"undamped", 1, 100, 0, 0},
    {"undamped/thrown", 1, 100, 0, 4}
};

static const unsigned spring_case_count = sizeof spring_cases / sizeof spring_cases[0];
