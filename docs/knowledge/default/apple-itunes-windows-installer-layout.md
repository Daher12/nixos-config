---
name: apple-itunes-windows-installer-layout
description: Apple's 2026 iTunes for Windows bundle layout — only 2 MSIs (AAS
  merged into iTunes64.msi, no Bonjour), /extract + 7z behavior, silent-install
  properties, MSI COM table inspection
metadata:
  node_type: memory
  type: reference
  originSessionId: sess_9eb77f92-f8d6-4129-8336-d63e43f98ae8
---

Apple's Windows iTunes installer layout changed; facts verified 2026-10-01 against the official `140-75773-20260908` bundle:

- Download: `https://www.apple.com/itunes/download/win64` 301-redirects to `https://secure-appldnld.apple.com/itunes12/140-75773-20260908-<hash>/iTunes64Setup.exe` (202,759,648 bytes; Authenticode Valid, CN=Apple Inc.). Resolve the current URL with `curl -sI -L` from the host — the page itself doesn't expose it.
- **The exe contains exactly 3 payloads** (7-Zip full extraction): `iTunes64.msi` (12.13.11.1), `AppleMobileDeviceSupport64.msi` (20.0.0.35), `SetupAdmin.exe`. **No AppleApplicationSupport*.msi, no Bonjour64.msi** — the classic "install AAS64→AAS32→AMDS64→Bonjour64→iTunes64" guides are obsolete.
- `iTunes64Setup.exe /extract <dir>` runs silently (exit 0, no GUI) but emits only the 2 MSIs; 7-Zip gives the same 2 — nothing is hidden.
- iTunes 12.13 **merges the Apple Application Support runtime into `C:\Program Files\iTunes`**: CoreFoundation.dll, ASL.dll, objc.dll, libdispatch.dll, AppleVersions.dll, mDNSResponderDLL.dll are in iTunes64.msi's File table with no `Apple Application Support` Directory rows. A missing `Common Files\Apple\Apple Application Support` dir is NORMAL now, not damage.
- AMDS 20.0.0.35 ships **no `AppleMobileDeviceProcess.exe`** (helpers: `AppleMobileDeviceHelper.exe`, `distnoted.exe`) and by design installs BOTH the 64-bit and 32-bit `Mobile Device Support` trees (Program Files and Program Files (x86)). ProductCode `{A1147B7D-734A-49BD-A6CA-E41E2B4B7B8F}` stable across reinstalls.
- Bonjour service is NOT in the bundle (only the mDNS client DLL inside iTunes); official `Bonjour64.msi` source = the iCloud for Windows installer.
- Silent install: `msiexec /i iTunes64.msi AUTORUN=0 /qn /norestart /l*v <log>` — `AUTORUN=0` suppresses the Launch_iTunes custom action. Oddity: ARP registers iTunes under GUID `{F7F4BCB2-0D0F-46DA-9896-303008DC6DBA}` even though the MSI's internal ProductCode is `{2A63AD0D-9135-4B2D-8095-296BBE33F93E}` (Apple rewrites the key; harmless).
- To inspect MSI internals without installing: `New-Object -ComObject WindowsInstaller.Installer` → `OpenDatabase(path,0)` → `OpenView('SELECT ... FROM Property|Directory|File|CustomAction')` + Fetch via InvokeMember — this is how the merged-AAS and no-helper findings were proven.

Related: [[win11-vm-troubleshooting]], [[win11-vm-access]].
