// Standalone test: enumerate all audio sessions for our process and print them.
// Compile: cl /EHsc ducking_debug.cpp ole32.lib
#include <windows.h>
#include <mmdeviceapi.h>
#include <audiopolicy.h>
#include <stdio.h>

int main() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    
    IMMDeviceEnumerator* enumerator = nullptr;
    CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                    CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&enumerator));
    if (!enumerator) { printf("No enumerator\n"); return 1; }
    
    DWORD myPid = GetCurrentProcessId();
    printf("My PID: %lu\n", myPid);
    
    const char* flowNames[] = {"eRender", "eCapture"};
    const char* roleNames[] = {"eConsole", "eCommunications"};
    EDataFlow flows[] = {eRender, eCapture};
    ERole roles[] = {eConsole, eCommunications};
    
    for (int f = 0; f < 2; f++) {
        for (int r = 0; r < 2; r++) {
            IMMDevice* device = nullptr;
            HRESULT hr = enumerator->GetDefaultAudioEndpoint(flows[f], roles[r], &device);
            if (FAILED(hr)) { printf("[%s/%s] No device\n", flowNames[f], roleNames[r]); continue; }
            
            IAudioSessionManager2* mgr = nullptr;
            hr = device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_INPROC_SERVER,
                                  nullptr, reinterpret_cast<void**>(&mgr));
            if (FAILED(hr)) { device->Release(); continue; }
            
            IAudioSessionEnumerator* se = nullptr;
            hr = mgr->GetSessionEnumerator(&se);
            if (FAILED(hr)) { mgr->Release(); device->Release(); continue; }
            
            int count = 0;
            se->GetCount(&count);
            printf("[%s/%s] Sessions: %d\n", flowNames[f], roleNames[r], count);
            
            for (int i = 0; i < count; i++) {
                IAudioSessionControl* ctrl = nullptr;
                if (FAILED(se->GetSession(i, &ctrl))) continue;
                IAudioSessionControl2* ctrl2 = nullptr;
                if (SUCCEEDED(ctrl->QueryInterface(IID_PPV_ARGS(&ctrl2)))) {
                    DWORD pid = 0;
                    ctrl2->GetProcessId(&pid);
                    AudioSessionState state;
                    ctrl->GetState(&state);
                    printf("  [%d] pid=%lu state=%d %s\n", i, pid, state,
                           pid == myPid ? "<-- OURS" : "");
                    ctrl2->Release();
                }
                ctrl->Release();
            }
            se->Release();
            mgr->Release();
            device->Release();
        }
    }
    enumerator->Release();
    CoUninitialize();
    return 0;
}
