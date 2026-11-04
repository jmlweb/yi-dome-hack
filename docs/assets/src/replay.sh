#!/bin/bash
# Replays rows recorded in docs/measurements/ (stock baseline and no-audio-thread boot runs).
# Times are compressed. Patched rows are an excerpt of the 9 starts in that run.
row() { sleep 0.45; printf '  %s   rmm: %-5s   MQTT: %-12s %b\n' "$1" "$2" "$3" "$4"; }
ok='\e[32m✓\e[0m'; lost='\e[1;31m✗ LOST\e[0m'

printf '\e[1;33mSTOCK\e[0m mqttv4, auto-tracking on\n\n'
row 11:18:25 0xe6 '(nothing)' "$lost"
row 11:19:31 0x7d motion_stop "$ok"
row 11:53:26 0xe6 '(nothing)' "$lost"
row 11:54:32 0x7d motion_stop "$ok"
row 11:58:50 0xe6 '(nothing)' "$lost"
row 11:59:56 0x7d motion_stop "$ok"
row 12:03:47 0x7c motion_start "$ok"
printf '\n  \e[1;31m3 of 4 starts lost\e[0m in 53 min\n\n'
sleep 1.6
printf '\e[1;34mPATCHED\e[0m mqttv4, same camera, tracking still on\n\n'
row 21:51:06 0xe6 motion_start "$ok"
row 21:52:12 0x7d motion_stop "$ok"
row 21:55:13 0xe6 motion_start "$ok"
row 21:56:41 0x7d motion_stop "$ok"
row 22:01:42 0xe6 motion_start "$ok"
row 22:02:48 0x7d motion_stop "$ok"
printf '\n  \e[1;32m0 of 9 starts lost\e[0m in 58 min\n'
sleep 3
