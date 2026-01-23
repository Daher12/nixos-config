#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Pre-Migration Network Health Check
# Validates that a network interface is physically and logically ready for strict networkd.
# -----------------------------------------------------------------------------

# 1. Hard Dependency Check
for bin in ip awk ping paste; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "❌ CRITICAL: Missing dependency: $bin"
    exit 1
  }
done

# The interface to validate. Defaults to 'enp1s0' but can be overridden.
# Usage: IFACE=enp2s0 TARGET_IP=10.0.0.10 ./check-network.sh
IFACE="${IFACE:-enp1s0}"

# Prefer a management target that reflects "will I still be able to reach the box?"
TARGET_IP="${TARGET_IP:-1.1.1.1}"

echo "=== Pre-Migration Network Health Check ($IFACE) ==="

# 2. Existence Check
if [ ! -d "/sys/class/net/$IFACE" ]; then
    echo "❌ CRITICAL: Interface '$IFACE' not found in /sys/class/net."
    echo "   Verify your hardware-configuration.nix or NIC drivers."
    exit 1
fi
echo "✅ Interface exists."

# 3a. Admin State Check (Link may have carrier but be administratively down)
if [ ! -r "/sys/class/net/$IFACE/operstate" ]; then
    echo "❌ CRITICAL: Missing operstate for $IFACE (unexpected sysfs layout)."
    exit 1
fi

OPERSTATE="$(<"/sys/class/net/$IFACE/operstate")"
if [ "$OPERSTATE" = "down" ]; then
    echo "❌ CRITICAL: Interface $IFACE is administratively down (operstate=down)."
    echo "   Bring it up before migration (e.g., ip link set $IFACE up)."
    exit 1
fi
echo "✅ Interface operstate: $OPERSTATE."

# 3b. Carrier Check (Physical Link)
if [ ! -r "/sys/class/net/$IFACE/carrier" ]; then
    echo "❌ CRITICAL: Missing carrier for $IFACE (not a physical NIC?)."
    exit 1
fi

if [ "$(<"/sys/class/net/$IFACE/carrier")" != "1" ]; then
    echo "❌ CRITICAL: No carrier signal on $IFACE."
    echo "   Is the Ethernet cable plugged in?"
    exit 1
fi
echo "✅ Carrier detected (Link is UP)."

# 4. Address Check (IPv4)
IPS=$(ip -4 -o addr show dev "$IFACE" scope global)
if [ -z "$IPS" ]; then
    echo "❌ CRITICAL: No IPv4 address assigned to $IFACE."
    echo "   Current DHCP client is failing or network is down."
    exit 1
fi
echo "✅ IP Address assigned: $(echo "$IPS" | awk '{print $4}' | paste -sd ' ' -)"

# 5. Default Route Check
ROUTES=$(ip -4 route show default dev "$IFACE" || true)
if [ -z "$ROUTES" ]; then
    echo "❌ CRITICAL: No default route via $IFACE."
    exit 1
fi

# We strictly look for 'via' to ensure it's a routed gateway, not just on-link.
GATEWAY=$(echo "$ROUTES" | awk '/default/ && /via/ {print $3; exit}')
if [ -z "$GATEWAY" ]; then
    echo "❌ CRITICAL: Default route exists but has no gateway IP ('via' missing)."
    echo "   This script expects a routed default gateway for the migration criteria."
    exit 1
fi
echo "✅ Default route present via $GATEWAY."

# 6. Connectivity (L3 Reachability)
PING_OPTS=(-c 1 -W 2)

if ping "${PING_OPTS[@]}" "$GATEWAY" >/dev/null 2>&1; then
    echo "✅ Gateway reachable."
else
    echo "⚠️  WARNING: Gateway $GATEWAY did not respond to ping (Firewall?)."
fi

# 7. Routing Policy Sanity Check
# Confirm the kernel *actually* intends to route traffic to TARGET_IP via this interface.
if ip -4 route get "$TARGET_IP" oif "$IFACE" >/dev/null 2>&1; then
    echo "✅ Kernel confirms $TARGET_IP routes via $IFACE."
else
    echo "❌ CRITICAL: Kernel cannot route to $TARGET_IP via $IFACE (policy/metric mismatch)."
    exit 1
fi

if ping "${PING_OPTS[@]}" "$TARGET_IP" >/dev/null 2>&1; then
    echo "✅ Target reachable: $TARGET_IP."
else
    echo "⚠️  WARNING: Target $TARGET_IP not reachable."
fi

echo "==================================================="
echo "PASS: $IFACE is healthy and meets ':routable' criteria."
echo "      Safe to apply systemd-networkd configuration."
