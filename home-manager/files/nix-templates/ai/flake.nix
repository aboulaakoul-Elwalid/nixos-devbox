{
  description = "AI Coding Project Development Environment";

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
            # Python for AI/ML
            python312
            python312Packages.pip
            python312Packages.virtualenv
            
            # Node.js for web/tooling
            nodejs_22
            nodePackages.pnpm
            
            # Rust for performance-critical code
            rustc
            cargo
            
            # Go for CLI tools
            go
            
            # Common tools
            git
            jq
            ripgrep
            fd
            
            # Optional: Database clients
            # postgresql
            # sqlite
          ];

          shellHook = ''
            echo "AI Development Environment loaded"
            echo "  Python: $(python --version)"
            echo "  Node: $(node --version)"
            echo "  Rust: $(rustc --version)"
            echo "  Go: $(go version)"
            
            # Create Python venv if not exists
            if [ ! -d .venv ]; then
              echo "Creating Python venv..."
              python -m venv .venv
            fi
            source .venv/bin/activate
          '';

          # Environment variables
          # ANTHROPIC_API_KEY = ""; # Set via .env.local
        };
      }
    );
}
