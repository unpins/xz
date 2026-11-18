{
  description = "xz as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # xz ships a multicall binary (xz) with symlinks for `unxz`, `xzcat`, `lzma`,
  # `unlzma`, `lzcat`, three standalone helpers (`xzdec`, `lzmadec`,
  # `lzmainfo`) and shell scripts (`xzdiff`, `xzgrep`, `xzless`, `xzmore` and
  # their aliases). The helpers fold into the multicall; the scripts are left
  # out, since they need a system shell plus cmp/grep/sed/less.
  outputs = { self, unpins-lib }:
    let
      lib = unpins-lib.lib;
      # Pages for the shipped commands (`xz`, its 5 aliases, the 3 helpers). Every
      # target — native, cross-linux, AND windows — runs the same prune below
      # and then embeds its OWN curated man via withMan. No grafted/curated
      # external tree: the windows .exe harvests the pages from its own mingw
      # build (xz ships pre-generated roff in the tarball, installed on every
      # cross), exactly like the cross-linux targets already do.
      manPages = [ "xz" "unxz" "xzcat" "lzma" "unlzma" "lzcat" "xzdec" "lzmadec" "lzmainfo" ];
      manKeepArgs =
        builtins.concatStringsSep " " (map (p: "! -name '${p}.1*'") manPages);
      binKeepArgs = builtins.concatStringsSep " "
        (map (p: "! -name '${p}' ! -name '${p}.exe'") [ "xz" "xzdec" "lzmadec" "lzmainfo" ]);

      # Shared postInstall, applied identically on native and windows. Upstream
      # installs 23 man1 pages and the script wrappers; keep the four programs
      # (+ `.exe`) and the 9 pages of the shipped commands.
      #
      # Touch only the C-locale `man1/` (the only tree withMan embeds); the
      # translated locale dirs (de/, fr/, …) are left intact so their internal
      # alias→page symlink webs don't dangle. The kept alias pages link to xz.1
      # and xzdec.1, which we keep, so man1/ stays self-consistent.
      prunePostInstall = ''
        for o in $outputs; do
          d="''${!o}"
          if [ -d "$d/bin" ]; then
            find "$d/bin" -mindepth 1 -maxdepth 1 \
              ${binKeepArgs} -delete
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
      smoke = [ "--version" ];
      smokePattern = "^xz \\(XZ Utils\\) [0-9]+\\.[0-9]+";

      # Build via the unpin-llvm engine + emit a bitcode multicall module.
      engine = "unpin-llvm";
      multicall = {
        # The `.exe` on the engine too, not the nixpkgs mingw-gcc cross.
        windows = true;
        programs = [
          { name = "xz"; aliases = [ "unxz" "xzcat" "lzma" "unlzma" "lzcat" ]; }
          { name = "xzdec"; }
          { name = "lzmadec"; }
          { name = "lzmainfo"; }
        ];
        # All four link liblzma; fold it once. Per program it would be four
        # private copies, and the i686 CRC assembly then finds no
        # `lzma_crc32_table` to bind to.
        foldSharedArchives = true;
        # xz is NLS-enabled and bakes its own $out/share/locale as the gettext
        # domain directory. The standalone ships bin/ only, so that path is
        # dead -- but Nix counted it as a runtime reference and dragged the base
        # build, and through its compiler wrapper the toolchain, behind a
        # self-contained binary. Scrubbing changes nothing at run time (gettext
        # already fell through to the untranslated strings) and leaves NLS
        # compiled in.
        removeReferences = [ "xz-static" "xz-x86_64-w64-mingw32" ];
      };

      # nixpkgs lists [ gpl2Plus lgpl21Plus ], which is stale: since 5.6.0
      # upstream licenses liblzma and the command-line tools under 0BSD. The
      # LGPL getopt_long replacement is only compiled where libc lacks it
      # (musl, mingw-w64, and macOS all provide it) and the GPL bits are
      # build-system files that don't land in the artifact.
      license = "0BSD";
      build = pkgs:
        let
          base = pkgs.pkgsStatic.xz;
          pruned = base.overrideAttrs (old: {
            # Restates the nixpkgs default; skipped on crosses the build host
            # can't execute.
            doCheck = base.stdenv.buildPlatform.canExecute base.stdenv.hostPlatform;
            # On darwin nix-lib's filterEnableStaticOnDarwin drops
            # `--disable-shared` from configureFlags, so libtool builds
            # liblzma.5.dylib and the CLI links it, failing action-build's
            # portability check. Have libtool emit only the static archive.
            postConfigure = (old.postConfigure or "")
              + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
                sed -i 's/^build_libtool_libs=yes$/build_libtool_libs=no/' libtool
              '';
            postInstall = (old.postInstall or "") + "\n" + prunePostInstall;
          });
        in
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
        pruned;
    };
}
