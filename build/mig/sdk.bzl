def _mig_macos_sdk_impl(rctx):
    if rctx.os.name != "mac os x":
        rctx.file("BUILD.bazel", "# Stub: macOS SDK not available.\n")
        return

    result = rctx.execute([
        "xcrun",
        "--sdk",
        "macosx",
        "--show-sdk-path",
    ])

    if result.return_code != 0:
        fail("Failed to locate macOS SDK: %s" % result.stderr)

    sdk_path = result.stdout.strip()
    rctx.symlink(sdk_path + "/usr/include/mach", "usr/include/mach")

    rctx.file("BUILD.bazel", """
filegroup(
    name = "mach_defs",
    srcs = [
        "usr/include/mach/exc.defs",
        "usr/include/mach/mach_exc.defs",
        "usr/include/mach/notify.defs",
    ],
    visibility = ["//visibility:public"],
)

exports_files(glob(["usr/include/mach/*.defs"]))
""")

mig_macos_sdk = repository_rule(
    implementation = _mig_macos_sdk_impl,
    local = True,
    doc = "Locates the macOS SDK and exposes Mach .defs files.",
)
