{ lib
, runCommand
, writeScript
, writeShellApplication
, cpio
, linuxPackages
, pkgsStatic
, zstd
, kernel ? linuxPackages.kernel.override {
    enableCommonConfig = false; # don't inject nixpkgs specifics
  }
, extraRootfsFiles ? { }
}:

let
  # To tinker with the kernel config, run
  #
  # nix develop .\#linux-aarch64.kernel.configEnv
  menuconfigShell = linuxPackages.kernel.configEnv.overrideAttrs (_: {
    shellHook = ''
      # unpack only if not already present
      if [ ! -d linux-* ]
      then
        unpackPhase
        cd linux-*
        patchPhase
      else
        cd linux-*
      fi
      make menuconfig ARCH=${linuxPackages.kernel.stdenv.hostPlatform.linuxArch}
    '';
  });


  # Attrsets of things to put into the initramfs
  #
  # Example:
  #
  # ```nix
  # "/var/lib/my-file".copy =
  # TODO handle permissions, and username/groups
  rootfsFiles = {
    "/etc/init.d/rcS".copy = writeScript "script" ''
      #!/bin/sh

      mount -t devtmpfs none /dev
      mount -t proc procfs /proc
      mount -t sysfs sysfs /sys/
      mount -t tmpfs none /var/run
      ip link set dev eth0 up
      udhcpc -A 0 -b -R
    '';

    "/".copy = pkgsStatic.busybox.override {
      extraConfig = ''
        CONFIG_UDHCPC_DEFAULT_SCRIPT "/default.script"
      '';
    };

    "/init".target = "/bin/init";
  } // extraRootfsFiles;


  # Function to create a shell script which populates current working dir as specified in
  # `rootfsFiles`
  setupScript =
    let
      inherit (lib.lists) any;
      inherit (lib.attrsets) attrValues hasAttr mapAttrsToList;
      inherit (lib.strings) concatStringsSep escapeShellArg optionalString removePrefix;
    in

    # an operation must __either__ be a copy __or__ a symlink creation, but not both
    assert ! any (x: hasAttr "copy" x && hasAttr "target" x) (attrValues rootfsFiles);

    writeShellApplication {
      name = "setup-rootfs";

      # The ordering is important, first copy files, then create symlinks. Iterating through an
      # attrset has no guaranteed order, hence we have to first do the copying, then in a second
      # pass create the symlinks.
      text = concatStringsSep "\n" (

        # case: copy a dir/file
        (mapAttrsToList
          (path': value:
            let
              path = removePrefix "/" path';
            in
            optionalString (value ? copy) ''
              mkdir --parent -- "$(dirname -- ${escapeShellArg path})"
              cp --recursive --no-clobber --no-target-directory -- \
                ${escapeShellArg value.copy} \
                ${escapeShellArg path}
            ''
          )
          rootfsFiles) ++

        # case: create a symlink
        (mapAttrsToList
          (path': value:
            let
              path = removePrefix "/" path';
            in

            optionalString (value ? target) ''
              mkdir --parent -- "$(dirname -- ${escapeShellArg path})"
              ln --relative --symbolic -- \
                ${escapeShellArg (removePrefix "/" value.target)} \
                ${escapeShellArg path}
            ''
          )
          rootfsFiles)

      );
    };


  # minimal initramfs, containing solely busybox
  initrd = runCommand
    "initrd"
    {
      depsBuildBuild = [ cpio zstd ];
      doCheck = true;
    }
    ''
      # create new root for initrd and cd there
      mkdir --parent -- rootfs
      cd rootfs
      
      mkdir --parent -- \
        dev \
        etc/network/if-{,pre-}{up,down}.d \
        proc \
        sys \
        var/run

      # propagate new root
      ${lib.meta.getExe setupScript}

      # patch out the store references
      sed --in-place --regexp-extended 's|/nix/store/[^/]+/|/|g' \
        default.script

      # verify the new root is free-standing, as in, has no dependencies
      # TODO allow store references if present in rootfs dir
      if grep --recursive -- ${builtins.storeDir} .
      then
        echo "Found references to store which will be unavailable at run-time"
        exit 1
      fi

      # pack it up into an archive
      find . | cpio --create --format='newc' | zstd -19 --check > "$out"
    '';
in
# helper script to run the kernel in qemu for debugging
writeShellApplication
  {
    name = "run-linux-in-qemu";
    runtimeInputs = [ ];
    text = ''
      qemu-system-aarch64 \
        -machine virt \
        -m 64 \
        -cpu cortex-a53 \
        -kernel ${kernel}/Image \
        -initrd ${initrd} \
        -device e1000,netdev=net0 \
        -netdev user,id=net0 \
        -nographic
    '';
  } // { inherit kernel initrd menuconfigShell; }
