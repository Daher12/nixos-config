# Config Optimization Summary

## 1. DRY: Move `networking.hosts` to `nas.nix` module

**Problem**: Both `hosts/yoga/default.nix` and `hosts/latitude/default.nix` duplicated the same host entry:
```nix
networking.hosts = {
  "100.123.189.29" = [ "nix-media" ];
};
```

**Fix**: Moved it into `modules/features/nas.nix` using the module's `serverIp` option (`${cfg.serverIp}`), making it dynamic and DRY. Any host enabling `features.nas.enable` automatically gets the host entry.

**Files changed**:
- `modules/features/nas.nix` — Added `networking.hosts` inside `lib.mkIf cfg.enable`
- `hosts/yoga/default.nix` — Removed hardcoded hosts block
- `hosts/latitude/default.nix` — Removed hardcoded hosts block

---

## 2. tmpfs/ZRAM Balance on Yoga (32GB RAM)

**Problem**: `core.boot.tmpfs.size = "80%"` claimed up to 25.6GB for `/tmp`, and the laptop profile's zram default of 80% claimed up to 25.6GB for compressed swap. Together they could contend for the same physical RAM under pressure.

**Fix**:
- **tmpfs**: Reduced from `"80%"` (25.6G) to `"4G"` — `/tmp` doesn't need 25G on a laptop. 4G is more than sufficient for temporary files, build artifacts, etc.
- **zram**: Set `features.zram.memoryPercent = 50` — 50% of 32GB = 16GB for zram. With lz4 compression (~2.5x), this yields ~40GB effective swap, more than adequate. Frees up 9.6GB of potential RAM pressure vs the old 80%.

**Files changed**:
- `hosts/yoga/default.nix` — Changed `core.boot.tmpfs.size` to `"4G"`, added `zram.memoryPercent = 50`

---

## 3. tmpfs Reduction on Latitude (Intel Laptop)

**Problem**: Same 80% tmpfs issue. The Latitude likely has 8-16GB RAM, so 80% = 6.4-12.8G for `/tmp`.

**Fix**: Reduced from `"80%"` to `"2G"` — more than enough for temporary files on a lightweight laptop.

**Files changed**:
- `hosts/latitude/default.nix` — Changed `core.boot.tmpfs.size` to `"2G"`

---

## 4. Remove Redundant `enableFstrim = false` on Yoga

**Problem**: Yoga's `features.filesystem.enableFstrim = false` was redundant. The filesystem module (`modules/features/filesystem.nix`) already auto-detects that btrfs with `discard=async` mount options makes periodic fstrim unnecessary.

**Fix**: Removed the explicit `enableFstrim = false` line — the module's auto-detection handles it.

**Files changed**:
- `hosts/yoga/default.nix` — Removed `enableFstrim = false`
