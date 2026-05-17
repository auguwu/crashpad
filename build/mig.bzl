# build/mig/mig.bzl

load("@rules_cc//cc:defs.bzl", "cc_library")

def _mig_gen_impl(ctx):
    if not ctx.files.srcs:
        return [
            DefaultInfo(files = depset()),
        ]

    mig_script = ctx.file._mig_tool
    support_files = ctx.files._mig_support
    outputs = []

    for src in ctx.files.srcs:
        basename = src.basename.replace(".defs", "")

        user_c = ctx.actions.declare_file("mach/%sUser.c" % basename)
        server_c = ctx.actions.declare_file("mach/%sServer.c" % basename)
        hdr = ctx.actions.declare_file("mach/%s.h" % basename)
        server_h = ctx.actions.declare_file("mach/%sServer.h" % basename)

        outs = [user_c, server_c, hdr, server_h]
        outputs.extend(outs)

        args = ctx.actions.args()
        args.add(mig_script.path)
        args.add(src.path)

        if ctx.attr.sdk_path:
            args.add("--sdk", ctx.attr.sdk_path)

        args.add("--arch", ctx.attr.arch)

        for out in outs:
            args.add(out.path)

        args.add("--")

        for inc in ctx.attr.includes:
            args.add("-I%s" % inc)

        for define in ctx.attr.defines:
            args.add("-D%s" % define)

        ctx.actions.run(
            executable = "python3",
            arguments = [args],
            inputs = [src, mig_script] + support_files,
            outputs = outs,
            mnemonic = "MachMIG",
            progress_message = "MIG: Generating %s" % basename,
            use_default_shell_env = True,
        )

    return [
        DefaultInfo(files = depset(outputs)),
        OutputGroupInfo(
            sources = depset([f for f in outputs if f.extension == "c"]),
            headers = depset([f for f in outputs if f.extension == "h"]),
        ),
    ]

_mig_gen = rule(
    implementation = _mig_gen_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".defs"],
            mandatory = True,
            doc = "Mach .defs files to process",
        ),
        "arch": attr.string(
            default = "arm64",
            values = ["arm64", "x86_64"],
            doc = "Target architecture for MIG output",
        ),
        "sdk_path": attr.string(
            default = "",
            doc = "Path to macOS SDK sysroot",
        ),
        "includes": attr.string_list(
            default = [],
            doc = "Include paths passed after -- to mig.py",
        ),
        "defines": attr.string_list(
            default = [],
            doc = "Preprocessor defines passed after -- to mig.py",
        ),
        "_mig_tool": attr.label(
            default = "//util:mach/mig.py",
            allow_single_file = True,
            doc = "The mig.py wrapper script",
        ),
        "_mig_support": attr.label_list(
            default = [
                "//util:mach/mig_fix.py",
                "//util:mach/mig_gen.py",
            ],
            allow_files = True,
            doc = "Support scripts needed by mig.py",
        ),
    },
    doc = "Runs the Crashpad MIG wrapper to generate Mach IPC stubs.",
)

def mig_library(
        name,
        srcs,
        sdk_path = "",
        includes = [],
        defines = [],
        deps = [],
        copts = [],
        target_compatible_with = None,
        visibility = None):
    """Generates Mach MIG stubs and wraps them in a cc_library.

    Args:
        name: Target name for the resulting cc_library.
        srcs: List of .defs files (can be a select()).
        sdk_path: macOS SDK sysroot path.
        includes: Include paths for the MIG preprocessor.
        defines: Preprocessor defines for MIG.
        deps: Additional cc_library deps.
        copts: Additional compiler flags for the generated C sources.
        target_compatible_with: Platform compatibility.
        visibility: Bazel visibility.
    """

    if target_compatible_with == None:
        target_compatible_with = ["@platforms//os:macos"]

    gen_name = name + "_gen"

    _mig_gen(
        name = gen_name,
        srcs = srcs,
        arch = select({
            "//build:aarch64": "arm64",
            "//build:x86_64": "x86_64",
        }),
        sdk_path = sdk_path,
        includes = includes,
        defines = defines,
        target_compatible_with = target_compatible_with,
    )

    cc_library(
        name = name,
        srcs = [":" + gen_name],
        hdrs = [":" + gen_name],
        copts = ["-Wno-unreachable-code"] + copts,
        deps = deps,
        target_compatible_with = target_compatible_with,
        visibility = visibility,
    )
