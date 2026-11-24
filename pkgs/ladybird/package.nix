# Derived from nixpkgs pkgs/by-name/la/ladybird/package.nix (MIT).
# Version and hashes live in ./sources.json and are bumped by scripts/update.sh.
{
  lib,
  stdenv,
  fetchFromGitHub,
  pdfjs,
  chromium-hsts-preload-list,
  cmake,
  gitMinimal,
  ninja,
  pkg-config,
  curlFull, # Websocket support
  libavif,
  angle, # libEGL
  brotli,
  cpptrace,
  glib,
  glslang,
  harfbuzz,
  libdrm,
  libGL,
  libjpeg_turbo,
  libpng,
  libpsl,
  libxml2,
  libedit,
  libpulseaudio,
  libwebp,
  mimalloc,
  openssl,
  perl,
  python3,
  qt6Packages,
  woff2,
  wuffs,
  cargo,
  fast-float,
  ffmpeg,
  fontconfig,
  rustPlatform,
  rustc,
  simdutf,
  skia,
  libtommath,
  sdl3,
  icu78,
  simdjson,
  sqlite,
  vulkan-headers,
  vulkan-loader,
  vulkan-memory-allocator,
  zlib,
  zmij,
  dbus,
  callPackage,
}:

let
  sources = lib.importJSON ./sources.json;

  llvm-libc = callPackage ./llvm-libc.nix { inherit (sources.llvmLibc) rev sha512; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ladybird";
  inherit (sources) version;

  src = fetchFromGitHub {
    owner = "LadybirdBrowser";
    repo = "ladybird";
    # Pinned to the commit the release tag pointed to (sources.tag), so a moved tag can't break the hash.
    inherit (sources) rev;
    hash = sources.srcHash;
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = sources.cargoHash;
  };

  postPatch = ''
    sed -i '/iconutil/d' UI/CMakeLists.txt

    # New Rust releases can deprecate APIs used by this snapshot.
    substituteInPlace Meta/CMake/rust_crate.cmake \
      --replace-quiet 'set(RUSTC_TARGET_FLAGS -Dwarnings ' 'set(RUSTC_TARGET_FLAGS '

    # Upstream suffixes its reduced FFmpeg build to coexist with system FFmpeg.
    # Use nixpkgs' FFmpeg, which already provides the additional decoders.
    substituteInPlace Meta/CMake/check_for_dependencies.cmake \
      --replace-quiet libavcodec-ladybird libavcodec \
      --replace-quiet libavutil-ladybird libavutil \
      --replace-quiet libswresample-ladybird libswresample

    perl -0pi -e \
      's/find_package\(ICU 78\.[0-9]+ EXACT REQUIRED COMPONENTS data i18n uc\)/find_package(ICU ${icu78.version} EXACT REQUIRED COMPONENTS data i18n uc)/' \
      Meta/CMake/check_for_dependencies.cmake

    # Install the same PDF viewer assets and integration patch as the vcpkg build.
    cp -r ${pdfjs}/share/pdf.js pdfjs
    chmod -R u+w pdfjs
    patch -d pdfjs -p1 < Meta/CMake/vcpkg/overlay-ports/pdfjs/0001-ladybird-embed.patch
    # Upstream only ships en-US with a minimal locale.json (see the vcpkg portfile).
    echo '{"en-us":"en-US/viewer.ftl"}' > pdfjs/web/locale/locale.json

    # Don't set absolute paths in RPATH
    substituteInPlace Meta/CMake/lagom_install_options.cmake \
      --replace-fail "\''${CMAKE_INSTALL_BINDIR}" "bin" \
      --replace-fail "\''${CMAKE_INSTALL_LIBDIR}" "lib"
  '';

  preConfigure = ''
    # HSTS preload data is the only remaining downloaded data cache.
    mkdir -p build/Caches
    cmakeFlagsArray+=("-DLADYBIRD_CACHE_DIR=$PWD/build/Caches")
    # Picked up by Meta/CMake/FindPDFJS.cmake
    cmakeFlagsArray+=("-DPDFJS_DIR=$PWD/pdfjs")

    mkdir build/Caches/HSTSPreload
    cp ${chromium-hsts-preload-list}/share/chromium-hsts-preload-list/transport_security_state_static.json build/Caches/HSTSPreload
  '';

  nativeBuildInputs = [
    cargo
    cmake
    gitMinimal
    ninja
    perl
    pkg-config
    python3
    rustPlatform.cargoSetupHook
    rustc
    qt6Packages.wrapQtAppsHook
    glslang
  ];

  buildInputs = [
    curlFull
    brotli
    cpptrace
    fast-float
    (ffmpeg.overrideAttrs (prev: {
      # Ladybird's code uses its own FFmpeg patches (e.g. AV_HWACCEL_FLAG_LADYBIRD_*), shipped in its
      # vcpkg overlay port as 01xx-*.patch. Apply them from the release source so new or changed
      # patches are picked up automatically. 0100 only renames symbol versions for the "-ladybird"
      # library suffix, which this package doesn't use, so it's skipped.
      postPatch = (prev.postPatch or "") + ''
        for p in ${finalAttrs.src}/Meta/CMake/vcpkg/overlay-ports/ffmpeg/01*.patch; do
          [ -e "$p" ] || continue
          case "$(basename "$p")" in 0100-*) continue ;; esac
          echo "applying Ladybird FFmpeg patch $(basename "$p")"
          patch -p1 < "$p"
        done
      '';
    }))
    fontconfig
    harfbuzz
    libavif
    angle # libEGL
    libGL
    libjpeg_turbo
    libpng
    libpsl
    libtommath
    libxml2
    libedit
    libwebp
    (mimalloc.overrideAttrs {
      # Ladybird uses heap APIs removed in mimalloc 3.
      version = "2.2.7";
      src = fetchFromGitHub {
        owner = "microsoft";
        repo = "mimalloc";
        tag = "v2.2.7";
        hash = "sha256-z9qMOTcGkURblZChXDGfQ58hrql52lG6EE1NQmxxuj0=";
      };
    })
    openssl
    qt6Packages.qtbase
    sdl3
    simdutf
    (skia.overrideAttrs (prev: {
      # Ladybird also uses Skia's color management API directly.
      gnFlags = prev.gnFlags ++ [
        "extra_cflags+=[\"-DSKCMS_DLL\"]"
      ];
    }))
    wuffs
    woff2
    icu78
    simdjson
    sqlite
    zlib
    zmij
    llvm-libc
    dbus
    libpulseaudio.dev
    glib
    libdrm
    qt6Packages.qtpositioning
    qt6Packages.qtwayland
    vulkan-headers
    vulkan-loader
    vulkan-memory-allocator
  ];

  cmakeFlags = [
    # Takes an enormous amount of resources, even with mold
    (lib.cmakeBool "ENABLE_LTO_FOR_RELEASE" false)
    # Disable network operations
    "-DENABLE_NETWORK_DOWNLOADS=OFF"
    # Ladybird requires icu 78, but without this flag the default icu
    # from other dependencies gets picked up instead.
    (lib.cmakeFeature "ICU_ROOT" (toString icu78.dev))
    # Upstream defaults to -Ctarget-cpu=native for Rust; target a portable baseline.
    # (Older name kept for snapshots that predate the rename.) Without this, CI-built binaries
    # would use the runner's CPU features and could SIGILL on users' machines.
    (lib.cmakeBool "LADYBIRD_BASELINE_CPU_TARGET" true)
    (lib.cmakeBool "ENABLE_CI_BASELINE_CPU" true)
    "-DCMAKE_INSTALL_LIBEXECDIR=libexec"
    (lib.cmakeFeature "LLVM_LIBC_INCLUDE_DIR" "${llvm-libc}/include")
  ];

  # https://github.com/LadybirdBrowser/ladybird/issues/371#issuecomment-2616415434
  env.NIX_LDFLAGS = "-lGL -lfontconfig";

  passthru = { inherit sources llvm-libc; };

  meta = {
    description = "Browser using the SerenityOS LibWeb engine with a Qt GUI (alpha releases)";
    changelog = "https://github.com/LadybirdBrowser/ladybird/releases/tag/${sources.tag}";
    homepage = "https://ladybird.org";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "Ladybird";
  };
})
