{
  description = "Standalone build of xz";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # xz ships a multicall binary (xz) with symlinks for `unxz`, `xzcat`, `lzma`,
  # `unlzma`, `lzcat` plus a handful of standalone helpers (`xzdec`, `lzmadec`,
  # `lzmainfo`) and shell scripts (`xzdiff`, `xzgrep`, `xzless`, `xzmore` and
  # their aliases). The scripts need a system shell + cmp/grep/sed/less to work,
  # which violates unpins' "single binary" model, and the standalone helpers add
  # little over the multicall — so we ship only `xz` with the multicall aliases
  # embedded as UNPIN_META so unpin's installer can create argv[0]-dispatch
  # links at install time.
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "xz";
      windows = true;
      build = pkgs:
        let
          pruned = pkgs.pkgsStatic.xz.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + "\n" + ''
              for o in $outputs; do
                d="''${!o}"
                [ -d "$d/bin" ] || continue
                find "$d/bin" -mindepth 1 -maxdepth 1 \
                  ! -name 'xz' ! -name 'xz.exe' -delete
              done
            '';
          });
        in
        unpins-lib.lib.withAliases pkgs
          {
            primary = "xz";
            aliases = [ "unxz" "xzcat" "lzma" "unlzma" "lzcat" ];
          }
          pruned;
    };
}
