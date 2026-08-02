# Small standalone-app configs that don't fit an existing module:
#   - satty (the screenshot annotate/save editor omarchy-cmd-screenshot
#     launches): early-exit + save-after-copy make it close itself right
#     after you copy/save instead of staying open waiting to be closed
#     manually -- without this file satty falls back to its (annoying)
#     stay-open default.
#   - swayosd (volume/brightness on-screen-display): config.toml plus a
#     personal style.css override (flat corners, higher opacity, custom
#     font) layered on top of the active omarchy theme's swayosd.css.
{ config, pkgs, lib, ... }:

{
  home.file.".config/satty/config.toml".source = ../files/satty/config.toml;

  home.file.".config/swayosd/config.toml".source = ../files/swayosd/config.toml;
  home.file.".config/swayosd/style.css".source = ../files/swayosd/style.css;
}
