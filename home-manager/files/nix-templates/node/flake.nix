{
  description = "Node.js/TypeScript Development Environment";

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
            # Node.js
            nodejs_22
            
            # Package managers
            nodePackages.pnpm
            nodePackages.yarn
            
            # TypeScript tooling
            nodePackages.typescript
            nodePackages.typescript-language-server
            
            # Development tools
            git
            jq
          ];

          shellHook = ''
            echo "Node.js Development Environment"
            echo "  Node: $(node --version)"
            echo "  pnpm: $(pnpm --version)"
            
            # Install deps if package.json exists
            if [ -f package.json ] && [ ! -d node_modules ]; then
              echo "Installing dependencies..."
              if [ -f pnpm-lock.yaml ]; then
                pnpm install
              elif [ -f yarn.lock ]; then
                yarn install
              else
                npm install
              fi
            fi
          '';
        };
      }
    );
}
