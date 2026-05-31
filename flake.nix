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
    let
      # Windows man is grafted from nixpkgs (the mingw cross can't run
      # help2man), and `name = "xz"` resolves the graft to nixpkgs' xz.man
      # — which carries all 23 upstream man1 pages. We ship only `xz` + its
      # 5 aliases, so build a curated 6-page tree and pin it via winManRoot
      # (the native side curates its own $out/share/man in postInstall).
      pkgsX = unpins-lib.inputs.nixpkgs.legacyPackages.x86_64-linux;
      winMan = pkgsX.runCommand "xz-win-man" { } ''
        mkdir -p "$out/share/man/man1"
        for p in xz unxz xzcat lzma unlzma lzcat; do
          zcat ${pkgsX.xz.man}/share/man/man1/$p.1.gz > "$out/share/man/man1/$p.1"
        done
      '';
    in
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "xz";
      winManRoot = winMan;
      build = pkgs:
        let
          pruned = pkgs.pkgsStatic.xz.overrideAttrs (old: {
            # On darwin, pkgsStatic still leaves libtool building a shared
            # liblzma — configure reports "build shared libraries: yes"
            # despite `--disable-shared` (Apple has no static libSystem, so
            # the static adapter can't fully suppress shared). The CLI then
            # links liblzma.5.dylib and fails action-build's portability
            # check. Force libtool to emit only the static archive so
            # liblzma folds into the binary (libSystem stays the sole
            # dynamic dep). Linux/musl already links static, so gate on
            # darwin to leave that build untouched.
            postConfigure = (old.postConfigure or "")
              + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
                sed -i 's/^build_libtool_libs=yes$/build_libtool_libs=no/' libtool
              '';
            postInstall = (old.postInstall or "") + "\n" + ''
              for o in $outputs; do
                d="''${!o}"
                if [ -d "$d/bin" ]; then
                  find "$d/bin" -mindepth 1 -maxdepth 1 \
                    ! -name 'xz' ! -name 'xz.exe' -delete
                fi
                # Curate man pages to the shipped commands only. Upstream
                # installs 23 man1 pages; we ship `xz` + the 5 multicall
                # aliases, so drop the pages for the standalone helpers
                # (xzdec/lzmadec/lzmainfo) and the shell scripts
                # (xzdiff/xzgrep/xzless/xzmore + lz* variants) we don't
                # carry — otherwise withMan embeds all 23. Touch only the
                # C-locale `man1/` (the only tree withMan embeds); the
                # translated locale dirs (de/, fr/, …) are left intact so
                # their internal alias→page symlink webs don't dangle. The
                # 5 alias pages we keep are all symlinks to xz.1, which we
                # keep, so man1/ stays self-consistent.
                if [ -d "$d/share/man/man1" ]; then
                  find "$d/share/man/man1" -mindepth 1 -maxdepth 1 \
                    ! -name 'xz.1*'   ! -name 'unxz.1*'  ! -name 'xzcat.1*' \
                    ! -name 'lzma.1*' ! -name 'unlzma.1*' ! -name 'lzcat.1*' \
                    -delete
                fi
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
      # Mingw counterpart: same pruning, `xz.exe` as the embed target.
      windowsBuild = pkgs:
        let
          cross = unpins-lib.lib.mingwStaticCross pkgs;
          # No man curation here: the Windows binary's embedded man comes
          # from `winManRoot` (the mingw cross can't run help2man), not from
          # this cross build's own share/man — so we only need to prune bin/.
          pruned = cross.xz.overrideAttrs (old: {
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
            primary = "xz.exe";
            aliases = [ "unxz" "xzcat" "lzma" "unlzma" "lzcat" ];
          }
          pruned;
    };
}
