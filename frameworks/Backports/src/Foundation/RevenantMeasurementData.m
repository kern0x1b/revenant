#import "RevenantMeasurementData.h"

static const RevenantMeasurementUnit revenant_units_0[] = {
    {"g", 0, 9.8100000000000005, {{"{0}G", "{0}Gs", "{0} G", "{0} G", "{0} g-force", "{0} g-force"}, {"{0}G", "{0}G", "{0} G", "{0} G", "{0} g-force", "{0} g-force"}}, {{"g-force", "g-force", "g-force"}, {"g-force", "g-force", "g-force"}}},
    {"m/s\u00b2", 0, 1, {{"{0}m/s\u00b2", "{0}m/s\u00b2", "{0} m/s\u00b2", "{0} m/s\u00b2", "{0} meter per second squared", "{0} meters per second squared"}, {"{0}m/s\u00b2", "{0}m/s\u00b2", "{0} m/s\u00b2", "{0} m/s\u00b2", "{0} metre per second squared", "{0} metres per second squared"}}, {{"m/s\u00b2", "meters/sec\u00b2", "meters per second squared"}, {"m/s\u00b2", "metres/sec\u00b2", "metres per second squared"}}},
};

static const RevenantMeasurementUnit revenant_units_1[] = {
    {"\u00b0", 0, 1, {{"{0}\u00b0", "{0}\u00b0", "{0} deg", "{0} deg", "{0} degree", "{0} degrees"}, {"{0}\u00b0", "{0}\u00b0", "{0} deg", "{0} deg", "{0} degree", "{0} degrees"}}, {{"deg", "degrees", "degrees"}, {"deg", "degrees", "degrees"}}},
    {"rad", 0, 57.295779513082323, {{"{0}rad", "{0}rad", "{0} rad", "{0} rad", "{0} radian", "{0} radians"}, {"{0}rad", "{0}rad", "{0} rad", "{0} rad", "{0} radian", "{0} radians"}}, {{"rad", "radians", "radians"}, {"rad", "radians", "radians"}}},
    {"\u02b9", 0, 0.016667000000000001, {{"{0}\u2032", "{0}\u2032", "{0} arcmin", "{0} arcmins", "{0} arcminute", "{0} arcminutes"}, {"{0}\u2032", "{0}\u2032", "{0} arcmin", "{0} arcmins", "{0} arcminute", "{0} arcminutes"}}, {{"arcmin", "arcmins", "arcminutes"}, {"arcmin", "arcmins", "arcminutes"}}},
    {"\u02ba", 0, 0.00027777999999999999, {{"{0}\u2033", "{0}\u2033", "{0} arcsec", "{0} arcsecs", "{0} arcsecond", "{0} arcseconds"}, {"{0}\u2033", "{0}\u2033", "{0} arcsec", "{0} arcsecs", "{0} arcsecond", "{0} arcseconds"}}, {{"arcsec", "arcsecs", "arcseconds"}, {"arcsec", "arcsecs", "arcseconds"}}},
    {"grad", 0, 0.90000000000000002, {{"{0} grad", "{0} grad", "{0} grad", "{0} grad", "{0} grad", "{0} grad"}, {"{0} grad", "{0} grad", "{0} grad", "{0} grad", "{0} grad", "{0} grad"}}, {{"grad", "grad", "grad"}, {"grad", "grad", "grad"}}},
    {"rev", 0, 360, {{"{0}rev", "{0}rev", "{0} rev", "{0} rev", "{0} revolution", "{0} revolutions"}, {"{0}rev", "{0}rev", "{0} rev", "{0} revs", "{0} revolution", "{0} revolutions"}}, {{"rev", "rev", "revolutions"}, {"rev", "rev", "revolutions"}}},
};

static const RevenantMeasurementUnit revenant_units_2[] = {
    {"ac", 0, 4046.8564224000002, {{"{0}ac", "{0}ac", "{0} ac", "{0} ac", "{0} acre", "{0} acres"}, {"{0}ac", "{0}ac", "{0} ac", "{0} ac", "{0} acre", "{0} acres"}}, {{"acre", "acres", "acres"}, {"acre", "acres", "acres"}}},
    {"a", 0, 100, {{"{0} a", "{0} a", "{0} a", "{0} a", "{0} a", "{0} a"}, {"{0} a", "{0} a", "{0} a", "{0} a", "{0} a", "{0} a"}}, {{"a", "a", "a"}, {"a", "a", "a"}}},
    {"ha", 0, 10000, {{"{0}ha", "{0}ha", "{0} ha", "{0} ha", "{0} hectare", "{0} hectares"}, {"{0}ha", "{0}ha", "{0} ha", "{0} ha", "{0} hectare", "{0} hectares"}}, {{"hectare", "hectares", "hectares"}, {"hectare", "hectares", "hectares"}}},
    {"cm\u00b2", 0, 0.0001, {{"{0}cm\u00b2", "{0}cm\u00b2", "{0} cm\u00b2", "{0} cm\u00b2", "{0} square centimeter", "{0} square centimeters"}, {"{0}cm\u00b2", "{0}cm\u00b2", "{0} cm\u00b2", "{0} cm\u00b2", "{0} square centimetre", "{0} square centimetres"}}, {{"cm\u00b2", "cm\u00b2", "square centimeters"}, {"cm\u00b2", "cm\u00b2", "square centimetres"}}},
    {"ft\u00b2", 0, 0.092903040000000006, {{"{0}ft\u00b2", "{0}ft\u00b2", "{0} sq ft", "{0} sq ft", "{0} square foot", "{0} square feet"}, {"{0}ft\u00b2", "{0}ft\u00b2", "{0} sq ft", "{0} sq ft", "{0} square foot", "{0} square feet"}}, {{"ft\u00b2", "sq feet", "square feet"}, {"ft\u00b2", "sq feet", "square feet"}}},
    {"in\u00b2", 0, 0.00064515999999999998, {{"{0}in\u00b2", "{0}in\u00b2", "{0} in\u00b2", "{0} in\u00b2", "{0} square inch", "{0} square inches"}, {"{0}in\u00b2", "{0}in\u00b2", "{0} in\u00b2", "{0} in\u00b2", "{0} square inch", "{0} square inches"}}, {{"in\u00b2", "inches\u00b2", "square inches"}, {"in\u00b2", "inches\u00b2", "square inches"}}},
    {"km\u00b2", 0, 1000000, {{"{0}km\u00b2", "{0}km\u00b2", "{0} km\u00b2", "{0} km\u00b2", "{0} square kilometer", "{0} square kilometers"}, {"{0}km\u00b2", "{0}km\u00b2", "{0} km\u00b2", "{0} km\u00b2", "{0} square kilometre", "{0} square kilometres"}}, {{"km\u00b2", "km\u00b2", "square kilometers"}, {"km\u00b2", "km\u00b2", "square kilometres"}}},
    {"Mm\u00b2", 0, 1000000000000, {{"{0} Mm\u00b2", "{0} Mm\u00b2", "{0} Mm\u00b2", "{0} Mm\u00b2", "{0} Mm\u00b2", "{0} Mm\u00b2"}, {"{0} Mm\u00b2", "{0} Mm\u00b2", "{0} Mm\u00b2", "{0} Mm\u00b2", "{0} Mm\u00b2", "{0} Mm\u00b2"}}, {{"Mm\u00b2", "Mm\u00b2", "Mm\u00b2"}, {"Mm\u00b2", "Mm\u00b2", "Mm\u00b2"}}},
    {"m\u00b2", 0, 1, {{"{0}m\u00b2", "{0}m\u00b2", "{0} m\u00b2", "{0} m\u00b2", "{0} square meter", "{0} square meters"}, {"{0} m\u00b2", "{0} m\u00b2", "{0} m\u00b2", "{0} m\u00b2", "{0} square metre", "{0} square metres"}}, {{"meters\u00b2", "meters\u00b2", "square meters"}, {"m\u00b2", "m\u00b2", "square metres"}}},
    {"\u00b5m\u00b2", 0, 9.9999999999999998e-13, {{"{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2"}, {"{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2", "{0} \u00b5m\u00b2"}}, {{"\u00b5m\u00b2", "\u00b5m\u00b2", "\u00b5m\u00b2"}, {"\u00b5m\u00b2", "\u00b5m\u00b2", "\u00b5m\u00b2"}}},
    {"mi\u00b2", 0, 2589988.1103360001, {{"{0}mi\u00b2", "{0}mi\u00b2", "{0} sq mi", "{0} sq mi", "{0} square mile", "{0} square miles"}, {"{0}mi\u00b2", "{0}mi\u00b2", "{0} sq mi", "{0} sq mi", "{0} square mile", "{0} square miles"}}, {{"mi\u00b2", "sq miles", "square miles"}, {"mi\u00b2", "sq miles", "square miles"}}},
    {"mm\u00b2", 0, 9.9999999999999995e-07, {{"{0} mm\u00b2", "{0} mm\u00b2", "{0} mm\u00b2", "{0} mm\u00b2", "{0} mm\u00b2", "{0} mm\u00b2"}, {"{0} mm\u00b2", "{0} mm\u00b2", "{0} mm\u00b2", "{0} mm\u00b2", "{0} mm\u00b2", "{0} mm\u00b2"}}, {{"mm\u00b2", "mm\u00b2", "mm\u00b2"}, {"mm\u00b2", "mm\u00b2", "mm\u00b2"}}},
    {"nm\u00b2", 0, 1.0000000000000001e-18, {{"{0} nm\u00b2", "{0} nm\u00b2", "{0} nm\u00b2", "{0} nm\u00b2", "{0} nm\u00b2", "{0} nm\u00b2"}, {"{0} nm\u00b2", "{0} nm\u00b2", "{0} nm\u00b2", "{0} nm\u00b2", "{0} nm\u00b2", "{0} nm\u00b2"}}, {{"nm\u00b2", "nm\u00b2", "nm\u00b2"}, {"nm\u00b2", "nm\u00b2", "nm\u00b2"}}},
    {"yd\u00b2", 0, 0.83612735999999999, {{"{0}yd\u00b2", "{0}yd\u00b2", "{0} yd\u00b2", "{0} yd\u00b2", "{0} square yard", "{0} square yards"}, {"{0}yd\u00b2", "{0}yd\u00b2", "{0} yd\u00b2", "{0} yd\u00b2", "{0} square yard", "{0} square yards"}}, {{"yd\u00b2", "yards\u00b2", "square yards"}, {"yd\u00b2", "yards\u00b2", "square yards"}}},
};

static const RevenantMeasurementUnit revenant_units_3[] = {
    {"g/L", 0, 1, {{"{0} g/L", "{0} g/L", "{0} g/L", "{0} g/L", "{0} g/L", "{0} g/L"}, {"{0} g/L", "{0} g/L", "{0} g/L", "{0} g/L", "{0} g/L", "{0} g/L"}}, {{"g/L", "g/L", "g/L"}, {"g/L", "g/L", "g/L"}}},
    {"mg/dL", 0, 0.01, {{"0.0{0} g/L", "0.0{0} g/L", "0.0{0} g/L", "0.0{0} g/L", "0.0{0} g/L", "0.0{0} g/L"}, {"0.0{0} g/L", "0.0{0} g/L", "0.0{0} g/L", "0.0{0} g/L", "0.0{0} g/L", "0.0{0} g/L"}}, {{"mg/dL", "mg/dL", "milligrams per deciliter"}, {"mg/dl", "mg/dl", "milligrams per decilitre"}}},
};

