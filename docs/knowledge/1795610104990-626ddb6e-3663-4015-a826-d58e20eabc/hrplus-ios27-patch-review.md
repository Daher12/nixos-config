---
name: hrplus-ios27-patch-review
description: State of the user's review of Niaktou/hrplus-ios27-patch (iOS 27
  fix for HR+ V007 earbud replicas) — findings so far and the binary
  verification that is still pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_410311bd-fa86-41ce-953b-ce065ffc1da4
---

On 2026-11-25 the user asked for a review of https://github.com/Niaktou/hrplus-ios27-patch (docs/PATCH.md) because they want to flash it to their own HR+ earbuds using the Android APK. Session was in plan mode, so only a document-level review was done; the ExitPlanMode proposal for hands-on verification of the binaries was denied (permission denied), so it is not approved.

Findings established (documents only, binaries not inspected):
- Repo holds only binaries (APK 14,710,578 B, two identical 1,054,473 B `.bin`, zip) plus docs; no source, no license. Published 2026-10-27 in two commits, not updated since.
- Validated on one pair, profile `A5G_BY_G23_M05_ST_007_20260122_L`, iPhone 17 / iOS 27.0, pairing + music only, using an earlier installer build; the published APK was never used to flash.
- Hand decode of the 37-byte block with PairBridge's `probe.py` rules matches the documented rule (command and byte4 checks unchanged, byte5 masked with 0x7F when expected is 0, all rejects to function+0xFC, jump to block end); condition of the skip instruction is inferred.
- Missing: stock/rollback image, failed-transfer recovery, APK source, non-debug signing, permission list.
- Success reports in issues #2/#3 are ports to other profiles (`M03_ST` → NoRiCKaB3/hr-m03-st-ios27-patch, `M03_EQ2` → DDDIABLE/hr-m03-eq2-ios27-patch); all three APKs share package ID `com.hzm.contro.gearphone.hrpatch`.
- Issue #3: FOTA stalls at 0% with RESPONSE TIMEOUT if another multipoint device is connected.

**Why:** the user is deciding whether to flash their own earbuds with this APK.

**How to apply:** if they come back, do not repeat the document review. The user's headphone profile is still unknown (must match the string above, otherwise use the matching port). Next step if they want it: download into a fresh scratch dir, verify SHA-256 against SHA256SUMS.txt, unpack firmware with PairBridge container tooling (clone from GitHub, MIT) and compare with stock from `http://43.138.251.38/upgrade?deviceType=A5G_BY_G23_M05_ST&gray=` (expected `1dea0bbd…`), inspect APK signer/permissions/Guard class. Needs plan mode off.
