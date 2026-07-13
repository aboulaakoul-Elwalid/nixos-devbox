{
  description = "Python Development Environment";

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
            # Python
            python312
            python312Packages.pip
            python312Packages.virtualenv
            
            # Python tooling
            ruff        # Fast linter
            uv          # Fast pip replacement
            
            # Development tools
            git
            jq
          ];

          shellHook = ''
            echo "Python Development Environment"
            echo "  Python: $(python --version)"
            
            # Create venv if not exists
            if [ ! -d .venv ]; then
              echo "Creating Python venv..."
              python -m venv .venv
            fi
            source .venv/bin/activate
            
            # Install deps if requirements.txt exists
            if [ -f requirements.txt ] && [ ! -f .venv/.installed ]; then
              echo "Installing dependencies..."
              pip install -r requirements.txt
              touch .venv/.installed
            fi
          '';
        };
      }
    );
}
