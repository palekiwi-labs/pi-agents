{
  description = "Development environment for pi-agents extension";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "pi-agents";
          buildInputs = with pkgs; [
            nodejs_26
            bun
            typescript
            typescript-language-server
            prettier
          ];
        };
      }
    );
}
