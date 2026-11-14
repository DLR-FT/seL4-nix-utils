set unstable
set lists
set shell := ["bash", "-euo", "pipefail", "-c"]

system := "x86_64-linux"
cores := "6"
jobs := "1"
keep_going := "--keep-going"
nix_flags := ["--cores", cores, "--max-jobs", jobs, "--no-link", keep_going]
# nix_flags := ["--no-link", keep_going]

# ANSI colors
c_reset := '\033[0m'
c_bold := '\033[1m'
c_dim := '\033[2m'
c_red := '\033[31m'
c_green := '\033[32m'
c_yellow := '\033[33m'
c_cyan := '\033[36m'

# Target lists (single source of truth)
tools := ".#" + ["capDL-tool", "guardonce", "pyfdt", "concurrencytest", "microkit-sdk"]

toolchains := ".#toolchain-" + ["aarch64-elf", "aarch64-linux", "armv7l-eabihf", "armv7l-linux", "i686-elf", "riscv32-elf", "riscv64-elf", "riscv64-linux", "x86_64-elf"]

kernels := ".#seL4-kernel-" + ["aarch64", "arm-hyp-exynos5", "arm-hyp", "arm-mcs", "arm-imx8mm", "arm", "riscv64-mcs", "riscv64-elf", "x64"]

sim_tests := ".#seL4-test-" + ["armv7l-zynq7000-simulate", "i686-ia32-simulate", "riscv32-spike-simulate", "riscv64-spike-simulate", "x86_64-x86_64-simulate"]

sel4tests := [".#seL4-test-" + ["aarch64-imx8mq-evk", "aarch64-rpi4-1GB", "aarch64-rpi4-2GB", "aarch64-rpi4-4GB", "aarch64-rpi4-8GB", "aarch64-zcu102", "armv7l-rpi3", "armv7l-zynq7000", "i686-ia32", "riscv32-spike", "riscv64-spike", "x86_64-x86_64"], sim_tests]

camkes := ".#seL4-camkes-vm-examples-" + ["aarch64-tx1", "aarch64-tx2", "aarch64-qemu-arm-virt", "aarch64-zcu102", "armv7l-exynos5422"]

firmware := ".#" + ["atf-aarch64-zcu102", "opensbi-riscv64-cva6", "pmufw-mblaze-zcu102", "uboot-aarch64-rpi4", "uboot-aarch64-zcu102", "uboot-armv7l-zynq-zc702", "sd-aarch64-rpi4"]

devshells := ".#devShells." + system + "." + ["default", "microkit"]

all_builds := [tools, toolchains, kernels, sel4tests, camkes, firmware, devshells]

# Show available recipes
default:
    @just --list

# === Checks, Formatting & Manifests ===

# Format Nix files with treefmt
fmt:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🎨 Formatting Nix files...{{ c_reset }}"
    nix fmt

# Run flake checks (formatting, etc.)
check:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🛡️  Running flake check...{{ c_reset }}"
    nix flake check --cores {{ cores }} --max-jobs {{ jobs }} {{ keep_going }}

# Audit upstream seL4 manifests against flake.lock
sync-check:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🔍 Auditing upstream manifests...{{ c_reset }}"
    python3 scripts/sync_manifests.py

# Update flake.nix manifest inputs & nix/manifests.nix from upstream manifests
sync-write:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}✍️  Syncing manifests...{{ c_reset }}"
    python3 scripts/sync_manifests.py --write

# Evaluate .drvPath of all targets without building
eval-all:
    #!/usr/bin/env bash
    set -uo pipefail
    rc=0
    printf "%b\n" "{{ c_bold }}{{ c_cyan }}🧪 Evaluating {{ len(all_builds) }} targets...{{ c_reset }}"
    for target in {{ all_builds }}; do
        if drv=$(nix eval --raw "${target}.drvPath" 2>/dev/null); then
            printf "%b\n" "{{ c_green }}✅{{ c_reset }} $(printf '%-54s' "$target") {{ c_dim }}${drv}{{ c_reset }}"
        else
            printf "%b\n" "{{ c_red }}❌ $target{{ c_reset }}"
            rc=1
        fi
    done
    exit "$rc"

# === Generic Build & Simulation Runners ===

# Build one or more flake packages: just build seL4-kernel-aarch64 seL4-kernel-x64
build +targets:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🔨 Building {{ ".#" + targets }}...{{ c_reset }}"
    nix build {{ nix_flags }} {{ ".#" + targets }}

# Build and run ./simulate for a simulation package
sim target="seL4-test-x86_64-x86_64-simulate":
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🚀 Building & simulating .#{{ target }}...{{ c_reset }}"
    out=$(nix build --cores {{ cores }} --max-jobs {{ jobs }} --no-link --print-out-paths ".#{{ target }}") && \
    "$out/simulate"

# === Tests ===

