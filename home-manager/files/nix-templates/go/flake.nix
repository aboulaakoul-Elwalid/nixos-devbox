{
  description = "Go Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Go
            go
            
            # Go tools
            gopls           # Language server
            golangci-lint   # Linter
            gotools         # goimports, etc.
            delve           # Debugger
            
            # Development tools
            git
          ];

          shellHook = ''
            echo "Go Development Environment"
            echo "  Go: $(go version)"
            
            # Set up local GOPATH
            export GOPATH="$PWD/.go"
            export GOBIN="$GOPATH/bin"
            export PATH="$GOBIN:$PATH"
            mkdir -p "$GOBIN"
          '';
        };
      }
    );
}
