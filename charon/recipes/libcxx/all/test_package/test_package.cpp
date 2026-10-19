#include <algorithm>
#include <expected>
#include <format>
#include <ranges>
#include <string>
#include <vector>

static std::expected<int, std::string> parse(std::string_view text)
{
    if (text.empty())
        return std::unexpected("empty");
    return static_cast<int>(text.size());
}

int main()
{
    std::vector<int> values { 5, 3, 8, 1 };
    std::ranges::sort(values);
    auto doubled = values | std::views::transform([](int value) { return value * 2; });
    std::string joined;
    for (int value : doubled)
        joined += std::format("{} ", value);
    if (joined != "2 6 10 16 ")
        return 1;
    if (_LIBCPP_VERSION < 210000)
        return 1;
    return parse("armv7").value_or(0) == 5 && !parse("").has_value() ? 0 : 1;
}
