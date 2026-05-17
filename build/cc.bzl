load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library", "cc_test")
load("@rules_cc//cc:objc_library.bzl", "objc_library")

_WIN_DEFINES = [
    "NOMINMAX",
    "UNICODE",
    "WIN32_LEAN_AND_MEAN",
    "_CRT_SECURE_NO_WARNINGS",
    "_HAS_EXCEPTIONS=0",
    "_UNICODE",
]

_CLANG_WARNINGS = [
    "-Wall",
    "-Wextra",
    "-Wendif-labels",
    "-Wextra-semi",
    "-Wheader-hygiene",
    "-Wnewline-eof",
    "-Wno-missing-field-initializers",
    "-Wno-unused-parameter",
    "-Wsign-compare",
    "-Wstring-conversion",
    "-Wvla",
]

_GCC_WARNINGS = [
    "-Wall",
    "-Wextra",
    "-Wno-missing-field-initializers",
    "-Wno-unused-parameter",
    "-Wsign-compare",
    "-Wvla",
    "-Wno-multichar",
    "-Wno-dangling-else",
    "-Wno-attributes",
    "-Wno-class-memaccess",
    "-Wno-restrict",
    "-Wno-ignored-attributes",
    "-Wno-infinite-recursion",
    "-Wno-uninitialized",
    "-Wno-unknown-pragmas",
]

_POSIX_HARDENING = [
    "-fno-exceptions",
    "-fno-rtti",
    "-fno-strict-aliasing",
    "-fstack-protector-all",
    "-fvisibility-inlines-hidden",
    "-fvisibility=hidden",
]

_CLANG_CL_SUPPRESSIONS = [
    "-Wno-cast-function-type-mismatch",
    "-Wno-format",
    "-Wno-microsoft-cast",
    "-Wno-missing-field-initializers",
    "-Wno-sign-compare",
    "-Wno-unused-const-variable",
    "-Wno-unused-function",
]

_MSVC_COMMON = [
    "/FS",
    "/W4",
    "/WX",
    "/bigobj",
    "/wd4996",
]

_MSVC_SUPPRESSIONS = [
    "/wd4100",
    "/wd4127",
    "/wd4324",
    "/wd4351",
    "/wd4577",
]

def crashpad_objc_library(
        name,
        deps = [],
        copts = [],
        **kwargs):
    objc_library(
        name = name,
        deps = ["//:config"] + deps,
        copts = _CLANG_WARNINGS + _POSIX_HARDENING + [
            "-fobjc-arc",
            "-std=c++23",
        ] + select({
            "//build:dbg_clang": ["-g"],
            "//build:opt_clang": ["-O3"],
            "//conditions:default": [],
        }) + copts,
        target_compatible_with = ["@platforms//os:macos"],
        **kwargs
    )

def crashpad_objc_binary(
        name,
        srcs = [],
        deps = [],
        copts = [],
        linkopts = [],
        **kwargs):
    crashpad_objc_library(
        name = name + "_objc_srcs",
        srcs = srcs,
        deps = deps,
        copts = copts,
        visibility = ["//visibility:private"],
    )

    cc_binary(
        name = name,
        deps = [":" + name + "_objc_srcs"],
        linkopts = select({
            "//build:opt_macos": ["-Wl,-dead_strip"],
            "//conditions:default": [],
        }) + linkopts,
        target_compatible_with = ["@platforms//os:macos"],
        **kwargs
    )