static const RevenantMeasurementUnit revenant_units_4[] = {
    {"ppm", 0, 1, {{"{0}ppm", "{0}ppm", "{0} ppm", "{0} ppm", "{0} part per million", "{0} parts per million"}, {"{0}ppm", "{0}ppm", "{0} ppm", "{0} ppm", "{0} part per million", "{0} parts per million"}}, {{"ppm", "parts/million", "parts per million"}, {"ppm", "parts/million", "parts per million"}}},
};

static const RevenantMeasurementUnit revenant_units_5[] = {
    {"hr", 0, 3600, {{"{0}h", "{0}h", "{0} hr", "{0} hr", "{0} hour", "{0} hours"}, {"{0}h", "{0}h", "{0} hr", "{0} hrs", "{0} hour", "{0} hours"}}, {{"hour", "hours", "hours"}, {"hour", "hours", "hours"}}},
    {"min", 0, 60, {{"{0}m", "{0}m", "{0} min", "{0} min", "{0} minute", "{0} minutes"}, {"{0}m", "{0}m", "{0} min", "{0} min", "{0} minute", "{0} minutes"}}, {{"min", "min", "minutes"}, {"min", "min", "minutes"}}},
    {"\u00b5s", 0, 9.9999999999999995e-07, {{"{0}\u03bcs", "{0}\u03bcs", "{0} \u03bcs", "{0} \u03bcs", "{0} microsecond", "{0} microseconds"}, {"{0}\u03bcs", "{0}\u03bcs", "{0} \u03bcs", "{0} \u03bcs", "{0} microsecond", "{0} microseconds"}}, {{"\u03bcsec", "\u03bcsecs", "microseconds"}, {"\u03bcsec", "\u03bcsecs", "microseconds"}}},
    {"ms", 0, 0.001, {{"{0}ms", "{0}ms", "{0} ms", "{0} ms", "{0} millisecond", "{0} milliseconds"}, {"{0}ms", "{0}ms", "{0} ms", "{0} ms", "{0} millisecond", "{0} milliseconds"}}, {{"msec", "millisecs", "milliseconds"}, {"msec", "millisecs", "milliseconds"}}},
    {"ns", 0, 1.0000000000000001e-09, {{"{0}ns", "{0}ns", "{0} ns", "{0} ns", "{0} nanosecond", "{0} nanoseconds"}, {"{0}ns", "{0}ns", "{0} ns", "{0} ns", "{0} nanosecond", "{0} nanoseconds"}}, {{"ns", "nanosecs", "nanoseconds"}, {"ns", "nanosecs", "nanoseconds"}}},
    {"ps", 0, 9.9999999999999998e-13, {{"{0} ps", "{0} ps", "{0} ps", "{0} ps", "{0} ps", "{0} ps"}, {"{0} ps", "{0} ps", "{0} ps", "{0} ps", "{0} ps", "{0} ps"}}, {{"ps", "ps", "ps"}, {"ps", "ps", "ps"}}},
    {"s", 0, 1, {{"{0}s", "{0}s", "{0} sec", "{0} sec", "{0} second", "{0} seconds"}, {"{0}s", "{0}s", "{0} sec", "{0} secs", "{0} second", "{0} seconds"}}, {{"sec", "secs", "seconds"}, {"sec", "secs", "seconds"}}},
};

static const RevenantMeasurementUnit revenant_units_6[] = {
    {"kAh", 0, 3600000, {{"{0} kAh", "{0} kAh", "{0} kAh", "{0} kAh", "{0} kAh", "{0} kAh"}, {"{0} kAh", "{0} kAh", "{0} kAh", "{0} kAh", "{0} kAh", "{0} kAh"}}, {{"kAh", "kAh", "kAh"}, {"kAh", "kAh", "kAh"}}},
    {"MAh", 0, 3600000000, {{"{0} MAh", "{0} MAh", "{0} MAh", "{0} MAh", "{0} MAh", "{0} MAh"}, {"{0} MAh", "{0} MAh", "{0} MAh", "{0} MAh", "{0} MAh", "{0} MAh"}}, {{"MAh", "MAh", "MAh"}, {"MAh", "MAh", "MAh"}}},
    {"Ah", 0, 3600, {{"{0} Ah", "{0} Ah", "{0} Ah", "{0} Ah", "{0} Ah", "{0} Ah"}, {"{0} Ah", "{0} Ah", "{0} Ah", "{0} Ah", "{0} Ah", "{0} Ah"}}, {{"Ah", "Ah", "Ah"}, {"Ah", "Ah", "Ah"}}},
    {"C", 0, 1, {{"{0} C", "{0} C", "{0} C", "{0} C", "{0} C", "{0} C"}, {"{0} C", "{0} C", "{0} C", "{0} C", "{0} C", "{0} C"}}, {{"C", "C", "C"}, {"C", "C", "C"}}},
    {"\u00b5Ah", 0, 0.0035999999999999999, {{"{0} \u00b5Ah", "{0} \u00b5Ah", "{0} \u00b5Ah", "{0} \u00b5Ah", "{0} \u00b5Ah", "{0} \u00b5Ah"}, {"{0} \u00b5Ah", "{0} \u00b5Ah", "{0} \u00b5Ah", "{0} \u00b5Ah", "{0} \u00b5Ah", "{0} \u00b5Ah"}}, {{"\u00b5Ah", "\u00b5Ah", "\u00b5Ah"}, {"\u00b5Ah", "\u00b5Ah", "\u00b5Ah"}}},
    {"mAh", 0, 3.6000000000000001, {{"{0} mAh", "{0} mAh", "{0} mAh", "{0} mAh", "{0} mAh", "{0} mAh"}, {"{0} mAh", "{0} mAh", "{0} mAh", "{0} mAh", "{0} mAh", "{0} mAh"}}, {{"mAh", "mAh", "mAh"}, {"mAh", "mAh", "mAh"}}},
};

static const RevenantMeasurementUnit revenant_units_7[] = {
    {"A", 0, 1, {{"{0}A", "{0}A", "{0} A", "{0} A", "{0} ampere", "{0} amperes"}, {"{0}A", "{0}A", "{0} A", "{0} A", "{0} ampere", "{0} amperes"}}, {{"amp", "amps", "amperes"}, {"amp", "amps", "amperes"}}},
    {"kA", 0, 1000, {{"{0} kA", "{0} kA", "{0} kA", "{0} kA", "{0} kA", "{0} kA"}, {"{0} kA", "{0} kA", "{0} kA", "{0} kA", "{0} kA", "{0} kA"}}, {{"kA", "kA", "kA"}, {"kA", "kA", "kA"}}},
    {"MA", 0, 1000000, {{"{0} MA", "{0} MA", "{0} MA", "{0} MA", "{0} MA", "{0} MA"}, {"{0} MA", "{0} MA", "{0} MA", "{0} MA", "{0} MA", "{0} MA"}}, {{"MA", "MA", "MA"}, {"MA", "MA", "MA"}}},
    {"\u00b5A", 0, 9.9999999999999995e-07, {{"{0} \u00b5A", "{0} \u00b5A", "{0} \u00b5A", "{0} \u00b5A", "{0} \u00b5A", "{0} \u00b5A"}, {"{0} \u00b5A", "{0} \u00b5A", "{0} \u00b5A", "{0} \u00b5A", "{0} \u00b5A", "{0} \u00b5A"}}, {{"\u00b5A", "\u00b5A", "\u00b5A"}, {"\u00b5A", "\u00b5A", "\u00b5A"}}},
    {"mA", 0, 0.001, {{"{0}mA", "{0}mA", "{0} mA", "{0} mA", "{0} milliampere", "{0} milliamperes"}, {"{0}mA", "{0}mA", "{0} mA", "{0} mA", "{0} milliampere", "{0} milliamperes"}}, {{"mA", "milliamps", "milliamperes"}, {"mA", "milliamps", "milliamperes"}}},
};

static const RevenantMeasurementUnit revenant_units_8[] = {
    {"V", 0, 1, {{"{0}V", "{0}V", "{0} V", "{0} V", "{0} volt", "{0} volts"}, {"{0}V", "{0}V", "{0} V", "{0} V", "{0} volt", "{0} volts"}}, {{"volt", "volts", "volts"}, {"volt", "volts", "volts"}}},
    {"kV", 0, 1000, {{"{0} kV", "{0} kV", "{0} kV", "{0} kV", "{0} kV", "{0} kV"}, {"{0} kV", "{0} kV", "{0} kV", "{0} kV", "{0} kV", "{0} kV"}}, {{"kV", "kV", "kV"}, {"kV", "kV", "kV"}}},
    {"MV", 0, 1000000, {{"{0} MV", "{0} MV", "{0} MV", "{0} MV", "{0} MV", "{0} MV"}, {"{0} MV", "{0} MV", "{0} MV", "{0} MV", "{0} MV", "{0} MV"}}, {{"MV", "MV", "MV"}, {"MV", "MV", "MV"}}},
    {"\u00b5V", 0, 9.9999999999999995e-07, {{"{0} \u00b5V", "{0} \u00b5V", "{0} \u00b5V", "{0} \u00b5V", "{0} \u00b5V", "{0} \u00b5V"}, {"{0} \u00b5V", "{0} \u00b5V", "{0} \u00b5V", "{0} \u00b5V", "{0} \u00b5V", "{0} \u00b5V"}}, {{"\u00b5V", "\u00b5V", "\u00b5V"}, {"\u00b5V", "\u00b5V", "\u00b5V"}}},
    {"mV", 0, 0.001, {{"{0} mV", "{0} mV", "{0} mV", "{0} mV", "{0} mV", "{0} mV"}, {"{0} mV", "{0} mV", "{0} mV", "{0} mV", "{0} mV", "{0} mV"}}, {{"mV", "mV", "mV"}, {"mV", "mV", "mV"}}},
};

