{
  runCommand,
  # User configurable arguments
  seL4-generate-target-specs,
}:
runCommand "seL4-rust-targets" { nativeBuildInputs = [ seL4-generate-target-specs ]; } ''
  mkdir $out
  sel4-generate-target-specs write --target-dir $out --all
''
