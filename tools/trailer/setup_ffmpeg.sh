#!/usr/bin/env bash
# Download a static Windows ffmpeg/ffprobe build into the shared .tools/ffmpeg/ (git-ignored).
#   tools/trailer/setup_ffmpeg.sh
# Build: Gyan Doshi's "essentials" static build of FFmpeg 9.0.2 for Windows x64 (GPLv3, includes
# libx264 and the ebur128/loudnorm filters). The SHA-256 is the one GitHub publishes for the release
# asset. Only .tools/ffmpeg/ is written outside this checkout; the download is staged in .userdata/. Idempotent: does nothing when .tools/ffmpeg/bin/ffmpeg.exe already reports 9.0.2.
source "$(dirname "$0")/../lib/common.sh"
VERSION="9.0.2"
NAME="ffmpeg-$VERSION-essentials_build"
URL="https://github.com/GyanD/codexffmpeg/releases/download/$VERSION/$NAME.zip"
SHA256="60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba"
DEST="$TOOLS_DIR/ffmpeg"

if [ -x "$DEST/bin/ffmpeg.exe" ] && "$DEST/bin/ffmpeg.exe" -hide_banner -version | head -1 | grep -q "version $VERSION"; then
	echo "ffmpeg $VERSION already in .tools/ffmpeg"
	"$DEST/bin/ffmpeg.exe" -hide_banner -version | head -1
	exit 0
fi

tmp="$USERDATA/ffmpeg_download"
rm -rf "$tmp"
mkdir -p "$tmp"
echo "downloading $URL"
curl -fL --retry 3 -o "$(native "$tmp/$NAME.zip")" "$URL"
got="$(sha256sum "$tmp/$NAME.zip" | cut -d' ' -f1)"
if [ "$got" != "$SHA256" ]; then
	echo "checksum mismatch: got $got, want $SHA256" >&2
	rm -rf "$tmp"
	exit 1
fi
echo "sha256 ok"
unzip -q "$tmp/$NAME.zip" -d "$tmp/x"
rm -rf "$DEST"
mkdir -p "$DEST"
cp -r "$tmp/x/$NAME/bin" "$DEST/bin"
cp "$tmp/x/$NAME/LICENSE" "$DEST/LICENSE" 2>/dev/null || true
cp "$tmp/x/$NAME/README.txt" "$DEST/README.txt" 2>/dev/null || true
echo "$SHA256  $NAME.zip" > "$DEST/SHA256.txt"
rm -rf "$tmp"
"$DEST/bin/ffmpeg.exe" -hide_banner -version | head -1
"$DEST/bin/ffprobe.exe" -hide_banner -version | head -1