static const RevenantMeasurementUnit revenant_units_9[] = {
    {"k\u2126", 0, 1000, {{"{0} k\u2126", "{0} k\u2126", "{0} k\u2126", "{0} k\u2126", "{0} k\u2126", "{0} k\u2126"}, {"{0} k\u2126", "{0} k\u2126", "{0} k\u2126", "{0} k\u2126", "{0} k\u2126", "{0} k\u2126"}}, {{"k\u2126", "k\u2126", "k\u2126"}, {"k\u2126", "k\u2126", "k\u2126"}}},
    {"M\u2126", 0, 1000000, {{"{0} M\u2126", "{0} M\u2126", "{0} M\u2126", "{0} M\u2126", "{0} M\u2126", "{0} M\u2126"}, {"{0} M\u2126", "{0} M\u2126", "{0} M\u2126", "{0} M\u2126", "{0} M\u2126", "{0} M\u2126"}}, {{"M\u2126", "M\u2126", "M\u2126"}, {"M\u2126", "M\u2126", "M\u2126"}}},
    {"\u00b5\u2126", 0, 9.9999999999999995e-07, {{"{0} \u00b5\u2126", "{0} \u00b5\u2126", "{0} \u00b5\u2126", "{0} \u00b5\u2126", "{0} \u00b5\u2126", "{0} \u00b5\u2126"}, {"{0} \u00b5\u2126", "{0} \u00b5\u2126", "{0} \u00b5\u2126", "{0} \u00b5\u2126", "{0} \u00b5\u2126", "{0} \u00b5\u2126"}}, {{"\u00b5\u2126", "\u00b5\u2126", "\u00b5\u2126"}, {"\u00b5\u2126", "\u00b5\u2126", "\u00b5\u2126"}}},
    {"m\u2126", 0, 0.001, {{"{0} m\u2126", "{0} m\u2126", "{0} m\u2126", "{0} m\u2126", "{0} m\u2126", "{0} m\u2126"}, {"{0} m\u2126", "{0} m\u2126", "{0} m\u2126", "{0} m\u2126", "{0} m\u2126", "{0} m\u2126"}}, {{"m\u2126", "m\u2126", "m\u2126"}, {"m\u2126", "m\u2126", "m\u2126"}}},
    {"\u2126", 0, 1, {{"{0}\u03a9", "{0}\u03a9", "{0} \u03a9", "{0} \u03a9", "{0} ohm", "{0} ohms"}, {"{0}\u03a9", "{0}\u03a9", "{0} \u03a9", "{0} \u03a9", "{0} ohm", "{0} ohms"}}, {{"ohm", "ohms", "ohms"}, {"ohm", "ohms", "ohms"}}},
};

static const RevenantMeasurementUnit revenant_units_10[] = {
    {"cal", 0, 4.1840000000000002, {{"{0}cal", "{0}cal", "{0} cal", "{0} cal", "{0} calorie", "{0} calories"}, {"{0}cal", "{0}cal", "{0} cal", "{0} cal", "{0} calorie", "{0} calories"}}, {{"cal", "cal", "calories"}, {"cal", "cal", "calories"}}},
    {"C", 0, 4184, {{"{0}Cal", "{0}Cal", "{0} Cal", "{0} Cal", "{0} Calorie", "{0} Calories"}, {"{0}Cal", "{0}Cal", "{0} Cal", "{0} Cal", "{0} Calorie", "{0} Calories"}}, {{"Cal", "Cal", "Calories"}, {"Cal", "Cal", "Calories"}}},
    {"J", 0, 1, {{"{0}J", "{0}J", "{0} J", "{0} J", "{0} joule", "{0} joules"}, {"{0}J", "{0}J", "{0} J", "{0} J", "{0} joule", "{0} joules"}}, {{"joule", "joules", "joules"}, {"joule", "joules", "joules"}}},
    {"kCal", 0, 4184, {{"{0}kcal", "{0}kcal", "{0} kcal", "{0} kcal", "{0} kilocalorie", "{0} kilocalories"}, {"{0}kcal", "{0}kcal", "{0} kcal", "{0} kcal", "{0} kilocalorie", "{0} kilocalories"}}, {{"kcal", "kcal", "kilocalories"}, {"kcal", "kcal", "kilocalories"}}},
    {"kJ", 0, 1000, {{"{0}kJ", "{0}kJ", "{0} kJ", "{0} kJ", "{0} kilojoule", "{0} kilojoules"}, {"{0}kJ", "{0}kJ", "{0} kJ", "{0} kJ", "{0} kilojoule", "{0} kilojoules"}}, {{"kJ", "kilojoule", "kilojoules"}, {"kJ", "kilojoule", "kilojoules"}}},
    {"kWh", 0, 3600000, {{"{0}kWh", "{0}kWh", "{0} kWh", "{0} kWh", "{0} kilowatt hour", "{0} kilowatt-hours"}, {"{0}kWh", "{0}kWh", "{0} kWh", "{0} kWh", "{0} kilowatt-hour", "{0} kilowatt-hours"}}, {{"kWh", "kW-hour", "kilowatt-hours"}, {"kWh", "kW-hour", "kilowatt-hours"}}},
};

static const RevenantMeasurementUnit revenant_units_11[] = {
    {"fps", 0, 1, {{"{0} fps", "{0} fps", "{0} fps", "{0} fps", "{0} fps", "{0} fps"}, {"{0} fps", "{0} fps", "{0} fps", "{0} fps", "{0} fps", "{0} fps"}}, {{"fps", "fps", "fps"}, {"fps", "fps", "fps"}}},
    {"GHz", 0, 1000000000, {{"{0}GHz", "{0}GHz", "{0} GHz", "{0} GHz", "{0} gigahertz", "{0} gigahertz"}, {"{0}GHz", "{0}GHz", "{0} GHz", "{0} GHz", "{0} gigahertz", "{0} gigahertz"}}, {{"GHz", "GHz", "gigahertz"}, {"GHz", "GHz", "gigahertz"}}},
    {"Hz", 0, 1, {{"{0}Hz", "{0}Hz", "{0} Hz", "{0} Hz", "{0} hertz", "{0} hertz"}, {"{0}Hz", "{0}Hz", "{0} Hz", "{0} Hz", "{0} hertz", "{0} hertz"}}, {{"Hz", "Hz", "hertz"}, {"Hz", "Hz", "hertz"}}},
    {"kHz", 0, 1000, {{"{0}kHz", "{0}kHz", "{0} kHz", "{0} kHz", "{0} kilohertz", "{0} kilohertz"}, {"{0}kHz", "{0}kHz", "{0} kHz", "{0} kHz", "{0} kilohertz", "{0} kilohertz"}}, {{"kHz", "kHz", "kilohertz"}, {"kHz", "kHz", "kilohertz"}}},
    {"MHz", 0, 1000000, {{"{0}MHz", "{0}MHz", "{0} MHz", "{0} MHz", "{0} megahertz", "{0} megahertz"}, {"{0}MHz", "{0}MHz", "{0} MHz", "{0} MHz", "{0} megahertz", "{0} megahertz"}}, {{"MHz", "MHz", "megahertz"}, {"MHz", "MHz", "megahertz"}}},
    {"\u00b5Hz", 0, 9.9999999999999995e-07, {{"{0} \u00b5Hz", "{0} \u00b5Hz", "{0} \u00b5Hz", "{0} \u00b5Hz", "{0} \u00b5Hz", "{0} \u00b5Hz"}, {"{0} \u00b5Hz", "{0} \u00b5Hz", "{0} \u00b5Hz", "{0} \u00b5Hz", "{0} \u00b5Hz", "{0} \u00b5Hz"}}, {{"\u00b5Hz", "\u00b5Hz", "\u00b5Hz"}, {"\u00b5Hz", "\u00b5Hz", "\u00b5Hz"}}},
    {"mHz", 0, 0.001, {{"{0} mHz", "{0} mHz", "{0} mHz", "{0} mHz", "{0} mHz", "{0} mHz"}, {"{0} mHz", "{0} mHz", "{0} mHz", "{0} mHz", "{0} mHz", "{0} mHz"}}, {{"mHz", "mHz", "mHz"}, {"mHz", "mHz", "mHz"}}},
    {"nHz", 0, 1.0000000000000001e-09, {{"{0} nHz", "{0} nHz", "{0} nHz", "{0} nHz", "{0} nHz", "{0} nHz"}, {"{0} nHz", "{0} nHz", "{0} nHz", "{0} nHz", "{0} nHz", "{0} nHz"}}, {{"nHz", "nHz", "nHz"}, {"nHz", "nHz", "nHz"}}},
    {"THz", 0, 1000000000000, {{"{0} THz", "{0} THz", "{0} THz", "{0} THz", "{0} THz", "{0} THz"}, {"{0} THz", "{0} THz", "{0} THz", "{0} THz", "{0} THz", "{0} THz"}}, {{"THz", "THz", "THz"}, {"THz", "THz", "THz"}}},
};

static const RevenantMeasurementUnit revenant_units_12[] = {
    {"L/100km", 0, 1, {{"{0}L/100km", "{0}L/100km", "{0} L/100 km", "{0} L/100 km", "{0} liter per 100 kilometers", "{0} liters per 100 kilometers"}, {"{0}l/100km", "{0}l/100km", "{0} l/100 km", "{0} l/100 km", "{0} litre per 100 kilometres", "{0} litres per 100 kilometres"}}, {{"L/100km", "L/100 km", "liters per 100 kilometers"}, {"l/100km", "l/100 km", "litres per 100 kilometres"}}},
    {"mpg", INFINITY, 235.215, {{"{0}mpg", "{0}mpg", "{0} mpg", "{0} mpg", "{0} mile per gallon", "{0} miles per gallon"}, {"{0}mpgUS", "{0}mpgUS", "{0} mpg US", "{0} mpg US", "{0} mile per US gallon", "{0} miles per US gallon"}}, {{"mpg", "miles/gal", "miles per gallon"}, {"mpg US", "miles/US gal", "miles per US gallon"}}},
    {"mpg", INFINITY, 282.48099999999999, {{"{0}m/gUK", "{0}m/gUK", "{0} mpg Imp.", "{0} mpg Imp.", "{0} mile per Imp. gallon", "{0} miles per Imp. gallon"}, {"{0}mpg", "{0}mpg", "{0} mpg", "{0} mpg", "{0} mile per gallon", "{0} miles per gallon"}}, {{"mpg UK", "miles/gal Imp.", "miles per Imp. gallon"}, {"mpg", "miles/gal", "miles per gallon"}}},
};

static const RevenantMeasurementUnit revenant_units_13[] = {
    {"lx", 0, 1, {{"{0}lx", "{0}lx", "{0} lx", "{0} lx", "{0} lux", "{0} lux"}, {"{0}lx", "{0}lx", "{0} lx", "{0} lx", "{0} lux", "{0} lux"}}, {{"lux", "lux", "lux"}, {"lux", "lux", "lux"}}},
};

