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
      lib = unpins-lib.lib;
      # Pages for the shipped commands (`xz` + its 5 multicall aliases). Every
      # target — native, cross-linux, AND windows — runs the same prune below
      # and then embeds its OWN curated man via withMan. No grafted/curated
      # external tree: the windows .exe harvests the pages from its own mingw
      # build (xz ships pre-generated roff in the tarball, installed on every
      # cross), exactly like the cross-linux targets already do.
      manPages = [ "xz" "unxz" "xzcat" "lzma" "unlzma" "lzcat" ];
      manKeepArgs =
        builtins.concatStringsSep " " (map (p: "! -name '${p}.1*'") manPages);

      # Shared postInstall, applied identically on native and windows. Upstream
      # installs 23 man1 pages + the standalone-helper binaries; we ship only
      # `xz` (+ `xz.exe`) and the 5 multicall aliases. Keep just the matching
      # binary and the 6 man pages.
      #
      # Touch only the C-locale `man1/` (the only tree withMan embeds); the
      # translated locale dirs (de/, fr/, …) are left intact so their internal
      # alias→page symlink webs don't dangle. The 5 alias pages we keep are all
      # symlinks to xz.1, which we keep, so man1/ stays self-consistent.
      prunePostInstall = ''
        for o in $outputs; do
          d="''${!o}"
          if [ -d "$d/bin" ]; then
            find "$d/bin" -mindepth 1 -maxdepth 1 \
              ! -name 'xz' ! -name 'xz.exe' -delete
          fi
          if [ -d "$d/share/man/man1" ]; then
            find "$d/share/man/man1" -mindepth 1 -maxdepth 1 \
              ${manKeepArgs} -delete
          fi
        done
      '';
    in
    lib.mkStandaloneFlake {
      inherit self;
      name = "xz";

      # nixpkgs lists [ gpl2Plus lgpl21Plus ], which is stale: since 5.6.0
      # upstream licenses liblzma and the command-line tools under 0BSD. The
      # LGPL getopt_long replacement is only compiled where libc lacks it
      # (musl, mingw-w64, and macOS all provide it) and the GPL bits are
      # build-system files that don't land in the artifact.
      license = "0BSD";
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
            postInstall = (old.postInstall or "") + "\n" + prunePostInstall;
          });
        in
        lib.withAliases pkgs
          {
            primary = "xz";
            aliases = [ "unxz" "xzcat" "lzma" "unlzma" "lzcat" ];
          }
          pruned;
      # Mingw counterpart: same prune (bin + man). The .exe embeds its OWN
      # curated man — the mingw cross installs xz's pre-generated man just like
      # every other target, so withMan harvests it after the prune. No graft.
      windowsBuild = pkgs:
        let
          cross = lib.mingwStaticCross pkgs;
          pruned = cross.xz.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + "\n" + prunePostInstall;
          });
        in
        lib.withAliases pkgs
          {
            primary = "xz.exe";
            aliases = [ "unxz" "xzcat" "lzma" "unlzma" "lzcat" ];
          }
          pruned;
    };
}
