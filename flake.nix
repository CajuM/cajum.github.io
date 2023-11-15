{
  inputs.nixpkgs.url = "nixpkgs";
  inputs.utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, utils }:
    (utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        devShell = (pkgs.buildFHSUserEnv {
          name = "blog";
          targetPkgs = ps: with ps; [
	    zola
          ];
        }).env;
      }));
}