static const RevenantMeasurementUnit revenant_units_14[] = {
    {"PB", 0, 1000000000000000, {{"{0}PB", "{0}PB", "{0} PB", "{0} PB", "{0} petabyte", "{0} petabytes"}, {"{0}PB", "{0}PB", "{0} PB", "{0} PB", "{0} petabyte", "{0} petabytes"}}, {{"PB", "PByte", "petabytes"}, {"PB", "PByte", "petabytes"}}},
    {"TiB", 0, 1099511627776, {{"{0} TiB", "{0} TiB", "{0} TiB", "{0} TiB", "{0} TiB", "{0} TiB"}, {"{0} TiB", "{0} TiB", "{0} TiB", "{0} TiB", "{0} TiB", "{0} TiB"}}, {{"TiB", "TiB", "TiB"}, {"TiB", "TiB", "TiB"}}},
    {"Eib", 0, 1.4411518807585587e+17, {{"{0} Eib", "{0} Eib", "{0} Eib", "{0} Eib", "{0} Eib", "{0} Eib"}, {"{0} Eib", "{0} Eib", "{0} Eib", "{0} Eib", "{0} Eib", "{0} Eib"}}, {{"Eib", "Eib", "Eib"}, {"Eib", "Eib", "Eib"}}},
    {"Zb", 0, 1.25e+20, {{"{0} Zb", "{0} Zb", "{0} Zb", "{0} Zb", "{0} Zb", "{0} Zb"}, {"{0} Zb", "{0} Zb", "{0} Zb", "{0} Zb", "{0} Zb", "{0} Zb"}}, {{"Zb", "Zb", "Zb"}, {"Zb", "Zb", "Zb"}}},
    {"Kib", 0, 128, {{"{0} Kib", "{0} Kib", "{0} Kib", "{0} Kib", "{0} Kib", "{0} Kib"}, {"{0} Kib", "{0} Kib", "{0} Kib", "{0} Kib", "{0} Kib", "{0} Kib"}}, {{"Kib", "Kib", "Kib"}, {"Kib", "Kib", "Kib"}}},
    {"nibble", 0, 0.5, {{"{0} nibble", "{0} nibble", "{0} nibble", "{0} nibble", "{0} nibble", "{0} nibble"}, {"{0} nibble", "{0} nibble", "{0} nibble", "{0} nibble", "{0} nibble", "{0} nibble"}}, {{"nibble", "nibble", "nibble"}, {"nibble", "nibble", "nibble"}}},
    {"GB", 0, 1000000000, {{"{0}GB", "{0}GB", "{0} GB", "{0} GB", "{0} gigabyte", "{0} gigabytes"}, {"{0}GB", "{0}GB", "{0} GB", "{0} GB", "{0} gigabyte", "{0} gigabytes"}}, {{"GB", "GByte", "gigabytes"}, {"GB", "GByte", "gigabytes"}}},
    {"ZiB", 0, 1.1805916207174113e+21, {{"{0} ZiB", "{0} ZiB", "{0} ZiB", "{0} ZiB", "{0} ZiB", "{0} ZiB"}, {"{0} ZiB", "{0} ZiB", "{0} ZiB", "{0} ZiB", "{0} ZiB", "{0} ZiB"}}, {{"ZiB", "ZiB", "ZiB"}, {"ZiB", "ZiB", "ZiB"}}},
    {"EiB", 0, 1.152921504606847e+18, {{"{0} EiB", "{0} EiB", "{0} EiB", "{0} EiB", "{0} EiB", "{0} EiB"}, {"{0} EiB", "{0} EiB", "{0} EiB", "{0} EiB", "{0} EiB", "{0} EiB"}}, {{"EiB", "EiB", "EiB"}, {"EiB", "EiB", "EiB"}}},
    {"Pb", 0, 125000000000000, {{"{0} Pb", "{0} Pb", "{0} Pb", "{0} Pb", "{0} Pb", "{0} Pb"}, {"{0} Pb", "{0} Pb", "{0} Pb", "{0} Pb", "{0} Pb", "{0} Pb"}}, {{"Pb", "Pb", "Pb"}, {"Pb", "Pb", "Pb"}}},
    {"bit", 0, 0.125, {{"{0}bit", "{0}bit", "{0} bit", "{0} bit", "{0} bit", "{0} bits"}, {"{0}bit", "{0}bit", "{0} bit", "{0} bit", "{0} bit", "{0} bits"}}, {{"bit", "bit", "bits"}, {"bit", "bit", "bits"}}},
    {"Yb", 0, 1.25e+23, {{"{0} Yb", "{0} Yb", "{0} Yb", "{0} Yb", "{0} Yb", "{0} Yb"}, {"{0} Yb", "{0} Yb", "{0} Yb", "{0} Yb", "{0} Yb", "{0} Yb"}}, {{"Yb", "Yb", "Yb"}, {"Yb", "Yb", "Yb"}}},
    {"YiB", 0, 1.2089258196146292e+24, {{"{0} YiB", "{0} YiB", "{0} YiB", "{0} YiB", "{0} YiB", "{0} YiB"}, {"{0} YiB", "{0} YiB", "{0} YiB", "{0} YiB", "{0} YiB", "{0} YiB"}}, {{"YiB", "YiB", "YiB"}, {"YiB", "YiB", "YiB"}}},
    {"B", 0, 1, {{"{0}B", "{0}B", "{0} byte", "{0} byte", "{0} byte", "{0} bytes"}, {"{0}B", "{0}B", "{0} byte", "{0} byte", "{0} byte", "{0} bytes"}}, {{"byte", "byte", "bytes"}, {"byte", "byte", "bytes"}}},
    {"Gb", 0, 125000000, {{"{0}Gb", "{0}Gb", "{0} Gb", "{0} Gb", "{0} gigabit", "{0} gigabits"}, {"{0}Gb", "{0}Gb", "{0} Gb", "{0} Gb", "{0} gigabit", "{0} gigabits"}}, {{"Gbit", "Gbit", "gigabits"}, {"Gbit", "Gbit", "gigabits"}}},
    {"Zib", 0, 1.4757395258967641e+20, {{"{0} Zib", "{0} Zib", "{0} Zib", "{0} Zib", "{0} Zib", "{0} Zib"}, {"{0} Zib", "{0} Zib", "{0} Zib", "{0} Zib", "{0} Zib", "{0} Zib"}}, {{"Zib", "Zib", "Zib"}, {"Zib", "Zib", "Zib"}}},
    {"KiB", 0, 1024, {{"{0} KiB", "{0} KiB", "{0} KiB", "{0} KiB", "{0} KiB", "{0} KiB"}, {"{0} KiB", "{0} KiB", "{0} KiB", "{0} KiB", "{0} KiB", "{0} KiB"}}, {{"KiB", "KiB", "KiB"}, {"KiB", "KiB", "KiB"}}},
    {"ZB", 0, 1e+21, {{"{0} ZB", "{0} ZB", "{0} ZB", "{0} ZB", "{0} ZB", "{0} ZB"}, {"{0} ZB", "{0} ZB", "{0} ZB", "{0} ZB", "{0} ZB", "{0} ZB"}}, {{"ZB", "ZB", "ZB"}, {"ZB", "ZB", "ZB"}}},
    {"TB", 0, 1000000000000, {{"{0}TB", "{0}TB", "{0} TB", "{0} TB", "{0} terabyte", "{0} terabytes"}, {"{0}TB", "{0}TB", "{0} TB", "{0} TB", "{0} terabyte", "{0} terabytes"}}, {{"TB", "TByte", "terabytes"}, {"TB", "TByte", "terabytes"}}},
    {"Pib", 0, 140737488355328, {{"{0} Pib", "{0} Pib", "{0} Pib", "{0} Pib", "{0} Pib", "{0} Pib"}, {"{0} Pib", "{0} Pib", "{0} Pib", "{0} Pib", "{0} Pib", "{0} Pib"}}, {{"Pib", "Pib", "Pib"}, {"Pib", "Pib", "Pib"}}},
    {"EB", 0, 1e+18, {{"{0} EB", "{0} EB", "{0} EB", "{0} EB", "{0} EB", "{0} EB"}, {"{0} EB", "{0} EB", "{0} EB", "{0} EB", "{0} EB", "{0} EB"}}, {{"EB", "EB", "EB"}, {"EB", "EB", "EB"}}},
    {"PiB", 0, 1125899906842624, {{"{0} PiB", "{0} PiB", "{0} PiB", "{0} PiB", "{0} PiB", "{0} PiB"}, {"{0} PiB", "{0} PiB", "{0} PiB", "{0} PiB", "{0} PiB", "{0} PiB"}}, {{"PiB", "PiB", "PiB"}, {"PiB", "PiB", "PiB"}}},
    {"Eb", 0, 1.25e+17, {{"{0} Eb", "{0} Eb", "{0} Eb", "{0} Eb", "{0} Eb", "{0} Eb"}, {"{0} Eb", "{0} Eb", "{0} Eb", "{0} Eb", "{0} Eb", "{0} Eb"}}, {{"Eb", "Eb", "Eb"}, {"Eb", "Eb", "Eb"}}},
    {"Mb", 0, 125000, {{"{0}Mb", "{0}Mb", "{0} Mb", "{0} Mb", "{0} megabit", "{0} megabits"}, {"{0}Mb", "{0}Mb", "{0} Mb", "{0} Mb", "{0} megabit", "{0} megabits"}}, {{"Mbit", "Mbit", "megabits"}, {"Mbit", "Mbit", "megabits"}}},
    {"MB", 0, 1000000, {{"{0}MB", "{0}MB", "{0} MB", "{0} MB", "{0} megabyte", "{0} megabytes"}, {"{0}MB", "{0}MB", "{0} MB", "{0} MB", "{0} megabyte", "{0} megabytes"}}, {{"MB", "MByte", "megabytes"}, {"MB", "MByte", "megabytes"}}},
    {"YB", 0, 9.9999999999999998e+23, {{"{0} YB", "{0} YB", "{0} YB", "{0} YB", "{0} YB", "{0} YB"}, {"{0} YB", "{0} YB", "{0} YB", "{0} YB", "{0} YB", "{0} YB"}}, {{"YB", "YB", "YB"}, {"YB", "YB", "YB"}}},
    {"Mib", 0, 131072, {{"{0} Mib", "{0} Mib", "{0} Mib", "{0} Mib", "{0} Mib", "{0} Mib"}, {"{0} Mib", "{0} Mib", "{0} Mib", "{0} Mib", "{0} Mib", "{0} Mib"}}, {{"Mib", "Mib", "Mib"}, {"Mib", "Mib", "Mib"}}},
    {"Gib", 0, 134217728, {{"{0} Gib", "{0} Gib", "{0} Gib", "{0} Gib", "{0} Gib", "{0} Gib"}, {"{0} Gib", "{0} Gib", "{0} Gib", "{0} Gib", "{0} Gib", "{0} Gib"}}, {{"Gib", "Gib", "Gib"}, {"Gib", "Gib", "Gib"}}},
    {"Tb", 0, 125000000000, {{"{0}Tb", "{0}Tb", "{0} Tb", "{0} Tb", "{0} terabit", "{0} terabits"}, {"{0}Tb", "{0}Tb", "{0} Tb", "{0} Tb", "{0} terabit", "{0} terabits"}}, {{"Tbit", "Tbit", "terabits"}, {"Tbit", "Tbit", "terabits"}}},
    {"kB", 0, 1000, {{"{0}kB", "{0}kB", "{0} kB", "{0} kB", "{0} kilobyte", "{0} kilobytes"}, {"{0}kB", "{0}kB", "{0} kB", "{0} kB", "{0} kilobyte", "{0} kilobytes"}}, {{"kB", "kByte", "kilobytes"}, {"kB", "kByte", "kilobytes"}}},
    {"kb", 0, 125, {{"{0}kb", "{0}kb", "{0} kb", "{0} kb", "{0} kilobit", "{0} kilobits"}, {"{0}kb", "{0}kb", "{0} kb", "{0} kb", "{0} kilobit", "{0} kilobits"}}, {{"kbit", "kbit", "kilobits"}, {"kbit", "kbit", "kilobits"}}},
    {"Tib", 0, 137438953472, {{"{0} Tib", "{0} Tib", "{0} Tib", "{0} Tib", "{0} Tib", "{0} Tib"}, {"{0} Tib", "{0} Tib", "{0} Tib", "{0} Tib", "{0} Tib", "{0} Tib"}}, {{"Tib", "Tib", "Tib"}, {"Tib", "Tib", "Tib"}}},
    {"Yib", 0, 1.5111572745182865e+23, {{"{0} Yib", "{0} Yib", "{0} Yib", "{0} Yib", "{0} Yib", "{0} Yib"}, {"{0} Yib", "{0} Yib", "{0} Yib", "{0} Yib", "{0} Yib", "{0} Yib"}}, {{"Yib", "Yib", "Yib"}, {"Yib", "Yib", "Yib"}}},
    {"GiB", 0, 1073741824, {{"{0} GiB", "{0} GiB", "{0} GiB", "{0} GiB", "{0} GiB", "{0} GiB"}, {"{0} GiB", "{0} GiB", "{0} GiB", "{0} GiB", "{0} GiB", "{0} GiB"}}, {{"GiB", "GiB", "GiB"}, {"GiB", "GiB", "GiB"}}},
    {"MiB", 0, 1048576, {{"{0} MiB", "{0} MiB", "{0} MiB", "{0} MiB", "{0} MiB", "{0} MiB"}, {"{0} MiB", "{0} MiB", "{0} MiB", "{0} MiB", "{0} MiB", "{0} MiB"}}, {{"MiB", "MiB", "MiB"}, {"MiB", "MiB", "MiB"}}},
};

