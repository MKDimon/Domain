#!/bin/bash
# Apply domain_audio patches to flutter_webrtc after `flutter pub get`.
# Run from app/ directory: bash patches/apply_patches.sh

set -e

# Find pub cache — works for both regular user and SYSTEM service account
CACHE_DIR=""
for d in "$HOME/AppData/Local/Pub/Cache/hosted/pub.dev" \
         "$LOCALAPPDATA/Pub/Cache/hosted/pub.dev" \
         "$PUB_CACHE/hosted/pub.dev" \
         "$APPDATA/../Local/Pub/Cache/hosted/pub.dev" \
         "C:/Windows/system32/config/systemprofile/AppData/Local/Pub/Cache/hosted/pub.dev" \
         "C:/Windows/SysWOW64/config/systemprofile/AppData/Local/Pub/Cache/hosted/pub.dev"; do
  if ls -d "$d"/flutter_webrtc-1.4.* 2>/dev/null | head -1 | grep -q .; then
    CACHE_DIR="$d"
    break
  fi
done

WEBRTC_DIR=$(ls -d "$CACHE_DIR"/flutter_webrtc-1.4.* 2>/dev/null | head -1)

if [ -z "$WEBRTC_DIR" ]; then
  echo "ERROR: flutter_webrtc-1.4.x not found in pub cache"
  echo "HOME=$HOME"
  echo "LOCALAPPDATA=$LOCALAPPDATA"
  echo "PUB_CACHE=$PUB_CACHE"
  find /c/Windows/system32/config/systemprofile/AppData/Local/Pub -name "flutter_webrtc*" -type d 2>/dev/null | head -3
  exit 1
fi

echo "Patching $WEBRTC_DIR ..."

cp patches/flutter_webrtc.cc "$WEBRTC_DIR/common/cpp/src/flutter_webrtc.cc"
cp patches/flutter_screen_capture.cc "$WEBRTC_DIR/common/cpp/src/flutter_screen_capture.cc"

# Patch libwebrtc.dll: kDefaultCommunicationDevice -> kDefaultDevice (anti-ducking)
LIBWEBRTC="$WEBRTC_DIR/third_party/libwebrtc/lib/win64/libwebrtc.dll"
if [ -f "$LIBWEBRTC" ]; then
  python3 -c "
data = bytearray(open(r'$LIBWEBRTC', 'rb').read())
patched = False
if data[0x730957] == 0xFF:
    data[0x730957] = 0xFE
    patched = True
if data[0x730A97] == 0xFF:
    data[0x730A97] = 0xFE
    patched = True
if patched:
    open(r'$LIBWEBRTC', 'wb').write(data)
    print('  - libwebrtc.dll: patched audio ducking (2 locations)')
else:
    print('  - libwebrtc.dll: already patched')
"
fi

echo "Done. Patched files:"
echo "  - common/cpp/src/flutter_webrtc.cc (PCM gain + noise gate + VAD)"
echo "  - common/cpp/src/flutter_screen_capture.cc (screen share resolution)"
echo "  - libwebrtc.dll (audio ducking fix)"
