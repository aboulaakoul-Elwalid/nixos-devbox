# .zshrc expects ZSH_THEME="powerlevel10k/powerlevel10k" loaded via
# oh-my-zsh -- neither was ever installed, so the fancy p10k prompt was
# silently falling back to a bare zsh prompt (the guarded `if [[ -f
# "$ZSH/oh-my-zsh.sh" ]]` in .zshrc just no-ops when it's missing, no error,
# easy to miss). Both are real nixpkgs packages, no need to hand-manage a
# git clone of either.
{ config, pkgs, lib, ... }:

{
  home.file.".oh-my-zsh" = {
    source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
    recursive = true;
  };
  home.file.".oh-my-zsh/custom/themes/powerlevel10k".source =
    "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
}