static const RevenantMeasurementUnit revenant_units_15[] = {
    {"fur", 0, 201.16800000000001, {{"{0}fur", "{0}fur", "{0} fur", "{0} fur", "{0} furlong", "{0} furlongs"}, {"{0}fur", "{0}fur", "{0} fur", "{0} fur", "{0} furlong", "{0} furlongs"}}, {{"furlong", "furlongs", "furlongs"}, {"furlong", "furlongs", "furlongs"}}},
    {"m", 0, 1, {{"{0}m", "{0}m", "{0} m", "{0} m", "{0} meter", "{0} meters"}, {"{0}m", "{0}m", "{0} m", "{0} m", "{0} metre", "{0} metres"}}, {{"meter", "meters", "meters"}, {"m", "m", "metres"}}},
    {"in", 0, 0.025399999999999999, {{"{0}\u2033", "{0}\u2033", "{0} in", "{0} in", "{0} inch", "{0} inches"}, {"{0}\u2033", "{0}\u2033", "{0} in", "{0} in", "{0} inch", "{0} inches"}}, {{"in", "inches", "inches"}, {"in", "inches", "inches"}}},
    {"hm", 0, 100, {{"{0} hm", "{0} hm", "{0} hm", "{0} hm", "{0} hm", "{0} hm"}, {"{0} hm", "{0} hm", "{0} hm", "{0} hm", "{0} hm", "{0} hm"}}, {{"hm", "hm", "hm"}, {"hm", "hm", "hm"}}},
    {"dam", 0, 10, {{"{0} dam", "{0} dam", "{0} dam", "{0} dam", "{0} dam", "{0} dam"}, {"{0} dam", "{0} dam", "{0} dam", "{0} dam", "{0} dam", "{0} dam"}}, {{"dam", "dam", "dam"}, {"dam", "dam", "dam"}}},
    {"Mm", 0, 1000000, {{"{0} Mm", "{0} Mm", "{0} Mm", "{0} Mm", "{0} Mm", "{0} Mm"}, {"{0} Mm", "{0} Mm", "{0} Mm", "{0} Mm", "{0} Mm", "{0} Mm"}}, {{"Mm", "Mm", "Mm"}, {"Mm", "Mm", "Mm"}}},
    {"pm", 0, 9.9999999999999998e-13, {{"{0}pm", "{0}pm", "{0} pm", "{0} pm", "{0} picometer", "{0} picometers"}, {"{0}pm", "{0}pm", "{0} pm", "{0} pm", "{0} picometre", "{0} picometres"}}, {{"pm", "pm", "picometers"}, {"pm", "pm", "picometres"}}},
    {"mi", 0, 1609.3440000000001, {{"{0}mi", "{0}mi", "{0} mi", "{0} mi", "{0} mile", "{0} miles"}, {"{0}mi", "{0}mi", "{0} mi", "{0} mi", "{0} mile", "{0} miles"}}, {{"mi", "miles", "miles"}, {"mi", "miles", "miles"}}},
    {"pc", 0, 30856775814913672, {{"{0}pc", "{0}pc", "{0} pc", "{0} pc", "{0} parsec", "{0} parsecs"}, {"{0}pc", "{0}pc", "{0} pc", "{0} pc", "{0} parsec", "{0} parsecs"}}, {{"parsec", "parsecs", "parsecs"}, {"parsec", "parsecs", "parsecs"}}},
    {"yd", 0, 0.91439999999999999, {{"{0}yd", "{0}yd", "{0} yd", "{0} yd", "{0} yard", "{0} yards"}, {"{0}yd", "{0}yd", "{0} yd", "{0} yd", "{0} yard", "{0} yards"}}, {{"yd", "yards", "yards"}, {"yd", "yards", "yards"}}},
    {"\u00b5m", 0, 9.9999999999999995e-07, {{"{0}\u03bcm", "{0}\u03bcm", "{0} \u03bcm", "{0} \u03bcm", "{0} micrometer", "{0} micrometers"}, {"{0}\u03bcm", "{0}\u03bcm", "{0} \u03bcm", "{0} \u03bcm", "{0} micrometre", "{0} micrometres"}}, {{"\u03bcm", "\u03bcmeters", "micrometers"}, {"\u03bcm", "\u03bcmetres", "micrometres"}}},
    {"NM", 0, 1852, {{"{0}nmi", "{0}nmi", "{0} nmi", "{0} nmi", "{0} nautical mile", "{0} nautical miles"}, {"{0}nmi", "{0}nmi", "{0} nmi", "{0} nmi", "{0} nautical mile", "{0} nautical miles"}}, {{"nmi", "nmi", "nautical miles"}, {"nmi", "nmi", "nautical miles"}}},
    {"ly", 0, 9460730472580800, {{"{0}ly", "{0}ly", "{0} ly", "{0} ly", "{0} light year", "{0} light years"}, {"{0}ly", "{0}ly", "{0} ly", "{0} ly", "{0} light year", "{0} light years"}}, {{"ly", "light yrs", "light years"}, {"ly", "light yrs", "light years"}}},
    {"dm", 0, 0.10000000000000001, {{"{0}dm", "{0}dm", "{0} dm", "{0} dm", "{0} decimeter", "{0} decimeters"}, {"{0}dm", "{0}dm", "{0} dm", "{0} dm", "{0} decimetre", "{0} decimetres"}}, {{"dm", "dm", "decimeters"}, {"dm", "dm", "decimetres"}}},
    {"ft", 0, 0.30480000000000002, {{"{0}\u2032", "{0}\u2032", "{0} ft", "{0} ft", "{0} foot", "{0} feet"}, {"{0}\u2032", "{0}\u2032", "{0} ft", "{0} ft", "{0} foot", "{0} feet"}}, {{"ft", "feet", "feet"}, {"ft", "feet", "feet"}}},
    {"ftm", 0, 1.8288, {{"{0}fth", "{0}fth", "{0} fth", "{0} fth", "{0} fathom", "{0} fathoms"}, {"{0}fth", "{0}fth", "{0} fth", "{0} fth", "{0} fathom", "{0} fathoms"}}, {{"fathom", "fathoms", "fathoms"}, {"fathom", "fathoms", "fathoms"}}},
    {"nm", 0, 1.0000000000000001e-09, {{"{0}nm", "{0}nm", "{0} nm", "{0} nm", "{0} nanometer", "{0} nanometers"}, {"{0}nm", "{0}nm", "{0} nm", "{0} nm", "{0} nanometre", "{0} nanometres"}}, {{"nm", "nm", "nanometers"}, {"nm", "nm", "nanometres"}}},
    {"smi", 0, 10000, {{"{0}smi", "{0}smi", "{0} smi", "{0} smi", "{0} mile-scandinavian", "{0} miles-scandinavian"}, {"{0}smi", "{0}smi", "{0} smi", "{0} smi", "{0} Scandinavian mile", "{0} Scandinavian miles"}}, {{"smi", "smi", "miles-scandinavian"}, {"smi", "smi", "Scandinavian mile"}}},
    {"mm", 0, 0.001, {{"{0}mm", "{0}mm", "{0} mm", "{0} mm", "{0} millimeter", "{0} millimeters"}, {"{0}mm", "{0}mm", "{0} mm", "{0} mm", "{0} millimetre", "{0} millimetres"}}, {{"mm", "mm", "millimeters"}, {"mm", "mm", "millimetres"}}},
    {"ua", 0, 149597870700, {{"{0}au", "{0}au", "{0} au", "{0} au", "{0} astronomical unit", "{0} astronomical units"}, {"{0}au", "{0}au", "{0} au", "{0} au", "{0} astronomical unit", "{0} astronomical units"}}, {{"au", "au", "astronomical units"}, {"au", "au", "astronomical units"}}},
    {"km", 0, 1000, {{"{0}km", "{0}km", "{0} km", "{0} km", "{0} kilometer", "{0} kilometers"}, {"{0}km", "{0}km", "{0} km", "{0} km", "{0} kilometre", "{0} kilometres"}}, {{"km", "km", "kilometers"}, {"km", "km", "kilometres"}}},
    {"cm", 0, 0.01, {{"{0}cm", "{0}cm", "{0} cm", "{0} cm", "{0} centimeter", "{0} centimeters"}, {"{0}cm", "{0}cm", "{0} cm", "{0} cm", "{0} centimetre", "{0} centimetres"}}, {{"cm", "cm", "centimeters"}, {"cm", "cm", "centimetres"}}},
};

