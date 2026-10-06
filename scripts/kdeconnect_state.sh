#!/usr/bin/env bash
for id in $(kdeconnect-cli -l --id-only 2>/dev/null); do
  b=/modules/kdeconnect/devices/$id
  g() { busctl --user get-property org.kde.kdeconnect "$b$2" "org.kde.kdeconnect.device$3" "$1" 2>/dev/null | cut -d' ' -f2-; }
  n=$(g name "" "" | sed 's/^"//;s/"$//'); t=$(g type "" "" | tr -d '"'); r=$(g isReachable "" ""); s=$(g pairState "" ""); k=$(g verificationKey "" "" | tr -d '"'); ip=$(g reachableAddresses "" "" | grep -o '"[^"]*"' | head -n1 | tr -d '"')
  c=-1; ch=false; no=0; sg=-1; nt=""
  if [ "$r" = true ] && [ "$s" = 3 ]; then
    c=$(g charge /battery .battery); ch=$(g isCharging /battery .battery)
    no=$(busctl --user call org.kde.kdeconnect $b/notifications org.kde.kdeconnect.device.notifications activeNotifications 2>/dev/null | awk '{print $2}')
    sg=$(g cellularNetworkStrength /connectivity_report .connectivity_report); nt=$(g cellularNetworkType /connectivity_report .connectivity_report | tr -d '"')
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$n" "${t:-phone}" "${r:-false}" "${s:-0}" "$k" "${c:--1}" "${ch:-false}" "${no:-0}" "$ip" "${sg:--1}" "$nt"
done
