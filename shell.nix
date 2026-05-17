{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    gn
    bazel_8
    bazel-buildtools
    llvmPackages_22.clang-tools
  ];

  buildInputs = [
    pkgs.tzdata
  ];
}