def crashpad_cc_library(
        name,
        deps = [],
        defines = [],
        copts = [],
        cxxopts = [],
        linkopts = [],
        conlyopts = [],
        linkstatic = True,
        **kwargs):
    return cc_library(
        name = name,
        deps = ["//:config"] + deps,
        cxxopts = select({
            "//build:msvc-cl": ["/std:c++23preview", "/Zc:__cplusplus"],
            "//build:clang-cl": ["/std:c++23preview", "/Zc:__cplusplus"],
            "//build:clang": ["-std=c++23"],
            "//build:gcc": ["-std=c++23"],
        }) + cxxopts,
        conlyopts = select({
            "//build:clang": ["-std=c11"],
            "//build:gcc": ["-std=c11"],
            "//conditions:default": [],
        }) + conlyopts,
        defines = select({
            "//build:msvc-cl": _WIN_DEFINES,
            "//build:clang-cl": _WIN_DEFINES,
            "//conditions:default": [],
        }) + select({
            "//build:linux": ["_FILE_OFFSET_BITS=64"],
            "//conditions:default": [],
        }) + defines,
        copts = select({
            "//build:msvc-cl": _MSVC_COMMON + _MSVC_SUPPRESSIONS,
            "//build:clang-cl": _MSVC_COMMON + _CLANG_CL_SUPPRESSIONS,
            "//build:clang": _CLANG_WARNINGS + _POSIX_HARDENING,
            "//build:gcc": _GCC_WARNINGS + _POSIX_HARDENING,
            "//conditions:default": [],
        }) + select({
            "//build:linux": ["-fPIC"],
            "//build:macos": ["-fobjc-call-cxx-cdtors"],
            "//conditions:default": [],
        }) + select({
            "//build:dbg_clang": ["-g"],
            "//build:dbg_gcc": ["-g"],
            "//build:dbg_msvc-cl": ["/Zi"],
            "//build:opt_clang": ["-O3"],
            "//build:opt_gcc": ["-O3"],
            "//build:opt_msvc-cl": [
                "/O2",
                "/Ob2",
                "/Oy-",
                "/Zc:inline",
            ],
            "//conditions:default": [],
        }) + select({
            "//build:opt_linux": [
                "-fdata-sections",
                "-ffunction-sections",
            ],
            "//conditions:default": [],
        }) + copts,
        linkopts = select({
            "//build:linux": [
                "-Wl,--as-needed",
                "-Wl,-z,noexecstack",
                "-pthread",
                "-ldl",
            ],
            "//build:macos": [
                "-mmacosx-version-min=12.0",
            ],
            "//conditions:default": [],
        }) + select({
            "//build:opt_linux": [
                "-Wl,-O1",
                "-Wl,--gc-sections",
            ],
            "//build:opt_macos": [
                "-Wl,-dead_strip",
            ],
            "//build:opt_windows": [
                "/OPT:ICF",
                "/OPT:REF",
            ],
            "//build:dbg_windows": ["/DEBUG"],
            "//conditions:default": [],
        }) + linkopts,
        linkstatic = linkstatic,
        **kwargs
    )

def crashpad_cc_binary(
        name,
        deps = [],
        cxxopts = [],
        conlyopts = [],
        defines = [],
        copts = [],
        linkopts = [],
        linkstatic = True,
        **kwargs):
    return cc_binary(
        name = name,
        deps = ["//:config"] + deps,
        cxxopts = select({
            "//build:msvc-cl": ["/std:c++23preview", "/Zc:__cplusplus"],
            "//build:clang-cl": ["/std:c++23preview", "/Zc:__cplusplus"],
            "//build:clang": ["-std=c++23"],
            "//build:gcc": ["-std=c++23"],
        }) + cxxopts,
        conlyopts = select({
            "//build:clang": ["-std=c11"],
            "//build:gcc": ["-std=c11"],
            "//conditions:default": [],
        }) + conlyopts,
        defines = select({
            "//build:msvc-cl": _WIN_DEFINES,
            "//build:clang-cl": _WIN_DEFINES,
            "//conditions:default": [],
        }) + select({
            "//build:linux": ["_FILE_OFFSET_BITS=64"],
            "//conditions:default": [],
        }) + defines,
        copts = select({
            "//build:msvc-cl": _MSVC_COMMON + _MSVC_SUPPRESSIONS,
            "//build:clang-cl": _MSVC_COMMON + _CLANG_CL_SUPPRESSIONS,
            "//build:clang": _CLANG_WARNINGS + _POSIX_HARDENING,
            "//build:gcc": _GCC_WARNINGS + _POSIX_HARDENING,
            "//conditions:default": [],
        }) + select({
            "//build:linux": ["-fPIC"],
            "//build:macos": ["-fobjc-call-cxx-cdtors"],
            "//conditions:default": [],
        }) + select({
            "//build:dbg_clang": ["-g"],
            "//build:dbg_gcc": ["-g"],
            "//build:dbg_msvc-cl": ["/Zi"],
            "//build:opt_clang": ["-O3"],
            "//build:opt_gcc": ["-O3"],
            "//build:opt_msvc-cl": [
                "/O2",
                "/Ob2",
                "/Oy-",
                "/Zc:inline",
            ],
            "//conditions:default": [],
        }) + select({
            "//build:opt_linux": [
                "-fdata-sections",
                "-ffunction-sections",
            ],
            "//conditions:default": [],
        }) + copts,
        linkopts = select({
            "//build:linux": [
                "-Wl,--as-needed",
                "-Wl,-z,noexecstack",
                "-pthread",
                "-ldl",
            ],
            "//build:macos": [
                "-mmacosx-version-min=12.0",
            ],
            "//conditions:default": [],
        }) + select({
            "//build:opt_linux": [
                "-Wl,-O1",
                "-Wl,--gc-sections",
            ],
            "//build:opt_macos": [
                "-Wl,-dead_strip",
            ],
            "//build:opt_windows": [
                "/OPT:ICF",
                "/OPT:REF",
            ],
            "//build:dbg_windows": ["/DEBUG"],
            "//conditions:default": [],
        }) + linkopts,
        linkstatic = linkstatic,
        **kwargs
    )

