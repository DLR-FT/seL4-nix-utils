{
  nixpkgs,
  system,
  overlays,
}:

nixpkgs.lib.attrsets.genAttrs
  [
    "aarch64-unknown-linux-gnu"
    "aarch64-unknown-none-elf"
    "armv7l-unknown-linux-gnueabihf"
    "armv7l-unknown-none-eabihf"
    "i686-unknown-none-elf"
    "microblazeel-none-elf"
    "riscv32-unknown-none-elf"
    "riscv64-unknown-linux-gnu"
    "riscv64-unknown-none-elf"
    "x86_64-unknown-none-elf"
  ]
  (
    config:
    import nixpkgs {
      inherit system overlays;
      crossSystem = { inherit config; };
    }
  )
