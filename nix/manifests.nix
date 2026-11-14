{ pkgs, inputs }:

{
  sel4testWorkspace = pkgs.mkRepoWorkspace {
    name = "sel4test-workspace";
    projects = [
      {
        path = "kernel";
        src = inputs.seL4-src;
      }
      {
        path = "projects/musllibc";
        src = inputs.musllibc-src;
      }
      {
        path = "projects/seL4_libs";
        src = inputs.seL4-libs-src;
      }
      {
        path = "projects/sel4_projects_libs";
        src = inputs.seL4-projects-libs-src;
      }
      {
        path = "projects/sel4runtime";
        src = inputs.sel4runtime-src;
      }
      {
        path = "projects/sel4test";
        src = inputs.sel4test-src;
      }
      {
        path = "projects/util_libs";
        src = inputs.util-libs-src;
      }
      {
        path = "tools/nanopb";
        src = inputs.nanopb-src;
      }
      {
        path = "tools/opensbi";
        src = inputs.opensbi-sel4test-src;
      }
      {
        path = "tools/seL4";
        src = inputs.seL4-tools-src;
      }
    ];
    linkfiles = [
      {
        src = "tools/seL4/cmake-tool/init-build.sh";
        dest = "init-build.sh";
      }
      {
        src = "tools/seL4/cmake-tool/griddle";
        dest = "griddle";
      }
      {
        src = "projects/sel4test/easy-settings.cmake";
        dest = "easy-settings.cmake";
      }
    ];
  };

  camkesVmExamplesWorkspace = pkgs.mkRepoWorkspace {
    name = "camkes-vm-examples-workspace";
    projects = [
      {
        path = "kernel";
        src = inputs.seL4-src;
      }
      {
        path = "projects/camkes-tool";
        src = inputs.camkes-tool-src;
      }
      {
        path = "projects/camkes-vm-images";
        src = inputs.camkes-vm-images-src;
        symlink = true;
      }
      {
        path = "projects/capdl";
        src = inputs.capdl-src;
      }
      {
        path = "projects/global-components";
        src = inputs.global-components-src;
      }
      {
        path = "projects/libzmq";
        src = inputs.libzmq-src;
      }
      {
        path = "projects/lwip";
        src = inputs.lwip-src;
      }
      {
        path = "projects/musllibc";
        src = inputs.musllibc-src;
      }
      {
        path = "projects/picotcp";
        src = inputs.picotcp-src;
      }
      {
        path = "projects/projects_libs";
        src = inputs.projects-libs-src;
      }
      {
        path = "projects/seL4_libs";
        src = inputs.seL4-libs-src;
      }
      {
        path = "projects/seL4_projects_libs";
        src = inputs.seL4-projects-libs-src;
      }
      {
        path = "projects/sel4runtime";
        src = inputs.sel4runtime-src;
      }
      {
        path = "projects/util_libs";
        src = inputs.util-libs-src;
      }
      {
        path = "projects/vm";
        src = inputs.camkes-vm-src;
      }
      {
        path = "projects/vm-examples";
        src = inputs.camkes-vm-examples-src;
      }
      {
        path = "projects/vm-linux";
        src = inputs.camkes-vm-linux-src;
      }
      {
        path = "tools/polly";
        src = inputs.polly-src;
      }
      {
        path = "tools/seL4";
        src = inputs.seL4-tools-src;
      }
    ];
    linkfiles = [
      {
        src = "projects/camkes-tool/docs/index.md";
        dest = "camkes_README.md";
      }
      {
        src = "projects/vm-examples/easy-settings.cmake";
        dest = "easy-settings.cmake";
      }
      {
        src = "projects/vm/README.md";
        dest = "README.md";
      }
      {
        src = "tools/seL4/cmake-tool/griddle";
        dest = "griddle";
      }
      {
        src = "tools/seL4/cmake-tool/init-build.sh";
        dest = "init-build.sh";
      }
    ];
  };
}
