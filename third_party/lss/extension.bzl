load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

def _lss_repository(name):
    new_git_repository(
        name = name,
        remote = "https://chromium.googlesource.com/linux-syscall-support",
        commit = "29164a80da4d41134950d76d55199ea33fbb9613",
        build_file_content = """\
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "lss",
    hdrs = ["linux_syscall_support.h"],
    target_compatible_with = ["@platforms//os:linux"],
    include_prefix = "third_party/lss",
    visibility = ["//visibility:public"]
)
""",
    )

def _lss_extension_impl(mctx):
    _lss_repository(name = "lss")
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        return mctx.extension_metadata(
            reproducible = True,
            root_module_direct_deps = ["lss"],
            root_module_direct_dev_deps = [],
        )
    else:
        return None

lss = module_extension(
    implementation = _lss_extension_impl,
)
