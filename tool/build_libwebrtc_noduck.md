# Building libwebrtc.dll with audio ducking fix

## The Patch

File: `media/engine/adm_helpers.cc`

Change:
```cpp
#define AUDIO_DEVICE_ID \
  (AudioDeviceModule::WindowsDeviceType::kDefaultCommunicationDevice)
```
To:
```cpp
#define AUDIO_DEVICE_ID \
  (AudioDeviceModule::WindowsDeviceType::kDefaultDevice)
```

This makes WebRTC use the default Console audio device instead of the
Communications device, preventing Windows from ducking other apps.

## Prerequisites

1. **Visual Studio 2022** (Community edition is fine)
2. **Git**
3. **Python 3**
4. ~50 GB free disk space
5. ~4-6 hours for first build

## Build Steps (Windows, PowerShell)

```powershell
# 1. Set environment
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"
$env:GYP_MSVS_VERSION = "2022"
$env:vs2022_install = "C:\Program Files\Microsoft Visual Studio\2022\Community"

# 2. Get depot_tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
$env:PATH = "$PWD\depot_tools;" + $env:PATH

# 3. Create .gclient file
@"
solutions = [
  {
    "name": "src",
    "url": "https://github.com/niclas3332/webrtc.git@m137_release",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
  },
]
target_os = ["win"]
"@ | Out-File -Encoding ascii .gclient

# 4. Sync sources (~30-60 min)
gclient sync --no-history

# 5. Clone libwebrtc wrapper
cd src
git clone https://github.com/niclas3332/libwebrtc.git

# 6. Apply audio patch
git apply libwebrtc/patchs/custom_audio_source_m137.patch

# 7. APPLY OUR DUCKING FIX
# Edit media/engine/adm_helpers.cc:
# Change kDefaultCommunicationDevice → kDefaultDevice
(Get-Content media/engine/adm_helpers.cc) -replace 'kDefaultCommunicationDevice', 'kDefaultDevice' | Set-Content media/engine/adm_helpers.cc

# 8. Add libwebrtc to build
# Edit src/BUILD.gn, add "//libwebrtc" to the default group

# 9. Generate build files
gn gen out/Windows-x64 --args='target_os="win" target_cpu="x64" is_debug=false rtc_include_tests=false rtc_build_tools=false rtc_build_examples=false use_rtti=true is_clang=true treat_warnings_as_errors=false use_custom_libcxx=false'

# 10. Build (~2-4 hours)
ninja -C out/Windows-x64 libwebrtc

# 11. Output: out/Windows-x64/libwebrtc.dll
```

## Installing the patched DLL

Replace the DLL in flutter_webrtc's cache:

```powershell
$cache = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\flutter_webrtc-0.12.12+hotfix.1\third_party\libwebrtc\lib\win64"
Copy-Item out/Windows-x64/libwebrtc.dll "$cache\libwebrtc.dll" -Force
# Also copy to build output
Copy-Item out/Windows-x64/libwebrtc.dll "C:\wikiserver\app\build\windows\x64\runner\Release\libwebrtc.dll" -Force
```

Then rebuild Flutter app: `flutter build windows`

## Verification

1. Open the app, join a voice channel with another person
2. Play music in another app (e.g. YouTube in browser)
3. Music volume should NOT decrease when call connects
