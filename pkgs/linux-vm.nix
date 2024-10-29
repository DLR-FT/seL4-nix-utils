{ lib
, runCommand
, writeScript
, writeShellApplication
, cpio
, linuxPackages
, pkgsStatic
, zstd
, kernel ? linuxPackages.kernel.override {
    enableCommonConfig = false; # don't inject nixpkgs' specific kernel settings
  }

  # Example:
  #
  # ```nix
  # "/bin/cool-script".copy = writeScript "my-script" ''echo "Excellent!"'';
  # "/" = [
  #   pkgsStatic.busybox
  #   pkgsStatic.hello
  # ];
  # ```
, extraRootfsFiles ? { }

  # If true, copy over the Nix store closure for the extraRootfsFiles.
  # If false, fail the build if any `/nix/store` paths are discovered.
, propagateNixStore ? false
}:

let
  # To tinker with the kernel config, run
  #
  # nix develop .\#linux-aarch64.kernel.configEnv
  menuconfigShell =
    # otherwise the menuconfigShell might spit out incompatible .config files
    assert linuxPackages.kernel.version == kernel.version;

    linuxPackages.kernel.configEnv.overrideAttrs (old: {
      shellHook = ''
        # unpack only if not already present
        if [ ! -d linux-${old.version} ]
        then
          unpackPhase
          cd linux-${old.version}
          patchPhase
        else
          cd linux-${old.version}
        fi
        make menuconfig ARCH=${linuxPackages.kernel.stdenv.hostPlatform.linuxArch}
      '';
    });


  # Attrsets of things to put into the initramfs
  # TODO handle permissions, and username/groups
  rootfsFiles = {
    "/etc/init.d/rcS".copy = writeScript "script" ''
      #!/bin/sh

      mkdir -p -- /dev /proc /sys /tmp
      mount -t devtmpfs none /dev
      mount -t proc procfs /proc
      mount -t sysfs sysfs /sys/
      mount -t cgroup2 none /sys/fs/cgroup
      mount -t tmpfs none /tmp

      ip link set dev eth0 up
      udhcpc -A 0 -b -R
    '';

    "/".copy = (pkgsStatic.busybox.overrideAttrs (old: {
      # patch out the store references
      postFixup = ''
        sed --in-place --regexp-extended 's|/nix/store/[^/]+/|/|g' \
          $out/default.script
      '';
    })).override {
      extraConfig = ''
        CONFIG_UDHCPC_DEFAULT_SCRIPT "/default.script"
      '';
    };
    "/init".copy = writeScript "init" ''
      #!/bin/sh

      # mount new root as tmpfs
      mkdir /.newroot
      mount -t tmpfs none /.newroot
      cd /.newroot

      # move all files to new root
      cp /init .
      mv --no-clobber --target-directory=/.newroot /.* /*

      exec bin/switch_root . "/bin/init" "$@"
    '';
  } // extraRootfsFiles;


  # Function to create a shell script which populates current working dir as specified in
  # `rootfsFiles`
  setupScript =
    let
      inherit (lib.lists) any toList;
      inherit (lib.attrsets) attrValues hasAttr mapAttrsToList;
      inherit (lib.strings) concatMapStringsSep concatStringsSep escapeShellArg optionalString removePrefix;

      escapeRelativePath = path: escapeShellArg ("./" + (lib.strings.removePrefix "/" path));
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
          (path: value:
            optionalString (value ? copy) ''
              mkdir --parent -- "$(dirname -- ${escapeRelativePath path})"
              ${concatMapStringsSep "\n" (source: ''
                echo "Copying over ${escapeShellArg source} to ${escapeRelativePath path}"
                cp --recursive --no-clobber --no-target-directory -- \
                  ${escapeShellArg source} \
                  ${escapeRelativePath path}
                find ${escapeRelativePath path} -type d -exec chmod -- u+w {} \;
              '') (toList value.copy)
              }
            ''
          )
          rootfsFiles) ++

        # case: create a symlink
        (mapAttrsToList
          (path: value:
            optionalString (value ? target) ''
              mkdir --parent -- "$(dirname -- ${escapeRelativePath path})"
              echo "Linking ${escapeRelativePath value.target} to ${escapeRelativePath path}"
              ln --relative --symbolic -- \
                ${escapeRelativePath value.target} \
                ${escapeRelativePath path}
            ''
          )
          rootfsFiles)

      );
    };


  # minimal initramfs, containing solely busybox
  initrd = runCommand
    "initrd.cpio.zst"
    {
      depsBuildBuild = [ cpio setupScript zstd ];
      doCheck = true;
    }
    ''
      # create new root for initrd and cd there
      mkdir --parent -- rootfs
      cd rootfs

      echo "Propagate rootfs"
      ${lib.meta.getExe setupScript}

      ${
        if propagateNixStore then ''
          echo "Propagating Nix store"
          mkdir --parent -- ${lib.strings.removePrefix "/" builtins.storeDir}
          grep --extended-regexp --null-data --recursive --only-matching --no-filename \
            -- ${lib.strings.escapeShellArg "${builtins.storeDir}/[^/]+"} . \
            | while IFS= read -r -d $'\0' storePath ; do
            relativeStorePath="''${storePath#/}"
            [ -d "$relativeStorePath" ] && continue

            echo "Copying $storePath"
            cp --recursive --no-clobber -- "$storePath" "$relativeStorePath"
          done
        '' else ''
          echo "Verifying the new initramfs is free-standing, as in, has no dependencies to the Nix store"
          if grep --recursive -- ${builtins.storeDir} .
          then
            echo "Found references to store which will be unavailable at run-time"
            exit 1
          fi
        ''
      }

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
        -m 256 \
        -cpu cortex-a53 \
        -kernel ${kernel}/Image \
        -initrd ${initrd} \
        -device e1000,netdev=net0 \
        -netdev user,id=net0 \
        -nographic
    '';
  } // { inherit kernel initrd menuconfigShell; }
