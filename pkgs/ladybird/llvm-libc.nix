# Header-only LLVM libc math functions, packaged like Ladybird's vcpkg overlay port
# (Meta/CMake/vcpkg/overlay-ports/llvm-libc). rev and sha512 are copied from that port by scripts/update.sh.
{
  lib,
  stdenvNoCC,
  fetchurl,
  rev,
  sha512,
}:

stdenvNoCC.mkDerivation {
  pname = "llvm-libc-headers";
  version = "0-unstable-${builtins.substring 0 12 rev}";

  src = fetchurl {
    url = "https://github.com/llvm/llvm-project/archive/${rev}.tar.gz";
    inherit sha512;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # The archive holds all of llvm-project; only libc/ is needed.
    tar xzf "$src" "llvm-project-${rev}/libc"
    cd "llvm-project-${rev}/libc"

    # The headers the math functions include, at their paths under libc/.
    for dir in hdr include shared src/__support src/string/memory_utils; do
      find "$dir" -name '*.h' -exec install -Dm644 {} "$out/include/llvm-libc/{}" \;
    done
    install -Dm644 LICENSE.TXT "$out/share/licenses/llvm-libc/LICENSE.TXT"

    runHook postInstall
  '';

  meta = {
    description = "Header-only math functions of LLVM libc";
    homepage = "https://libc.llvm.org/";
    license = with lib.licenses; [
      asl20
      llvm-exception
    ];
    platforms = lib.platforms.all;
  };
}
