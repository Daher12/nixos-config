# Shared "is the machine on AC power" probe (exit 0 = AC, 1 = battery).
# Used by both power scripts that previously carried a copy-pasted
# is_on_ac() shell function: home/battery-refresh.nix (user unit) and
# modules/hardware/ryzen-tdp.nix (system unit). Logic is a verbatim
# transplant of that function; see the AC/Battery trigger comments there.
{
  writeShellApplication,
  coreutils,
}:

writeShellApplication {
  name = "is-on-ac";
  runtimeInputs = [ coreutils ];

  text = ''
    for psu in /sys/class/power_supply/*; do
      type_file="$psu/type"
      online_file="$psu/online"

      if [ -f "$type_file" ] && [ -f "$online_file" ]; then
        type=$(cat "$type_file")
        online=$(cat "$online_file")

        if [ "$online" = "1" ] && { [ "$type" = "Mains" ] || [ "$type" = "USB" ]; }; then
          exit 0
        fi
      fi
    done
    exit 1
  '';
}