# Run all QEMU simulation tests (seL4-test + CAmkES VM) via scripts/test_simulate.py
test-simulate *filters:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🧪 Running QEMU simulation tests...{{ c_reset }}"
    python3 scripts/test_simulate.py --verbose --cores {{ cores }} --max-jobs {{ jobs }} {{ filters }}

# Run all checks, manifest audit, and simulation tests (continues past failures)
test-all:
    #!/usr/bin/env bash
    set -uo pipefail
    rc=0
    just cores={{ cores }} jobs={{ jobs }} check || rc=1
    just sync-check || rc=1
    just cores={{ cores }} jobs={{ jobs }} test-simulate || rc=1
    if [ "$rc" -eq 0 ]; then
        printf "%b\n" "{{ c_bold }}{{ c_green }}✨ All tests passed!{{ c_reset }}"
    else
        printf "%b\n" "{{ c_bold }}{{ c_red }}❌ Some tests failed.{{ c_reset }}"
    fi
    exit "$rc"

# === Grouped Builds ===

# Build tools and Python packages
build-tools:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🧰 Building {{ len(tools) }} tools & Python packages...{{ c_reset }}"
    nix build {{ nix_flags }} {{ tools }}

# Build all cross-compilation toolchains
build-toolchains:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}⚙️  Building {{ len(toolchains) }} cross-compilation toolchains...{{ c_reset }}"
    nix build {{ nix_flags }} {{ toolchains }}

# Build all verified seL4 kernels
build-kernels:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🧬 Building {{ len(kernels) }} verified seL4 kernels...{{ c_reset }}"
    nix build {{ nix_flags }} {{ kernels }}

# Build all seL4test variants (non-sim + sim)
build-sel4tests:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🧪 Building {{ len(sel4tests) }} seL4test variants...{{ c_reset }}"
    nix build {{ nix_flags }} {{ sel4tests }}

# Build all CAmkES VM examples
build-camkes:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🖥️  Building {{ len(camkes) }} CAmkES VM examples...{{ c_reset }}"
    nix build {{ nix_flags }} {{ camkes }}

# Build all firmware, U-Boot, and SD card targets
build-firmware:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}💾 Building {{ len(firmware) }} firmware, U-Boot & SD targets...{{ c_reset }}"
    nix build {{ nix_flags }} {{ firmware }}

# Build all devShells
build-devshells:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}🐚 Building {{ len(devshells) }} devShells...{{ c_reset }}"
    nix build {{ nix_flags }} {{ devshells }}

# Build everything in one Nix invocation (continues building independent targets on failure)
# build-all is only useful on high-RAM CI servers where you want Nix to schedule all 50 targets in one giant build graph.
build-all:
    @printf "%b\n" "{{ c_bold }}{{ c_cyan }}📦 Building all {{ len(all_builds) }} targets...{{ c_reset }}"
    nix build {{ nix_flags }} {{ all_builds }}

# Build every target one-by-one and print a final colored OK/FAIL summary
build-summary:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=()
    passed=()
    printf "%b\n" "{{ c_bold }}{{ c_cyan }}📊 Building {{ len(all_builds) }} targets with per-target summary...{{ c_reset }}"
    for target in {{ all_builds }}; do
        printf "%b\n" "{{ c_yellow }}▶ Building ${target}...{{ c_reset }}"
        if nix build {{ nix_flags }} "$target"; then
            passed+=("$target")
            printf "%b\n" "{{ c_green }}✅ OK   ${target}{{ c_reset }}"
        else
            failed+=("$target")
            printf "%b\n" "{{ c_red }}❌ FAIL ${target}{{ c_reset }}"
        fi
    done
    printf "\n%b\n" "{{ c_bold }}{{ c_cyan }}=== Build Summary ==={{ c_reset }}"
    for p in "${passed[@]}"; do printf "%b\n" "  {{ c_green }}✅{{ c_reset }} $p"; done
    for f in "${failed[@]}"; do printf "%b\n" "  {{ c_red }}❌{{ c_reset }} $f"; done
    printf "\n%b\n" "{{ c_bold }}Result:{{ c_reset }} {{ c_green }}${#passed[@]} passed{{ c_reset }}, {{ c_red }}${#failed[@]} failed{{ c_reset }}"
    [ "${#failed[@]}" -eq 0 ]

# Run all tests and all builds (continues past failures)
all:
    #!/usr/bin/env bash
    set -uo pipefail
    rc=0
    just cores={{ cores }} jobs={{ jobs }} test-all || rc=1
    just cores={{ cores }} jobs={{ jobs }} build-summary || rc=1
    if [ "$rc" -eq 0 ]; then
        printf "%b\n" "{{ c_bold }}{{ c_green }}🏁 Everything finished cleanly!{{ c_reset }}"
    else
        printf "%b\n" "{{ c_bold }}{{ c_red }}💥 Finished with failures.{{ c_reset }}"
    fi
    exit "$rc"
