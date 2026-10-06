#!/usr/bin/env bash
b=/modules/kdeconnect/devices/$1/notifications
ids=$(busctl --user call org.kde.kdeconnect "$b" org.kde.kdeconnect.device.notifications activeNotifications 2>/dev/null | cut -d' ' -f3- | tr -d '"')
for n in $ids; do
  j=$(busctl --user --json=short call org.kde.kdeconnect "$b/$n" org.freedesktop.DBus.Properties GetAll s org.kde.kdeconnect.device.notifications.notification 2>/dev/null)
  [ -n "$j" ] && printf '%s\t%s\n' "$n" "$j"
done