static const RevenantMeasurementUnit revenant_units_16[] = {
    {"g", 0, 0.001, {{"{0}g", "{0}g", "{0} g", "{0} g", "{0} gram", "{0} grams"}, {"{0}g", "{0}g", "{0} g", "{0} g", "{0} gram", "{0} grams"}}, {{"gram", "grams", "grams"}, {"gram", "grams", "grams"}}},
    {"ct", 0, 0.00020000000000000001, {{"{0}CD", "{0}CD", "{0} CD", "{0} CD", "{0} carat", "{0} carats"}, {"{0}ct", "{0}ct", "{0} ct", "{0} ct", "{0} carat", "{0} carats"}}, {{"carat", "carats", "carats"}, {"carat", "carats", "carats"}}},
    {"cg", 0, 1.0000000000000001e-05, {{"{0} cg", "{0} cg", "{0} cg", "{0} cg", "{0} cg", "{0} cg"}, {"{0} cg", "{0} cg", "{0} cg", "{0} cg", "{0} cg", "{0} cg"}}, {{"cg", "cg", "cg"}, {"cg", "cg", "cg"}}},
    {"dg", 0, 0.0001, {{"{0} dg", "{0} dg", "{0} dg", "{0} dg", "{0} dg", "{0} dg"}, {"{0} dg", "{0} dg", "{0} dg", "{0} dg", "{0} dg", "{0} dg"}}, {{"dg", "dg", "dg"}, {"dg", "dg", "dg"}}},
    {"kg", 0, 1, {{"{0}kg", "{0}kg", "{0} kg", "{0} kg", "{0} kilogram", "{0} kilograms"}, {"{0}kg", "{0}kg", "{0} kg", "{0} kg", "{0} kilogram", "{0} kilograms"}}, {{"kg", "kg", "kilograms"}, {"kg", "kg", "kilograms"}}},
    {"t", 0, 1000, {{"{0}t", "{0}t", "{0} t", "{0} t", "{0} metric ton", "{0} metric tons"}, {"{0}t", "{0}t", "{0} t", "{0} t", "{0} tonne", "{0} tonnes"}}, {{"t", "t", "metric tons"}, {"t", "t", "tonnes"}}},
    {"\u00b5g", 0, 1.0000000000000001e-09, {{"{0}\u03bcg", "{0}\u03bcg", "{0} \u03bcg", "{0} \u03bcg", "{0} microgram", "{0} micrograms"}, {"{0}\u03bcg", "{0}\u03bcg", "{0} \u03bcg", "{0} \u03bcg", "{0} microgram", "{0} micrograms"}}, {{"\u03bcg", "\u03bcg", "micrograms"}, {"\u03bcg", "\u03bcg", "micrograms"}}},
    {"mg", 0, 9.9999999999999995e-07, {{"{0}mg", "{0}mg", "{0} mg", "{0} mg", "{0} milligram", "{0} milligrams"}, {"{0}mg", "{0}mg", "{0} mg", "{0} mg", "{0} milligram", "{0} milligrams"}}, {{"mg", "mg", "milligrams"}, {"mg", "mg", "milligrams"}}},
    {"ng", 0, 9.9999999999999998e-13, {{"{0} ng", "{0} ng", "{0} ng", "{0} ng", "{0} ng", "{0} ng"}, {"{0} ng", "{0} ng", "{0} ng", "{0} ng", "{0} ng", "{0} ng"}}, {{"ng", "ng", "ng"}, {"ng", "ng", "ng"}}},
    {"oz", 0, 0.0283495, {{"{0}oz", "{0}oz", "{0} oz", "{0} oz", "{0} ounce", "{0} ounces"}, {"{0}oz", "{0}oz", "{0} oz", "{0} oz", "{0} ounce", "{0} ounces"}}, {{"oz", "oz", "ounces"}, {"oz", "oz", "ounces"}}},
    {"oz t", 0, 0.031103479999999999, {{"{0}oz t", "{0}oz t", "{0} oz t", "{0} oz t", "{0} troy ounce", "{0} troy ounces"}, {"{0}oz t", "{0}oz t", "{0} oz t", "{0} oz t", "{0} troy ounce", "{0} troy ounces"}}, {{"oz t", "oz troy", "troy ounces"}, {"oz t", "oz troy", "troy ounces"}}},
    {"pg", 0, 1.0000000000000001e-15, {{"{0} pg", "{0} pg", "{0} pg", "{0} pg", "{0} pg", "{0} pg"}, {"{0} pg", "{0} pg", "{0} pg", "{0} pg", "{0} pg", "{0} pg"}}, {{"pg", "pg", "pg"}, {"pg", "pg", "pg"}}},
    {"lb", 0, 0.453592, {{"{0}#", "{0}#", "{0} lb", "{0} lb", "{0} pound", "{0} pounds"}, {"{0}lb", "{0}lb", "{0} lb", "{0} lb", "{0} pound", "{0} pounds"}}, {{"lb", "pounds", "pounds"}, {"lb", "pounds", "pounds"}}},
    {"ton", 0, 907.18499999999995, {{"{0}tn", "{0}tn", "{0} tn", "{0} tn", "{0} ton", "{0} tons"}, {"{0}tn", "{0}tn", "{0} tn", "{0} tn", "{0} ton", "{0} tons"}}, {{"ton", "tons", "tons"}, {"ton", "tons", "tons"}}},
    {"slug", 0, 14.5939, {{"{0} slug", "{0} slug", "{0} slug", "{0} slug", "{0} slug", "{0} slug"}, {"{0} slug", "{0} slug", "{0} slug", "{0} slug", "{0} slug", "{0} slug"}}, {{"slug", "slug", "slug"}, {"slug", "slug", "slug"}}},
    {"st", 0, 6.3502900000000002, {{"{0}st", "{0}st", "{0} st", "{0} st", "{0} stone", "{0} stones"}, {"{0}st", "{0}st", "{0} st", "{0} st", "{0} stone", "{0} stone"}}, {{"stone", "stones", "stones"}, {"stone", "stone", "stone"}}},
};

static const RevenantMeasurementUnit revenant_units_17[] = {
    {"W", 0, 1, {{"{0}W", "{0}W", "{0} W", "{0} W", "{0} watt", "{0} watts"}, {"{0}W", "{0}W", "{0} W", "{0} W", "{0} watt", "{0} watts"}}, {{"watt", "watts", "watts"}, {"watt", "watts", "watts"}}},
    {"fW", 0, 1.0000000000000001e-15, {{"{0} fW", "{0} fW", "{0} fW", "{0} fW", "{0} fW", "{0} fW"}, {"{0} fW", "{0} fW", "{0} fW", "{0} fW", "{0} fW", "{0} fW"}}, {{"fW", "fW", "fW"}, {"fW", "fW", "fW"}}},
    {"GW", 0, 1000000000, {{"{0}GW", "{0}GW", "{0} GW", "{0} GW", "{0} gigawatt", "{0} gigawatts"}, {"{0}GW", "{0}GW", "{0} GW", "{0} GW", "{0} gigawatt", "{0} gigawatts"}}, {{"GW", "GW", "gigawatts"}, {"GW", "GW", "gigawatts"}}},
    {"hp", 0, 745.70000000000005, {{"{0}hp", "{0}hp", "{0} hp", "{0} hp", "{0} horsepower", "{0} horsepower"}, {"{0}hp", "{0}hp", "{0} hp", "{0} hp", "{0} horsepower", "{0} horsepower"}}, {{"hp", "hp", "horsepower"}, {"hp", "hp", "horsepower"}}},
    {"kW", 0, 1000, {{"{0}kW", "{0}kW", "{0} kW", "{0} kW", "{0} kilowatt", "{0} kilowatts"}, {"{0}kW", "{0}kW", "{0} kW", "{0} kW", "{0} kilowatt", "{0} kilowatts"}}, {{"kW", "kW", "kilowatts"}, {"kW", "kW", "kilowatts"}}},
    {"MW", 0, 1000000, {{"{0}MW", "{0}MW", "{0} MW", "{0} MW", "{0} megawatt", "{0} megawatts"}, {"{0}MW", "{0}MW", "{0} MW", "{0} MW", "{0} megawatt", "{0} megawatts"}}, {{"MW", "MW", "megawatts"}, {"MW", "MW", "megawatts"}}},
    {"\u00b5W", 0, 9.9999999999999995e-07, {{"{0} \u00b5W", "{0} \u00b5W", "{0} \u00b5W", "{0} \u00b5W", "{0} \u00b5W", "{0} \u00b5W"}, {"{0} \u00b5W", "{0} \u00b5W", "{0} \u00b5W", "{0} \u00b5W", "{0} \u00b5W", "{0} \u00b5W"}}, {{"\u00b5W", "\u00b5W", "\u00b5W"}, {"\u00b5W", "\u00b5W", "\u00b5W"}}},
    {"mW", 0, 0.001, {{"{0}mW", "{0}mW", "{0} mW", "{0} mW", "{0} milliwatt", "{0} milliwatts"}, {"{0}mW", "{0}mW", "{0} mW", "{0} mW", "{0} milliwatt", "{0} milliwatts"}}, {{"mW", "mW", "milliwatts"}, {"mW", "mW", "milliwatts"}}},
    {"nW", 0, 1.0000000000000001e-09, {{"{0} nW", "{0} nW", "{0} nW", "{0} nW", "{0} nW", "{0} nW"}, {"{0} nW", "{0} nW", "{0} nW", "{0} nW", "{0} nW", "{0} nW"}}, {{"nW", "nW", "nW"}, {"nW", "nW", "nW"}}},
    {"pW", 0, 9.9999999999999998e-13, {{"{0} pW", "{0} pW", "{0} pW", "{0} pW", "{0} pW", "{0} pW"}, {"{0} pW", "{0} pW", "{0} pW", "{0} pW", "{0} pW", "{0} pW"}}, {{"pW", "pW", "pW"}, {"pW", "pW", "pW"}}},
    {"TW", 0, 1000000000000, {{"{0} TW", "{0} TW", "{0} TW", "{0} TW", "{0} TW", "{0} TW"}, {"{0} TW", "{0} TW", "{0} TW", "{0} TW", "{0} TW", "{0} TW"}}, {{"TW", "TW", "TW"}, {"TW", "TW", "TW"}}},
};

