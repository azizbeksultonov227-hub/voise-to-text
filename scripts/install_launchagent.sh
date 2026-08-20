#!/bin/bash
# RubaiSTT — LaunchAgent'ni yozadi va (qayta) yuklaydi. Idempotent.
# Ilova bundle ichidagi executable TO'G'RIDAN-TO'G'RI ishga tushiriladi (/usr/bin/open emas:
# open darhol chiqib ketadi, KeepAlive bilan ishlamaydi). Jarayon launchd farzandi bo'ladi,
# Terminal yopilsa ham yashaydi.
set -e
LABEL="com.rubaistt.dictation"
APP="$HOME/Applications/RubaiSTT Dictation.app"
EXE="$APP/Contents/MacOS/RubaiSTTDictation"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOGDIR="$HOME/Library/Logs/rubaistt"
UID_="$(id -u)"

[ -x "$EXE" ] || { echo "Xato: $EXE topilmadi (avval src/build.sh)" >&2; exit 1; }
mkdir -p "$HOME/Library/LaunchAgents" "$LOGDIR"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$EXE</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ThrottleInterval</key><integer>10</integer>
    <key>ProcessType</key><string>Interactive</string>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
    <key>StandardOutPath</key><string>$LOGDIR/launchd.out.log</string>
    <key>StandardErrorPath</key><string>$LOGDIR/launchd.err.log</string>
</dict>
</plist>
PL
plutil -lint "$PLIST" >/dev/null

# Eski agentni to'g'ri tushirib, yangisini yuklaymiz (load/unload eskirgan)
launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || true
# bootout asinxron — jarayon chiqishini qisqa kutamiz
for _ in 1 2 3 4 5 6 7 8 9 10; do
    launchctl print "gui/$UID_/$LABEL" >/dev/null 2>&1 || break
    sleep 0.5
done
# LaunchAgent'dan tashqari ishlayotgan (qo'lda ochilgan) nusxalarni ham yopamiz — bitta nusxa bo'lsin
pkill -f "$EXE" 2>/dev/null || true
sleep 0.5
launchctl bootstrap "gui/$UID_" "$PLIST"
launchctl enable "gui/$UID_/$LABEL" 2>/dev/null || true
sleep 1.5
if launchctl print "gui/$UID_/$LABEL" 2>/dev/null | grep -q "state = running"; then
    echo "==> LaunchAgent yuklandi va ishlayapti: $LABEL"
else
    echo "!! LaunchAgent yuklandi, lekin 'running' holatida emas:" >&2
    launchctl print "gui/$UID_/$LABEL" 2>&1 | grep -E "state|last exit|pid" >&2
    exit 1
fi
