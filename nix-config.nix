{
  inputs,
  ...
}:
let
  base = "/etc/nixpkgs/channels";
  nixpkgsPath = "${base}/nixpkgs";
in
{
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    optimise.automatic = true;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${nixpkgsPath}" ];
  };
  systemd.tmpfiles.rules = [
   "L+ ${nixpkgsPath} - - - - ${inputs.nixpkgs}"
  ];
}
