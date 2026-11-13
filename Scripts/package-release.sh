#!/usr/bin/env bash
# Builds the universal (arm64 + x86_64) macOS binary and packs it into dist/ as
#   keychest-<version>-macos-universal.tar.gz   (plus a .sha256 file)
# then unpacks that archive and checks what is inside. The Release workflow runs this script;
# run it locally to see exactly what a release would contain:
#
#   Scripts/package-release.sh 1.2.0
#
# An optional second argument is the source tree to build (default: this checkout). The workflow
# uses it to attach a binary to an older tag that has no copy of this script.
set -euo pipefail

VERSION="${1:?usage: Scripts/package-release.sh <version> [source-dir], for example 1.2.0}"
VERSION="${VERSION#v}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$(cd "${2:-$ROOT}" && pwd)"
NAME="keychest-${VERSION}-macos-universal"
DIST="$ROOT/dist"

rm -rf "$DIST"
mkdir -p "$DIST/$NAME"

swift build --package-path "$SOURCE" -c release --arch arm64 --arch x86_64 --product keychest
BUILT="$(swift build --package-path "$SOURCE" -c release --arch arm64 --arch x86_64 --show-bin-path)/keychest"

cp "$BUILT" "$DIST/$NAME/keychest"
# The linker only signs the arm64 slice, so sign the whole file (ad hoc) to give both slices a valid signature.
codesign --force --sign - "$DIST/$NAME/keychest"
cp "$SOURCE/LICENSE" "$SOURCE/README.md" "$DIST/$NAME/"

tar -C "$DIST" -czf "$DIST/$NAME.tar.gz" "$NAME"
(cd "$DIST" && shasum -a 256 "$NAME.tar.gz" > "$NAME.tar.gz.sha256")

# Check what we are about to ship, starting from the archive itself.
CHECK="$(mktemp -d)"
trap 'rm -rf "$CHECK"' EXIT
tar -xzf "$DIST/$NAME.tar.gz" -C "$CHECK"
BIN="$CHECK/$NAME/keychest"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ "$(lipo -archs "$BIN" | tr ' ' '\n' | sort | paste -sd' ' -)" = "arm64 x86_64" ] || fail "binary is not universal (arm64 + x86_64)"
codesign --verify --strict "$BIN" || fail "binary signature is not valid"

# Only macOS system libraries and the Swift runtime that ships with macOS: no Xcode, no Homebrew.
for arch in arm64 x86_64; do
  extra="$(otool -arch "$arch" -L "$BIN" | tail -n +2 | awk '{print $1}' | grep -vE '^(/usr/lib/|/System/Library/)' || true)"
  [ -z "$extra" ] || fail "$arch slice links against non-system libraries: $extra"
done

# The Homebrew formula declares the oldest macOS this runs on. Raising it here must raise it there too.
MINOS="$(vtool -arch arm64 -show-build "$BIN" | awk '/minos/ {print $2}')"
[ "${MINOS%%.*}" -le 12 ] || fail "needs macOS $MINOS; update depends_on macos in the Homebrew formula first"

# Run every slice this machine can run (the x86_64 one needs Rosetta on Apple silicon).
ran=0
for arch in arm64 x86_64; do
  if arch -"$arch" /usr/bin/true 2>/dev/null; then
    reported="$(arch -"$arch" "$BIN" --version)"
    [ "$reported" = "$VERSION" ] || fail "$arch slice reports '$reported', expected '$VERSION'"
    ran=$((ran + 1))
  else
    echo "note: cannot run the $arch slice here, skipping its run check"
  fi
done
[ "$ran" -ge 1 ] || fail "could not run the binary"

# A real generate with the packaged binary, for both languages.
cd "$CHECK"
printf 'backend: env\nplatforms: [swift, kotlin]\nglobal_secrets: [clientID]\n' > .keychest.yml
clientID=smoke-value "$BIN" generate >/dev/null
[ -f KeychestKeys/Sources/KeychestKeys/Secrets.swift ] || fail "Swift output was not generated"
[ -f keychest-keys/src/main/kotlin/keychest/keys/Secrets.kt ] || fail "Kotlin output was not generated"

echo "Packaged $NAME (macOS $MINOS+, $ran slice run check(s) passed):"
ls -lh "$DIST" | awk 'NR > 1 {print "  " $9 "  " $5}'
