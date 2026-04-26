@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >/dev/null 2>&1
cd C:\wikiserver\app\tool
cl /EHsc ducking_debug.cpp ole32.lib /Fe:ducking_debug.exe
