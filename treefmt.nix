{ ... }:
{
  projectRootFile = "flake.nix";
  programs.nixpkgs-fmt.enable = true;
  programs.prettier.enable = true;
}
