{
  description = "Rust Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        
        # Use stable rust with common components
        rust = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust toolchain
            rust
            
            # Build dependencies
            pkg-config
            openssl
            
            # Development tools
            cargo-watch
            cargo-edit
            
            # Common tools
            git
          ];

          shellHook = ''
            echo "Rust Development Environment"
            echo "  Rust: $(rustc --version)"
            echo "  Cargo: $(cargo --version)"
          '';
          
          # Required for some crates
          RUST_SRC_PATH = "${rust}/lib/rustlib/src/rust/library";
        };
      }
    );
}
