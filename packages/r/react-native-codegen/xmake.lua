package("react-native-codegen")
    set_kind("binary")
    set_homepage("https://github.com/facebook/react-native/tree/v0.86.3/packages/react-native-codegen")
    set_description("The React Native 0.86.3 codegen as a host tool: the runner of the react-native npm package and @react-native/codegen with the npm tree they load, which generates the Fabric component headers of a library under node")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://registry.npmjs.org/react-native/-/react-native-$(version).tgz")
    add_versions("0.86.3", "04e0ef4284ef9e2fb94075b0f98c6371d12ea1b31c2e42540a900a1e86ea46f5")
    add_deps("revenant@node 26.13.0", {alias = "node", kind = "binary"})
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "2", readonly = true})

    local DEPENDENCIES = {
        {"node_modules/@babel/code-frame", "https://registry.npmjs.org/@babel/code-frame/-/code-frame-7.29.0.tgz", "sha512-9NhCeYjq9+3uxgdtp20LSiJXJvN0FeCtNGpJxuMFZ1Kv3cWUNb6DOhJwUvcVCzKGR66cw4njwM6hrJLqgOwbcw=="},
        {"node_modules/@babel/compat-data", "https://registry.npmjs.org/@babel/compat-data/-/compat-data-7.29.0.tgz", "sha512-T1NCJqT/j9+cn8fvkt7jtwbLBfLC/1y1c7NtCeXFRgzGTsafi68MRv8yzkYSapBnFA6L3U2VSc02ciDzoAJhJg=="},
        {"node_modules/@babel/core", "https://registry.npmjs.org/@babel/core/-/core-7.29.0.tgz", "sha512-CGOfOJqWjg2qW/Mb6zNsDm+u5vFQ8DxXfbM09z69p5Z6+mE1ikP2jUXw+j42Pf1XTYED2Rni5f95npYeuwMDQA=="},
        {"node_modules/@babel/core/node_modules/semver", "https://registry.npmjs.org/semver/-/semver-6.3.1.tgz", "sha512-BR7VvDCVHO+q2xBEWskxS6DJE1qRnb7DxzUrogb71CWoSficBxYsiAGd+Kl0mmq/MprG9yArRkyrQxTO6XjMzA=="},
        {"node_modules/@babel/generator", "https://registry.npmjs.org/@babel/generator/-/generator-7.29.1.tgz", "sha512-qsaF+9Qcm2Qv8SRIMMscAvG4O3lJ0F1GuMo5HR/Bp02LopNgnZBC/EkbevHFeGs4ls/oPz9v+Bsmzbkbe+0dUw=="},
        {"node_modules/@babel/helper-compilation-targets", "https://registry.npmjs.org/@babel/helper-compilation-targets/-/helper-compilation-targets-7.28.6.tgz", "sha512-JYtls3hqi15fcx5GaSNL7SCTJ2MNmjrkHXg4FSpOA/grxK8KwyZ5bubHsCq8FXCkua6xhuaaBit+3b7+VZRfcA=="},
        {"node_modules/@babel/helper-compilation-targets/node_modules/lru-cache", "https://registry.npmjs.org/lru-cache/-/lru-cache-5.1.1.tgz", "sha512-KpNARQA3Iwv+jTA0utUVVbrh+Jlrr1Fv0e56GGzAFOXN7dk/FviaDW8LHmK52DlcH4WP2n6gI8vN1aesBFgo9w=="},
        {"node_modules/@babel/helper-compilation-targets/node_modules/semver", "https://registry.npmjs.org/semver/-/semver-6.3.1.tgz", "sha512-BR7VvDCVHO+q2xBEWskxS6DJE1qRnb7DxzUrogb71CWoSficBxYsiAGd+Kl0mmq/MprG9yArRkyrQxTO6XjMzA=="},
        {"node_modules/@babel/helper-compilation-targets/node_modules/yallist", "https://registry.npmjs.org/yallist/-/yallist-3.1.1.tgz", "sha512-a4UGQaWPH59mOXUYnAG2ewncQS4i4F43Tv3JoAM+s2VDAmS9NsK8GpDMLrCHPksFT7h3K6TOoUNn2pb7RoXx4g=="},
        {"node_modules/@babel/helper-globals", "https://registry.npmjs.org/@babel/helper-globals/-/helper-globals-7.28.0.tgz", "sha512-+W6cISkXFa1jXsDEdYA8HeevQT/FULhxzR99pxphltZcVaugps53THCeiWA8SguxxpSp3gKPiuYfSWopkLQ4hw=="},
        {"node_modules/@babel/helper-module-imports", "https://registry.npmjs.org/@babel/helper-module-imports/-/helper-module-imports-7.28.6.tgz", "sha512-l5XkZK7r7wa9LucGw9LwZyyCUscb4x37JWTPz7swwFE/0FMQAGpiWUZn8u9DzkSBWEcK25jmvubfpw2dnAMdbw=="},
        {"node_modules/@babel/helper-module-transforms", "https://registry.npmjs.org/@babel/helper-module-transforms/-/helper-module-transforms-7.28.6.tgz", "sha512-67oXFAYr2cDLDVGLXTEABjdBJZ6drElUSI7WKp70NrpyISso3plG9SAGEF6y7zbha/wOzUByWWTJvEDVNIUGcA=="},
        {"node_modules/@babel/helper-string-parser", "https://registry.npmjs.org/@babel/helper-string-parser/-/helper-string-parser-7.27.1.tgz", "sha512-qMlSxKbpRlAridDExk92nSobyDdpPijUq2DW6oDnUqd0iOGxmQjyqhMIihI9+zv4LPyZdRje2cavWPbCbWm3eA=="},
        {"node_modules/@babel/helper-validator-identifier", "https://registry.npmjs.org/@babel/helper-validator-identifier/-/helper-validator-identifier-7.28.5.tgz", "sha512-qSs4ifwzKJSV39ucNjsvc6WVHs6b7S03sOh2OcHF9UHfVPqWWALUsNUVzhSBiItjRZoLHx7nIarVjqKVusUZ1Q=="},
        {"node_modules/@babel/helper-validator-option", "https://registry.npmjs.org/@babel/helper-validator-option/-/helper-validator-option-7.27.1.tgz", "sha512-YvjJow9FxbhFFKDSuFnVCe2WxXk1zWc22fFePVNEaWJEu8IrZVlda6N0uHwzZrUM1il7NC9Mlp4MaJYbYd9JSg=="},
        {"node_modules/@babel/helpers", "https://registry.npmjs.org/@babel/helpers/-/helpers-7.28.6.tgz", "sha512-xOBvwq86HHdB7WUDTfKfT/Vuxh7gElQ+Sfti2Cy6yIWNW05P8iUslOVcZ4/sKbE+/jQaukQAdz/gf3724kYdqw=="},
        {"node_modules/@babel/parser", "https://registry.npmjs.org/@babel/parser/-/parser-7.29.0.tgz", "sha512-IyDgFV5GeDUVX4YdF/3CPULtVGSXXMLh1xVIgdCgxApktqnQV0r7/8Nqthg+8YLGaAtdyIlo2qIdZrbCv4+7ww=="},
        {"node_modules/@babel/template", "https://registry.npmjs.org/@babel/template/-/template-7.28.6.tgz", "sha512-YA6Ma2KsCdGb+WC6UpBVFJGXL58MDA6oyONbjyF/+5sBgxY/dwkhLogbMT2GXXyU84/IhRw/2D1Os1B/giz+BQ=="},
        {"node_modules/@babel/traverse", "https://registry.npmjs.org/@babel/traverse/-/traverse-7.29.0.tgz", "sha512-4HPiQr0X7+waHfyXPZpWPfWL/J7dcN1mx9gL6WdQVMbPnF3+ZhSMs8tCxN7oHddJE9fhNE7+lxdnlyemKfJRuA=="},
        {"node_modules/@babel/types", "https://registry.npmjs.org/@babel/types/-/types-7.29.0.tgz", "sha512-LwdZHpScM4Qz8Xw2iKSzS+cfglZzJGvofQICy7W7v4caru4EaAmyUuO6BGrbyQ2mYV11W0U8j5mBhd14dd3B0A=="},
        {"node_modules/@jridgewell/gen-mapping", "https://registry.npmjs.org/@jridgewell/gen-mapping/-/gen-mapping-0.3.13.tgz", "sha512-2kkt/7niJ6MgEPxF0bYdQ6etZaA+fQvDcLKckhy1yIQOzaoKjBBjSj63/aLVjYE3qhRt5dvM+uUyfCg6UKCBbA=="},
        {"node_modules/@jridgewell/remapping", "https://registry.npmjs.org/@jridgewell/remapping/-/remapping-2.3.5.tgz", "sha512-LI9u/+laYG4Ds1TDKSJW2YPrIlcVYOwi2fUC6xB43lueCjgxV4lffOCZCtYFiH6TNOX+tQKXx97T4IKHbhyHEQ=="},
        {"node_modules/@jridgewell/resolve-uri", "https://registry.npmjs.org/@jridgewell/resolve-uri/-/resolve-uri-3.1.2.tgz", "sha512-bRISgCIjP20/tbWSPWMEi54QVPRZExkuD9lJL+UIxUKtwVJA8wW1Trb1jMs1RFXo1CBTNZ/5hpC9QvmKWdopKw=="},
        {"node_modules/@jridgewell/sourcemap-codec", "https://registry.npmjs.org/@jridgewell/sourcemap-codec/-/sourcemap-codec-1.5.5.tgz", "sha512-cYQ9310grqxueWbl+WuIUIaiUaDcj7WOq5fVhEljNVgRfOUhY9fy2zTvfoqWsnebh8Sl70VScFbICvJnLKB0Og=="},
        {"node_modules/@jridgewell/trace-mapping", "https://registry.npmjs.org/@jridgewell/trace-mapping/-/trace-mapping-0.3.31.tgz", "sha512-zzNR+SdQSDJzc8joaeP8QQoCQr8NuYx2dIIytl1QeBEZHJ9uW6hebsrYgbz8hJwUQao3TWCMtmfV8Nu1twOLAw=="},
        {"node_modules/ansi-regex", "https://registry.npmjs.org/ansi-regex/-/ansi-regex-5.0.1.tgz", "sha512-quJQXlTSUGL2LH9SUXo8VwsY4soanhgo6LNSm84E1LBcE8s3O0wpdiRzyR9z/ZZJMlMWv37qOOb9pdJlMUEKFQ=="},
        {"node_modules/ansi-styles", "https://registry.npmjs.org/ansi-styles/-/ansi-styles-4.3.0.tgz", "sha512-zbB9rCJAT1rbjiVDb2hqKFHNYLxgtk8NURxZ3IZwD3F6NtxbXZQCnnSi1Lkx+IDohdPlFp222wVALIheZJQSEg=="},
        {"node_modules/baseline-browser-mapping", "https://registry.npmjs.org/baseline-browser-mapping/-/baseline-browser-mapping-2.10.0.tgz", "sha512-lIyg0szRfYbiy67j9KN8IyeD7q7hcmqnJ1ddWmNt19ItGpNN64mnllmxUNFIOdOm6by97jlL6wfpTTJrmnjWAA=="},
        {"node_modules/browserslist", "https://registry.npmjs.org/browserslist/-/browserslist-4.28.1.tgz", "sha512-ZC5Bd0LgJXgwGqUknZY/vkUQ04r8NXnJZ3yYi4vDmSiZmC/pdSN0NbNRPxZpbtO4uAfDUAFffO8IZoM3Gj8IkA=="},
        {"node_modules/caniuse-lite", "https://registry.npmjs.org/caniuse-lite/-/caniuse-lite-1.0.30001777.tgz", "sha512-tmN+fJxroPndC74efCdp12j+0rk0RHwV5Jwa1zWaFVyw2ZxAuPeG8ZgWC3Wz7uSjT3qMRQ5XHZ4COgQmsCMJAQ=="},
        {"node_modules/cliui", "https://registry.npmjs.org/cliui/-/cliui-8.0.1.tgz", "sha512-BSeNnyus75C4//NQ9gQt1/csTXyo/8Sb+afLAkzAptFuMsod9HFokGNudZpi/oQV73hnVK+sR+5PVRMd+Dr7YQ=="},
        {"node_modules/color-convert", "https://registry.npmjs.org/color-convert/-/color-convert-2.0.1.tgz", "sha512-RRECPsj7iu/xb5oKYcsFHSppFNnsj/52OVTRKb4zP5onXwVF3zVmmToNcOfGC+CRDpfK/U584fMg38ZHCaElKQ=="},
        {"node_modules/color-name", "https://registry.npmjs.org/color-name/-/color-name-1.1.4.tgz", "sha512-dOy+3AuW3a2wNbZHIuMZpTcgjGuLU/uBL/ubcZF9OXbDo8ff4O8yVp5Bf0efS8uEoYo5q4Fx7dY9OgQGXgAsQA=="},
        {"node_modules/convert-source-map", "https://registry.npmjs.org/convert-source-map/-/convert-source-map-2.0.0.tgz", "sha512-Kvp459HrV2FEJ1CAsi1Ku+MY3kasH19TFykTz2xWmMeq6bk2NU3XXvfJ+Q61m0xktWwt+1HSYf3JZsTms3aRJg=="},
        {"node_modules/debug", "https://registry.npmjs.org/debug/-/debug-4.4.3.tgz", "sha512-RGwwWnwQvkVfavKVt22FGLw+xYSdzARwm0ru6DhTVA3umU5hZc28V3kO4stgYryrTlLpuvgI9GiijltAjNbcqA=="},
        {"node_modules/electron-to-chromium", "https://registry.npmjs.org/electron-to-chromium/-/electron-to-chromium-1.5.307.tgz", "sha512-5z3uFKBWjiNR44nFcYdkcXjKMbg5KXNdciu7mhTPo9tB7NbqSNP2sSnGR+fqknZSCwKkBN+oxiiajWs4dT6ORg=="},
        {"node_modules/emoji-regex", "https://registry.npmjs.org/emoji-regex/-/emoji-regex-8.0.0.tgz", "sha512-MSjYzcWNOA0ewAHpz0MxpYFvwg6yjy1NG3xteoqz644VCo/RPgnr1/GGt+ic3iJTzQ8Eu3TdM14SawnVUmGE6A=="},
        {"node_modules/escalade", "https://registry.npmjs.org/escalade/-/escalade-3.2.0.tgz", "sha512-WUj2qlxaQtO4g6Pq5c29GTcWGDyd8itL8zTlipgECz3JesAiiOKotd8JU6otB3PACgG6xkJUyVhboMS+bje/jA=="},
        {"node_modules/fdir", "https://registry.npmjs.org/fdir/-/fdir-6.5.0.tgz", "sha512-tIbYtZbucOs0BRGqPJkshJUYdL+SDH7dVM8gjy+ERp3WAUjLEFJE+02kanyHtwjWOnwrKYBiwAmM0p4kLJAnXg=="},
        {"node_modules/gensync", "https://registry.npmjs.org/gensync/-/gensync-1.0.0-beta.2.tgz", "sha512-3hN7NaskYvMDLQY55gnW3NQ+mesEAepTqlg+VEbj7zzqEMBVNhzcGYYeqFo/TlYz6eQiFcp1HcsCZO+nGgS8zg=="},
        {"node_modules/get-caller-file", "https://registry.npmjs.org/get-caller-file/-/get-caller-file-2.0.5.tgz", "sha512-DyFP3BM/3YHTQOCUL/w0OZHR0lpKeGrxotcHWcqNEdnltqFwXVfhEBQ94eIo34AfQpo0rGki4cyIiftY06h2Fg=="},
        {"node_modules/invariant", "https://registry.npmjs.org/invariant/-/invariant-2.2.4.tgz", "sha512-phJfQVBuaJM5raOpJjSfkiD6BpbCE4Ns//LaXl6wGYtUBY83nWS6Rf9tXm2e8VaK60JEjYldbPif/A2B1C2gNA=="},
        {"node_modules/is-fullwidth-code-point", "https://registry.npmjs.org/is-fullwidth-code-point/-/is-fullwidth-code-point-3.0.0.tgz", "sha512-zymm5+u+sCsSWyD9qNaejV3DFvhCKclKdizYaJUuHA83RLjb7nSuGnddCHGv0hk+KY7BMAlsWeK4Ueg6EV6XQg=="},
        {"node_modules/js-tokens", "https://registry.npmjs.org/js-tokens/-/js-tokens-4.0.0.tgz", "sha512-RdJUflcE3cUzKiMqQgsCu06FPu9UdIJO0beYbPhHN4k6apgJtifcoCtT9bcxOpYBtpD2kCM6Sbzg4CausW/PKQ=="},
        {"node_modules/jsesc", "https://registry.npmjs.org/jsesc/-/jsesc-3.1.0.tgz", "sha512-/sM3dO2FOzXjKQhJuo0Q173wf2KOo8t4I8vHy6lF9poUp7bKT0/NHE8fPX23PwfhnykfqnC2xRxOnVw5XuGIaA=="},
        {"node_modules/json5", "https://registry.npmjs.org/json5/-/json5-2.2.3.tgz", "sha512-XmOWe7eyHYH14cLdVPoyg+GOH3rYX++KpzrylJwSW98t3Nk+U8XOl8FWKOgwtzdb8lXGf6zYwDUzeHMWfxasyg=="},
        {"node_modules/loose-envify", "https://registry.npmjs.org/loose-envify/-/loose-envify-1.4.0.tgz", "sha512-lyuxPGr/Wfhrlem2CL/UcnUc1zcqKAImBDzukY7Y5F/yQiNdko6+fRLevlw1HgMySw7f611UIY408EtxRSoK3Q=="},
        {"node_modules/ms", "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz", "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA=="},
        {"node_modules/node-releases", "https://registry.npmjs.org/node-releases/-/node-releases-2.0.36.tgz", "sha512-TdC8FSgHz8Mwtw9g5L4gR/Sh9XhSP/0DEkQxfEFXOpiul5IiHgHan2VhYYb6agDSfp4KuvltmGApc8HMgUrIkA=="},
        {"node_modules/nullthrows", "https://registry.npmjs.org/nullthrows/-/nullthrows-1.1.1.tgz", "sha512-2vPPEi+Z7WqML2jZYddDIfy5Dqb0r2fze2zTxNNknZaFpVHU3mFB3R+DWeJWGVx0ecvttSGlJTI+WG+8Z4cDWw=="},
        {"node_modules/picocolors", "https://registry.npmjs.org/picocolors/-/picocolors-1.1.1.tgz", "sha512-xceH2snhtb5M9liqDsmEw56le376mTZkEX/jEb/RxNFyegNul7eNslCXP9FDj/Lcu0X8KEyMceP2ntpaHrDEVA=="},
        {"node_modules/picomatch", "https://registry.npmjs.org/picomatch/-/picomatch-4.0.5.tgz", "sha512-RvwwcruNjI1ncT5xRakeyS9Lf8lcItv34KD+aif+VH9kduAyfYBipGh12274xtenIPZ119/R9BdTBa8gAwSh0A=="},
        {"react-native/node_modules/@react-native/codegen", "https://registry.npmjs.org/@react-native/codegen/-/codegen-0.86.3.tgz", "sha512-Ux4jHi0fh+bdtVEcL0gaPLbY56V+SvFUDl/8sRAE1jdb4k+o7fT/4Nc29yz4X+qfjstkSqObQTMBGhdzxH9JvA=="},
        {"react-native/node_modules/hermes-estree", "https://registry.npmjs.org/hermes-estree/-/hermes-estree-0.36.0.tgz", "sha512-A1+8zn5oss2CFP7pKsOaxorQG6FNIz1WU1VDqruLPPZl3LVgeE2C5xfFg8Ow6/Ow4mSslLLtYP1J3n38eKyW9w=="},
        {"react-native/node_modules/hermes-parser", "https://registry.npmjs.org/hermes-parser/-/hermes-parser-0.36.0.tgz", "sha512-GdpwMmH5x6IpC1cijvcvYnlPB60Mh6kTSF/NFdYV/j56gYdi+0RIakYs+eqOV+bbO0SW7mgVVGSsTJxyPQfo3w=="},
        {"node_modules/require-directory", "https://registry.npmjs.org/require-directory/-/require-directory-2.1.1.tgz", "sha512-fGxEI7+wsG9xrvdjsrlmL22OMTTiHRwAMroiEeMgq8gzoLC/PQr7RsRDSTLUg/bZAZtF+TVIkHc6/4RIKrui+Q=="},
        {"node_modules/string-width", "https://registry.npmjs.org/string-width/-/string-width-4.2.3.tgz", "sha512-wKyQRQpjJ0sIp62ErSZdGsjMJWsap5oRNihHhu6G7JVO/9jIB6UyevL+tXuOqrng8j/cxKTWyWUwvSTriiZz/g=="},
        {"node_modules/strip-ansi", "https://registry.npmjs.org/strip-ansi/-/strip-ansi-6.0.1.tgz", "sha512-Y38VPSHcqkFrCpFnQ9vuSXmquuv5oXOKpGeT6aGrr3o3Gc9AlVa6JBfUSOCnbxGGZF+/0ooI7KrPuUSztUdU5A=="},
        {"node_modules/tinyglobby", "https://registry.npmjs.org/tinyglobby/-/tinyglobby-0.2.15.tgz", "sha512-j2Zq4NyQYG5XMST4cbs02Ak8iJUdxRM0XI5QyxXuZOzKOINmWurp3smXu3y5wDcJrptwpSjgXHzIQxR0omXljQ=="},
        {"node_modules/update-browserslist-db", "https://registry.npmjs.org/update-browserslist-db/-/update-browserslist-db-1.2.3.tgz", "sha512-Js0m9cx+qOgDxo0eMiFGEueWztz+d4+M3rGlmKPT+T4IS/jP4ylw3Nwpu6cpTTP8R1MAC1kF4VbdLt3ARf209w=="},
        {"node_modules/wrap-ansi", "https://registry.npmjs.org/wrap-ansi/-/wrap-ansi-7.0.0.tgz", "sha512-YVGIj2kamLSTxw6NsZjoBxfSwsn0ycdesmc4p+Q21c5zPuZ1pl+NfxVdxPtdHvmNVOQ6XSYG4AUtyt/Fi7D16Q=="},
        {"node_modules/y18n", "https://registry.npmjs.org/y18n/-/y18n-5.0.8.tgz", "sha512-0pfFzegeDWJHJIAmTLRP2DwHjdF5s7jo9tuztdQxAhINCdvS+3nGINqPd00AphqJR/0LhANUS6/+7SCb98YOfA=="},
        {"node_modules/yargs", "https://registry.npmjs.org/yargs/-/yargs-17.7.2.tgz", "sha512-7dSzzRQ++CKnNI/krKnYRV7JKKPUXMEh61soaHKg9mrWEhzFWhFnxPxGl+69cD1Ou63C13NUPCnmIcrvqCuM6w=="},
        {"node_modules/yargs/node_modules/yargs-parser", "https://registry.npmjs.org/yargs-parser/-/yargs-parser-21.1.1.tgz", "sha512-tVpsJW7DdjecAiFpbIB1e3qxIQsE6NoPc5/eTdrbbIC4h0LVsWhnoa3g+m2HclBIujHzsxZ4VJVA+GUuc2/LBw=="},
    }

    on_install("@macosx|arm64", function (package)
        local function integrity(file)
            local digest = file .. ".sha512"
            os.vrunv("sh", {"-c", "openssl dgst -sha512 -binary '" .. file .. "' | openssl base64 -A > '" .. digest .. "'"})
            local value = io.readfile(digest):trim()
            os.tryrm(digest)
            return "sha512-" .. value
        end
        local archives = path.join(package:cachedir(), "archives")
        local tree = path.join(package:cachedir(), "tree")
        os.rm(tree)
        os.mkdir(archives)
        os.mkdir(path.join(tree, "react-native"))
        os.cp("scripts", path.join(tree, "react-native"))
        os.cp("src", path.join(tree, "react-native"))
        os.cp("package.json", path.join(tree, "react-native"))
        os.mkdir(package:installdir("licenses"))
        os.cp("LICENSE", package:installdir("licenses"))
        for index, dependency in ipairs(DEPENDENCIES) do
            local name, url, expected = dependency[1], dependency[2], dependency[3]
            local archive = path.join(archives, index .. "-" .. path.filename(url))
            if not os.isfile(archive) or integrity(archive) ~= expected then
                os.tryrm(archive)
                import("net.http").download(url, archive)
            end
            local found = integrity(archive)
            if found ~= expected then
                raise("%s has integrity %s, not the %s of the lock", url, found, expected)
            end
            local folder = path.join(tree, name)
            os.mkdir(folder)
            os.vrunv("tar", {"-xzf", archive, "-C", folder, "--strip-components=1"})
        end
        os.vcp(path.join(tree, "*"), package:installdir() .. "/")
    end)

    on_test(function (package)
        local node = path.join(package:dep("node"):installdir("bin"), "node")
        local runner = path.join(package:installdir("react-native"), "scripts", "generate-codegen-artifacts.js")
        os.vrunv(node, {"-e", "const from = [require('path').dirname(process.argv[1])]; if (require(require.resolve('@react-native/codegen/package.json', {paths: from})).version !== '0.86.3') process.exit(1)", runner})
        local usage = path.join(package:cachedir(), "usage.txt")
        os.vrunv(node, {runner, "--help"}, {stdout = usage})
        assert(io.readfile(usage):find("Usage", 1, true), "the codegen runner prints no usage")
        os.tryrm(usage)
    end)