def crashpad_cc_loadable_module(
        name,
        testonly = False,
        target_compatible_with = [],
        **kwargs):
    crashpad_cc_binary(
        name = name + "_shared",
        linkshared = True,
        testonly = testonly,
        target_compatible_with = target_compatible_with,
        **kwargs
    )

    native.genrule(
        name = name,
        srcs = [":" + name + "_shared"],
        outs = [name + ".so"],
        cmd = "cp $(SRCS) $@",
        testonly = testonly,
        target_compatible_with = target_compatible_with,
    )

def crashpad_cc_test(
        name,
        deps = [],
        cxxopts = [],
        conlyopts = [],
        defines = [],
        copts = [],
        linkopts = [],
        linkstatic = True,
        size = "small",
        **kwargs):
    return cc_test(
        name = "crashpad_%s" % name,
        deps = ["//:config", "//test:googletest_main"] + deps,
        cxxopts = select({
            "//build:msvc-cl": ["/std:c++23preview", "/Zc:__cplusplus"],
            "//build:clang-cl": ["/std:c++23preview", "/Zc:__cplusplus"],
            "//build:clang": ["-std=c++23"],
            "//build:gcc": ["-std=c++23"],
        }) + cxxopts,
        conlyopts = select({
            "//build:clang": ["-std=c11"],
            "//build:gcc": ["-std=c11"],
            "//conditions:default": [],
        }) + conlyopts,
        defines = select({
            "//build:msvc-cl": _WIN_DEFINES,
            "//build:clang-cl": _WIN_DEFINES,
            "//conditions:default": [],
        }) + select({
            "//build:linux": ["_FILE_OFFSET_BITS=64"],
            "//conditions:default": [],
        }) + defines,
        copts = select({
            "//build:msvc-cl": _MSVC_COMMON + _MSVC_SUPPRESSIONS,
            "//build:clang-cl": _MSVC_COMMON + _CLANG_CL_SUPPRESSIONS,
            "//build:clang": _CLANG_WARNINGS + _POSIX_HARDENING,
            "//build:gcc": _GCC_WARNINGS + _POSIX_HARDENING,
            "//conditions:default": [],
        }) + select({
            "//build:linux": ["-fPIC"],
            "//build:macos": ["-fobjc-call-cxx-cdtors"],
            "//conditions:default": [],
        }) + select({
            "//build:dbg_clang": ["-g"],
            "//build:dbg_gcc": ["-g"],
            "//build:dbg_msvc-cl": ["/Zi"],
            "//build:opt_clang": ["-O3"],
            "//build:opt_gcc": ["-O3"],
            "//build:opt_msvc-cl": [
                "/O2",
                "/Ob2",
                "/Oy-",
                "/Zc:inline",
            ],
            "//conditions:default": [],
        }) + select({
            "//build:opt_linux": [
                "-fdata-sections",
                "-ffunction-sections",
            ],
            "//conditions:default": [],
        }) + copts,
        linkopts = select({
            "//build:linux": [
                "-Wl,--as-needed",
                "-Wl,-z,noexecstack",
                "-pthread",
                "-ldl",
            ],
            "//build:macos": [
                "-mmacosx-version-min=12.0",
            ],
            "//conditions:default": [],
        }) + select({
            "//build:opt_linux": [
                "-Wl,-O1",
                "-Wl,--gc-sections",
            ],
            "//build:opt_macos": [
                "-Wl,-dead_strip",
            ],
            "//build:opt_windows": [
                "/OPT:ICF",
                "/OPT:REF",
            ],
            "//build:dbg_windows": ["/DEBUG"],
            "//conditions:default": [],
        }) + linkopts,
        linkstatic = linkstatic,
        size = size,
        **kwargs
    )