static const RevenantMeasurementUnit revenant_units_18[] = {
    {"bar", 0, 100000, {{"{0}bar", "{0}bar", "{0} bar", "{0} bar", "{0} bar", "{0} bars"}, {"{0}bar", "{0}bar", "{0} bar", "{0} bar", "{0} bar", "{0} bars"}}, {{"bar", "bar", "bars"}, {"bar", "bar", "bars"}}},
    {"inHg", 0, 3386.3899999999999, {{"{0}\u2033 Hg", "{0}\u2033 Hg", "{0} inHg", "{0} inHg", "{0} inch of mercury", "{0} inches of mercury"}, {"{0}\u2033 Hg", "{0}\u2033 Hg", "{0} inHg", "{0} inHg", "{0} inch of mercury", "{0} inches of mercury"}}, {{"\u2033 Hg", "in Hg", "inches of mercury"}, {"\u2033 Hg", "in Hg", "inches of mercury"}}},
    {"GPa", 0, 1000000000, {{"{0} GPa", "{0} GPa", "{0} GPa", "{0} GPa", "{0} GPa", "{0} GPa"}, {"{0} GPa", "{0} GPa", "{0} GPa", "{0} GPa", "{0} GPa", "{0} GPa"}}, {{"GPa", "GPa", "GPa"}, {"GPa", "GPa", "GPa"}}},
    {"hPa", 0, 100, {{"{0}hPa", "{0}hPa", "{0} hPa", "{0} hPa", "{0} hectopascal", "{0} hectopascals"}, {"{0}hPa", "{0}hPa", "{0} hPa", "{0} hPa", "{0} hectopascal", "{0} hectopascals"}}, {{"hPa", "hPa", "hectopascals"}, {"hPa", "hPa", "hectopascals"}}},
    {"kPa", 0, 1000, {{"{0}kPa", "{0}kPa", "{0} kPa", "{0} kPa", "{0} kilopascal", "{0} kilopascals"}, {"{0}kPa", "{0}kPa", "{0} kPa", "{0} kPa", "{0} kilopascal", "{0} kilopascals"}}, {{"kPa", "kPa", "kilopascals"}, {"kPa", "kPa", "kilopascals"}}},
    {"MPa", 0, 1000000, {{"{0}MPa", "{0}MPa", "{0} MPa", "{0} MPa", "{0} megapascal", "{0} megapascals"}, {"{0}MPa", "{0}MPa", "{0} MPa", "{0} MPa", "{0} megapascal", "{0} megapascals"}}, {{"MPa", "MPa", "megapascals"}, {"MPa", "MPa", "megapascals"}}},
    {"mbar", 0, 100, {{"{0}mb", "{0}mb", "{0} mbar", "{0} mbar", "{0} millibar", "{0} millibars"}, {"{0}mb", "{0}mb", "{0} mbar", "{0} mbar", "{0} millibar", "{0} millibars"}}, {{"mbar", "mbar", "millibars"}, {"mbar", "mbar", "millibars"}}},
    {"mmHg", 0, 133.322, {{"{0}mmHg", "{0}mmHg", "{0} mmHg", "{0} mmHg", "{0} millimeter of mercury", "{0} millimeters of mercury"}, {"{0}mmHg", "{0}mmHg", "{0} mm Hg", "{0} mm Hg", "{0} millimetre of mercury", "{0} millimetres of mercury"}}, {{"mm Hg", "mm Hg", "millimeters of mercury"}, {"mm Hg", "mm Hg", "millimetres of mercury"}}},
    {"N/m\u00b2", 0, 1, {{"{0} N/m\u00b2", "{0} N/m\u00b2", "{0} N/m\u00b2", "{0} N/m\u00b2", "{0} N/m\u00b2", "{0} N/m\u00b2"}, {"{0} N/m\u00b2", "{0} N/m\u00b2", "{0} N/m\u00b2", "{0} N/m\u00b2", "{0} N/m\u00b2", "{0} N/m\u00b2"}}, {{"N/m\u00b2", "N/m\u00b2", "N/m\u00b2"}, {"N/m\u00b2", "N/m\u00b2", "N/m\u00b2"}}},
    {"psi", 0, 6894.7600000000002, {{"{0}psi", "{0}psi", "{0} psi", "{0} psi", "{0} pound-force per square inch", "{0} pounds-force per square inch"}, {"{0}psi", "{0}psi", "{0} psi", "{0} psi", "{0} pound-force per square inch", "{0} pounds-force per square inch"}}, {{"psi", "psi", "pounds-force per square inch"}, {"psi", "psi", "pounds-force per square inch"}}},
};

static const RevenantMeasurementUnit revenant_units_19[] = {
    {"m/s", 0, 1, {{"{0}m/s", "{0}m/s", "{0} m/s", "{0} m/s", "{0} meter per second", "{0} meters per second"}, {"{0}m/s", "{0}m/s", "{0} m/s", "{0} m/s", "{0} metre per second", "{0} metres per second"}}, {{"m/s", "meters/sec", "meters per second"}, {"m/s", "metres/sec", "metres per second"}}},
    {"km/h", 0, 0.27777800000000002, {{"{0}km/h", "{0}km/h", "{0} km/h", "{0} km/h", "{0} kilometer per hour", "{0} kilometers per hour"}, {"{0}km/h", "{0}km/h", "{0} km/h", "{0} km/h", "{0} kilometre per hour", "{0} kilometres per hour"}}, {{"km/hr", "km/hour", "kilometers per hour"}, {"km/hr", "km/hour", "kilometres per hour"}}},
    {"kn", 0, 0.51444400000000001, {{"{0}kn", "{0}kn", "{0} kn", "{0} kn", "{0} knot", "{0} knots"}, {"{0}kn", "{0}kn", "{0} kn", "{0} kn", "{0} knot", "{0} knots"}}, {{"kn", "kn", "knots"}, {"kn", "kn", "knots"}}},
    {"mph", 0, 0.44703999999999999, {{"{0}mph", "{0}mph", "{0} mph", "{0} mph", "{0} mile per hour", "{0} miles per hour"}, {"{0}mph", "{0}mph", "{0} mph", "{0} mph", "{0} mile per hour", "{0} miles per hour"}}, {{"mi/hr", "miles/hour", "miles per hour"}, {"mph", "miles/hour", "miles per hour"}}},
};

static const RevenantMeasurementUnit revenant_units_20[] = {
    {"\u00b0C", 273.14999999999998, 274.14999999999998, {{"{0}\u00b0C", "{0}\u00b0C", "{0}\u00b0C", "{0}\u00b0C", "{0} degree Celsius", "{0} degrees Celsius"}, {"{0}\u00b0C", "{0}\u00b0C", "{0}\u00b0C", "{0}\u00b0C", "{0} degree Celsius", "{0} degrees Celsius"}}, {{"\u00b0C", "deg. C", "degrees Celsius"}, {"\u00b0C", "deg. C", "degrees Celsius"}}},
    {"\u00b0F", 255.37222222222428, 255.92777777777985, {{"{0}\u00b0", "{0}\u00b0", "{0}\u00b0F", "{0}\u00b0F", "{0} degree Fahrenheit", "{0} degrees Fahrenheit"}, {"{0}\u00b0F", "{0}\u00b0F", "{0}\u00b0F", "{0}\u00b0F", "{0} degree Fahrenheit", "{0} degrees Fahrenheit"}}, {{"\u00b0F", "deg. F", "degrees Fahrenheit"}, {"\u00b0F", "deg. F", "degrees Fahrenheit"}}},
    {"K", 0, 1, {{"{0}K", "{0}K", "{0} K", "{0} K", "{0} kelvin", "{0} kelvins"}, {"{0}K", "{0}K", "{0} K", "{0} K", "{0} kelvin", "{0} kelvin"}}, {{"K", "K", "kelvins"}, {"K", "K", "kelvin"}}},
};

