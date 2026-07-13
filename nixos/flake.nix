# NOTE ON LAYOUT: this flake lives in nixos/, but ../home-manager/home.nix
# (a sibling directory at the repo root) is imported below. That relative
# path resolves correctly as long as this whole cloned repo stays a single
# git checkout (flakes use the containing git repo's root as their source
# tree, not just this directory) -- don't split nixos/ and home-manager/
# into separate repos/checkouts without adjusting this path.
{
 inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  omanix.url = "github:T00fy/omanix/main";
 };
 outputs = { nixpkgs, home-manager, omanix, ...}: {
	nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
		system = "x86_64-linux";
		modules = [
			./configuration.nix
			./hardware-configuration.nix
			omanix.nixosModules.default
			home-manager.nixosModules.home-manager
			({ ... }: {
				# CHANGE THIS: "elwalid" here must match the username in
				# users.users.<name> in ./configuration.nix and
				# home.username in ../home-manager/home.nix.
				home-manager.useGlobalPkgs = true;
				home-manager.useUserPackages = true;
				home-manager.users.elwalid = import ../home-manager/home.nix;
			})
			];
		};
	};
}
