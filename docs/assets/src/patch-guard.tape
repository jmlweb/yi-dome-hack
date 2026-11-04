Output docs/assets/patch-guard.gif
Set Shell bash
Set FontFamily "Menlo"
Set FontSize 16
Set Width 1000
Set Height 280
Set Padding 24
Set TypingSpeed 28ms
Set Theme { "name": "gh", "background": "#0d1117", "foreground": "#e6edf3", "red": "#ff7b72", "green": "#3fb950", "yellow": "#d29922", "blue": "#58a6ff", "black": "#0d1117", "white": "#e6edf3", "brightBlack": "#6e7681", "brightRed": "#ffa198", "brightGreen": "#56d364", "brightYellow": "#e3b341", "brightBlue": "#79c0ff", "brightWhite": "#f0f6fc", "cyan": "#39c5cf", "magenta": "#bc8cff", "brightCyan": "#56d4dd", "brightMagenta": "#d2a8ff", "cursor": "#e6edf3", "selection": "#264f78" }
Hide
Type "PS1='$ ' ; head -c 4096 /dev/urandom > wrong-binary ; clear" Enter
Sleep 300ms
Show
Sleep 500ms
Type "python3 scripts/patch-apply.py patches/rmm-1.9.1.0J-no-audio-thread.json wrong-binary patched"
Sleep 400ms
Enter
Sleep 1.8s
Type "ls patched"
Sleep 300ms
Enter
Sleep 3s
