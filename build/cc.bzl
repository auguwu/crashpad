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

_CLANG_ONLY_WARNINGS = [
    "-Wendif-labels",
    "-Wexit-time-destructors",
    "-Wextra-semi",
    "-Wheader-hygiene",
    "-Wimplicit-fallthrough",
    "-Wnewline-eof",
    "-Wno-missing-field-initializers",
    "-Wno-unused-parameter",
    "-Wsign-compare",
    "-Wstring-conversion",
    "-Wvla",
]

_CLANG_WARNINGS = [
    "-Wall",
    "-Wextra",
] + _CLANG_ONLY_WARNINGS

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
    "/Zi",
    "/bigobj",
    "/wd4201",
    "/wd4996",
]

_MSVC_SUPPRESSIONS = [
    "/wd4100",
    "/wd4127",
    "/wd4324",
    "/wd4351",
    "/wd4577",
]

def _copts():
    return select({
        "//build:msvc-cl": _MSVC_COMMON + _MSVC_SUPPRESSIONS,
        "//build:clang-cl": _MSVC_COMMON + _CLANG_ONLY_WARNINGS + _CLANG_CL_SUPPRESSIONS,
        "//build:clang": _CLANG_WARNINGS + _POSIX_HARDENING,
        "//build:gcc": _GCC_WARNINGS + _POSIX_HARDENING,
        "//conditions:default": [],
    }) + select({
        "//build:linux": [
            "-fPIC",
            "-pthread",
        ],
        "//build:macos": ["-fobjc-call-cxx-cdtors"],
        "//conditions:default": [],
    }) + select({
        "//build:dbg_clang": ["-g"],
        "//build:dbg_gcc": ["-g"],
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
    })

def _cxxopts():
    return select({
        "//build:msvc-cl": ["/std:c++23preview", "/Zc:__cplusplus"],
        "//build:clang-cl": ["/std:c++23preview", "/Zc:__cplusplus"],
        "//build:clang": ["-std=c++23"],
        "//build:gcc": ["-std=c++23"],
    })

def _conlyopts():
    return select({
        "//build:clang": ["-std=c11"],
        "//build:gcc": ["-std=c11"],
        "//conditions:default": [],
    })

def _defines():
    return ["CRASHPAD_FLOCK_ALWAYS_SUPPORTED=1"] + select({
        "//build:linux": ["_FILE_OFFSET_BITS=64"],
        "//conditions:default": [],
    })

def _local_defines():
    return select({
        "//build:windows": _WIN_DEFINES,
        "//conditions:default": [],
    })

def _library_linkopts():
    return select({
        "//build:linux": [
            "-pthread",
            "-ldl",
        ],
        "//build:windows": ["kernel32.lib"],
        "//conditions:default": [],
    })

def _binary_linkopts(shared = False):
    return _library_linkopts() + select({
        "//build:linux": [
            "-Wl,--as-needed",
            "-Wl,-z,noexecstack",
        ] + ([] if shared else ["-pie"]),
        "//build:windows": ["/DEBUG"],
        "//conditions:default": [],
    }) + select({
        "//build:opt_linux": [
            "-Wl,-O1",
            "-Wl,--gc-sections",
        ],
        "//build:opt_macos": ["-Wl,-dead_strip"],
        "//build:opt_windows": [
            "/OPT:ICF",
            "/OPT:REF",
        ],
        "//conditions:default": [],
    })

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
            "-fno-objc-arc-exceptions",
            "-fobjc-call-cxx-cdtors",
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
        linkopts = _binary_linkopts() + linkopts,
        target_compatible_with = ["@platforms//os:macos"],
        **kwargs
    )

def crashpad_cc_library(
        name,
        deps = [],
        defines = [],
        local_defines = [],
        copts = [],
        cxxopts = [],
        linkopts = [],
        conlyopts = [],
        linkstatic = True,
        **kwargs):
    return cc_library(
        name = name,
        deps = ["//:config"] + deps,
        cxxopts = _cxxopts() + cxxopts,
        conlyopts = _conlyopts() + conlyopts,
        defines = _defines() + defines,
        local_defines = _local_defines() + local_defines,
        copts = _copts() + copts,
        linkopts = _library_linkopts() + linkopts,
        linkstatic = linkstatic,
        **kwargs
    )

def crashpad_cc_binary(
        name,
        deps = [],
        cxxopts = [],
        conlyopts = [],
        defines = [],
        local_defines = [],
        copts = [],
        linkopts = [],
        linkstatic = True,
        **kwargs):
    return cc_binary(
        name = name,
        deps = ["//:config"] + deps,
        cxxopts = _cxxopts() + cxxopts,
        conlyopts = _conlyopts() + conlyopts,
        defines = _defines() + defines,
        local_defines = _local_defines() + local_defines,
        copts = _copts() + copts,
        linkopts = _binary_linkopts(shared = kwargs.get("linkshared", False)) + linkopts,
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
        local_defines = [],
        copts = [],
        linkopts = [],
        linkstatic = True,
        size = "small",
        **kwargs):
    return cc_test(
        name = "crashpad_%s" % name,
        deps = ["//:config", "//test:googletest_main"] + deps,
        cxxopts = _cxxopts() + cxxopts,
        conlyopts = _conlyopts() + conlyopts,
        defines = _defines() + defines,
        local_defines = _local_defines() + local_defines,
        copts = _copts() + copts,
        linkopts = _binary_linkopts() + linkopts,
        linkstatic = linkstatic,
        size = size,
        **kwargs
    )
