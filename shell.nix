{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    gn
    bazel_9
    bazel-buildtools
    llvmPackages_23.clang-tools
  ];

  buildInputs = [
    pkgs.tzdata
  ];

  shellHook = ''
    unset BAZEL_COPTS BAZEL_CXXOPTS BAZEL_LINKOPTS
  '';
}
