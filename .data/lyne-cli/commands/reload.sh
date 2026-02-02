# lyne reload - Restart quickshell detached from the terminal

quickshell kill
sleep 0.2
setsid quickshell >/dev/null 2>&1 &
disown
