{
  description = "Zev Multi Dev Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system} = {

      # ========================
      # AI / LLM / Codex 环境
      # ========================
      ai = pkgs.mkShell {
        name = "ai-env";
        packages = with pkgs; [
          python3
          pip
          git
          curl
          wget
          nodejs
          starship
        ];
      };

      # ========================
      # Web 开发环境
      # ========================
      web = pkgs.mkShell {
        name = "web-env";
        packages = with pkgs; [
          nodejs
          pnpm
          git
          curl
          vscode
        ];
      };

      # ========================
      # Python / 数据环境
      # ========================
      python = pkgs.mkShell {
        name = "python-env";
        packages = with pkgs; [
          python3
          python3Packages.pip
          python3Packages.virtualenv
          git
        ];
      };

      # ========================
      # Rust / 系统开发环境
      # ========================
      rust = pkgs.mkShell {
        name = "rust-env";
        packages = with pkgs; [
          rustc
          cargo
          git
        ];
      };

      # ========================
      # CLI 工具环境（通用）
      # ========================
      cli = pkgs.mkShell {
        name = "cli-env";
        packages = with pkgs; [
          git
          curl
          wget
          htop
          starship
          fzf
        ];
      };

    };
  };
}