static const RevenantMeasurementUnit revenant_units_21[] = {
    {"bsh", 0, 35.239100000000001, {{"{0}bu", "{0}bu", "{0} bu", "{0} bu", "{0} bushel", "{0} bushels"}, {"{0}bu", "{0}bu", "{0} bu", "{0} bu", "{0} bushel", "{0} bushels"}}, {{"bushel", "bushels", "bushels"}, {"bushel", "bushels", "bushels"}}},
    {"dm\u00b3", 0, 1, {{"{0} dm\u00b3", "{0} dm\u00b3", "{0} dm\u00b3", "{0} dm\u00b3", "{0} dm\u00b3", "{0} dm\u00b3"}, {"{0} dm\u00b3", "{0} dm\u00b3", "{0} dm\u00b3", "{0} dm\u00b3", "{0} dm\u00b3", "{0} dm\u00b3"}}, {{"dm\u00b3", "dm\u00b3", "dm\u00b3"}, {"dm\u00b3", "dm\u00b3", "dm\u00b3"}}},
    {"gal", 0, 4.5460900000000004, {{"{0}gal-Im", "{0}gal-Im", "{0} gal Imp.", "{0} gal Imp.", "{0} Imp. gallon", "{0} Imp. gallons"}, {"{0}gal", "{0}gal", "{0} gal", "{0} gal", "{0} gallon", "{0} gallons"}}, {{"Imp gal", "Imp. gal", "Imp. gallons"}, {"gal", "gal", "gallons"}}},
    {"km\u00b3", 0, 1000000000000, {{"{0}km\u00b3", "{0}km\u00b3", "{0} km\u00b3", "{0} km\u00b3", "{0} cubic kilometer", "{0} cubic kilometers"}, {"{0}km\u00b3", "{0}km\u00b3", "{0} km\u00b3", "{0} km\u00b3", "{0} cubic kilometre", "{0} cubic kilometres"}}, {{"km\u00b3", "km\u00b3", "cubic kilometers"}, {"km\u00b3", "km\u00b3", "cubic kilometres"}}},
    {"gal", 0, 3.7854100000000002, {{"{0}gal", "{0}gal", "{0} gal", "{0} gal", "{0} gallon", "{0} gallons"}, {"{0}USgal", "{0}USgal", "{0} US gal", "{0} US gal", "{0} US gallon", "{0} US gallons"}}, {{"gal", "gal", "gallons"}, {"US gal", "US gal", "US gallons"}}},
    {"af", 0, 1233000, {{"{0}ac ft", "{0}ac ft", "{0} ac ft", "{0} ac ft", "{0} acre-foot", "{0} acre-feet"}, {"{0}ac ft", "{0}ac ft", "{0} ac ft", "{0} ac ft", "{0} acre-foot", "{0} acre-feet"}}, {{"acre ft", "acre ft", "acre-feet"}, {"acre ft", "acre ft", "acre-feet"}}},
    {"cL", 0, 0.01, {{"{0}cL", "{0}cL", "{0} cL", "{0} cL", "{0} centiliter", "{0} centiliters"}, {"{0}cl", "{0}cl", "{0} cl", "{0} cl", "{0} centilitre", "{0} centilitres"}}, {{"cL", "cL", "centiliters"}, {"cl", "cl", "centilitres"}}},
    {"cm\u00b3", 0, 0.001, {{"{0}cm\u00b3", "{0}cm\u00b3", "{0} cm\u00b3", "{0} cm\u00b3", "{0} cubic centimeter", "{0} cubic centimeters"}, {"{0}cm\u00b3", "{0}cm\u00b3", "{0} cm\u00b3", "{0} cm\u00b3", "{0} cubic centimetre", "{0} cubic centimetres"}}, {{"cm\u00b3", "cm\u00b3", "cubic centimeters"}, {"cm\u00b3", "cm\u00b3", "cubic centimetres"}}},
    {"ft\u00b3", 0, 28.316800000000001, {{"{0}ft\u00b3", "{0}ft\u00b3", "{0} ft\u00b3", "{0} ft\u00b3", "{0} cubic foot", "{0} cubic feet"}, {"{0}ft\u00b3", "{0}ft\u00b3", "{0} ft\u00b3", "{0} ft\u00b3", "{0} cubic foot", "{0} cubic feet"}}, {{"ft\u00b3", "feet\u00b3", "cubic feet"}, {"ft\u00b3", "feet\u00b3", "cubic feet"}}},
    {"in\u00b3", 0, 0.016387100000000002, {{"{0}in\u00b3", "{0}in\u00b3", "{0} in\u00b3", "{0} in\u00b3", "{0} cubic inch", "{0} cubic inches"}, {"{0}in\u00b3", "{0}in\u00b3", "{0} in\u00b3", "{0} in\u00b3", "{0} cubic inch", "{0} cubic inches"}}, {{"in\u00b3", "inches\u00b3", "cubic inches"}, {"in\u00b3", "inches\u00b3", "cubic inches"}}},
    {"m\u00b3", 0, 1000, {{"{0}m\u00b3", "{0}m\u00b3", "{0} m\u00b3", "{0} m\u00b3", "{0} cubic meter", "{0} cubic meters"}, {"{0}m\u00b3", "{0}m\u00b3", "{0} m\u00b3", "{0} m\u00b3", "{0} cubic metre", "{0} cubic metres"}}, {{"m\u00b3", "m\u00b3", "cubic meters"}, {"m\u00b3", "m\u00b3", "cubic metres"}}},
    {"mi\u00b3", 0, 4168000000000, {{"{0}mi\u00b3", "{0}mi\u00b3", "{0} mi\u00b3", "{0} mi\u00b3", "{0} cubic mile", "{0} cubic miles"}, {"{0}mi\u00b3", "{0}mi\u00b3", "{0} mi\u00b3", "{0} mi\u00b3", "{0} cubic mile", "{0} cubic miles"}}, {{"mi\u00b3", "mi\u00b3", "cubic miles"}, {"mi\u00b3", "mi\u00b3", "cubic miles"}}},
    {"mm\u00b3", 0, 9.9999999999999995e-07, {{"{0} mm\u00b3", "{0} mm\u00b3", "{0} mm\u00b3", "{0} mm\u00b3", "{0} mm\u00b3", "{0} mm\u00b3"}, {"{0} mm\u00b3", "{0} mm\u00b3", "{0} mm\u00b3", "{0} mm\u00b3", "{0} mm\u00b3", "{0} mm\u00b3"}}, {{"mm\u00b3", "mm\u00b3", "mm\u00b3"}, {"mm\u00b3", "mm\u00b3", "mm\u00b3"}}},
    {"yd\u00b3", 0, 764.55499999999995, {{"{0}yd\u00b3", "{0}yd\u00b3", "{0} yd\u00b3", "{0} yd\u00b3", "{0} cubic yard", "{0} cubic yards"}, {"{0}yd\u00b3", "{0}yd\u00b3", "{0} yd\u00b3", "{0} yd\u00b3", "{0} cubic yard", "{0} cubic yards"}}, {{"yd\u00b3", "yards\u00b3", "cubic yards"}, {"yd\u00b3", "yards\u00b3", "cubic yards"}}},
    {"cup", 0, 0.23999999999999999, {{"{0}c", "{0}c", "{0} c", "{0} c", "{0} cup", "{0} cups"}, {"{0}c", "{0}c", "{0} c", "{0} c", "{0} cup", "{0} cups"}}, {{"cup", "cups", "cups"}, {"cup", "cups", "cups"}}},
    {"dL", 0, 0.10000000000000001, {{"{0}dL", "{0}dL", "{0} dL", "{0} dL", "{0} deciliter", "{0} deciliters"}, {"{0}dl", "{0}dl", "{0} dl", "{0} dl", "{0} decilitre", "{0} decilitres"}}, {{"dL", "dL", "deciliters"}, {"dl", "dl", "decilitres"}}},
    {"fl oz", 0, 0.029573499999999999, {{"{0}fl oz", "{0}fl oz", "{0} fl oz", "{0} fl oz", "{0} fluid ounce", "{0} fluid ounces"}, {"{0}US fl oz", "{0}US fl oz", "{0} US fl oz", "{0} US fl oz", "{0} US fluid ounce", "{0} US fluid ounces"}}, {{"fl oz", "fl oz", "fluid ounces"}, {"US fl oz", "US fl oz", "US fluid ounces"}}},
    {"fl oz", 0, 0.0284131, {{"0.96{0}fl oz", "1.9{0}2fl oz", "0.96{0} fl oz", "1.9{0}2 fl oz", "0.96{0} fluid ounces", "1.9{0}2 fluid ounces"}, {"0.96{0}US fl oz", "1.9{0}2US fl oz", "0.96{0} US fl oz", "1.9{0}2 US fl oz", "0.96{0} US fluid ounces", "1.9{0}2 US fluid ounces"}}, {{"fl oz", "fl oz", "fluid ounces"}, {"US fl oz", "US fl oz", "US fluid ounces"}}},
    {"pt", 0, 0.56826100000000002, {{"{0}.201pt", "{0}.402pt", "{0}.201 pt", "{0}.402 pt", "{0}.201 pints", "{0}.402 pints"}, {"{0}.201pt", "{0}.402pt", "{0}.201 pt", "{0}.402 pt", "{0}.201 pints", "{0}.402 pints"}}, {{"pt", "pints", "pints"}, {"pt", "pints", "pints"}}},
    {"qt", 0, 1.13652, {{"{0}.201qt", "{0}.402qt", "{0}.201 qt", "{0}.402 qt", "{0}.201 quarts", "{0}.402 quarts"}, {"{0}.201USqt", "{0}.402USqt", "{0}.201 US qt", "{0}.402 US qt", "{0}.201 US quarts", "{0}.402 US quarts"}}, {{"qt", "qts", "quarts"}, {"USqt", "US qts", "US quarts"}}},
    {"tbsp", 0, 0.017758199999999998, {{"{0}.201tbsp", "{0}.402tbsp", "{0}.201 tbsp", "{0}.402 tbsp", "{0}.201 tablespoons", "{0}.402 tablespoons"}, {"{0}.201tbsp", "{0}.402tbsp", "{0}.201 tbsp", "{0}.402 tbsp", "{0}.201 tablespoons", "{0}.402 tablespoons"}}, {{"tbsp", "tbsp", "tablespoons"}, {"tbsp", "tbsp", "tablespoons"}}},
    {"tsp", 0, 0.0059193900000000001, {{"{0}.201tsp", "{0}.402tsp", "{0}.201 tsp", "{0}.402 tsp", "{0}.201 teaspoons", "{0}.402 teaspoons"}, {"{0}.201tsp", "{0}.402tsp", "{0}.201 tsp", "{0}.402 tsp", "{0}.201 teaspoons", "{0}.402 teaspoons"}}, {{"tsp", "tsp", "teaspoons"}, {"tsp", "tsp", "teaspoons"}}},
    {"kL", 0, 1000, {{"{0} kL", "{0} kL", "{0} kL", "{0} kL", "{0} kL", "{0} kL"}, {"{0} kL", "{0} kL", "{0} kL", "{0} kL", "{0} kL", "{0} kL"}}, {{"kL", "kL", "kL"}, {"kL", "kL", "kL"}}},
    {"L", 0, 1, {{"{0}L", "{0}L", "{0} L", "{0} L", "{0} liter", "{0} liters"}, {"{0}l", "{0}l", "{0} l", "{0} l", "{0} litre", "{0} litres"}}, {{"liter", "liters", "liters"}, {"litre", "litres", "litres"}}},
    {"ML", 0, 1000000, {{"{0}ML", "{0}ML", "{0} ML", "{0} ML", "{0} megaliter", "{0} megaliters"}, {"{0}Ml", "{0}Ml", "{0} Ml", "{0} Ml", "{0} megalitre", "{0} megalitres"}}, {{"ML", "ML", "megaliters"}, {"Ml", "Ml", "megalitres"}}},
    {"metric cup", 0, 0.25, {{"{0}mc", "{0}mc", "{0} mc", "{0} mc", "{0} metric cup", "{0} metric cups"}, {"{0}mc", "{0}mc", "{0} mc", "{0} mc", "{0} metric cup", "{0} metric cups"}}, {{"mcup", "mcup", "metric cups"}, {"mcup", "mcup", "metric cups"}}},
    {"mL", 0, 0.001, {{"{0}mL", "{0}mL", "{0} mL", "{0} mL", "{0} milliliter", "{0} milliliters"}, {"{0}ml", "{0}ml", "{0} ml", "{0} ml", "{0} millilitre", "{0} millilitres"}}, {{"mL", "mL", "milliliters"}, {"ml", "ml", "millilitres"}}},
    {"pt", 0, 0.47317599999999999, {{"{0}pt", "{0}pt", "{0} pt", "{0} pt", "{0} pint", "{0} pints"}, {"{0}pt", "{0}pt", "{0} pt", "{0} pt", "{0} pint", "{0} pints"}}, {{"pt", "pints", "pints"}, {"pt", "pints", "pints"}}},
    {"qt", 0, 0.946353, {{"{0}qt", "{0}qt", "{0} qt", "{0} qt", "{0} quart", "{0} quarts"}, {"{0}USqt", "{0}USqt", "{0} US qt", "{0} US qt", "{0} US quart", "{0} US quarts"}}, {{"qt", "qts", "quarts"}, {"USqt", "US qts", "US quarts"}}},
    {"tbsp", 0, 0.014786799999999999, {{"{0}tbsp", "{0}tbsp", "{0} tbsp", "{0} tbsp", "{0} tablespoon", "{0} tablespoons"}, {"{0}tbsp", "{0}tbsp", "{0} tbsp", "{0} tbsp", "{0} tablespoon", "{0} tablespoons"}}, {{"tbsp", "tbsp", "tablespoons"}, {"tbsp", "tbsp", "tablespoons"}}},
    {"tsp", 0, 0.0049289199999999998, {{"{0}tsp", "{0}tsp", "{0} tsp", "{0} tsp", "{0} teaspoon", "{0} teaspoons"}, {"{0}tsp", "{0}tsp", "{0} tsp", "{0} tsp", "{0} teaspoon", "{0} teaspoons"}}, {{"tsp", "tsp", "teaspoons"}, {"tsp", "tsp", "teaspoons"}}},
};

const RevenantMeasurementDimension revenant_measurement_dimensions[] = {
    {"NSUnitAcceleration", revenant_units_0, 2},
    {"NSUnitAngle", revenant_units_1, 6},
    {"NSUnitArea", revenant_units_2, 14},
    {"NSUnitConcentrationMass", revenant_units_3, 2},
    {"NSUnitDispersion", revenant_units_4, 1},
    {"NSUnitDuration", revenant_units_5, 7},
    {"NSUnitElectricCharge", revenant_units_6, 6},
    {"NSUnitElectricCurrent", revenant_units_7, 5},
    {"NSUnitElectricPotentialDifference", revenant_units_8, 5},
    {"NSUnitElectricResistance", revenant_units_9, 5},
    {"NSUnitEnergy", revenant_units_10, 6},
    {"NSUnitFrequency", revenant_units_11, 9},
    {"NSUnitFuelEfficiency", revenant_units_12, 3},
    {"NSUnitIlluminance", revenant_units_13, 1},
    {"NSUnitInformationStorage", revenant_units_14, 35},
    {"NSUnitLength", revenant_units_15, 22},
    {"NSUnitMass", revenant_units_16, 16},
    {"NSUnitPower", revenant_units_17, 11},
    {"NSUnitPressure", revenant_units_18, 10},
    {"NSUnitSpeed", revenant_units_19, 4},
    {"NSUnitTemperature", revenant_units_20, 3},
    {"NSUnitVolume", revenant_units_21, 31},
};

const size_t revenant_measurement_dimension_count = sizeof revenant_measurement_dimensions / sizeof *revenant_measurement_dimensions;
