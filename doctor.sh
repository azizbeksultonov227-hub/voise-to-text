#!/bin/bash
# RubaiSTT Dictation — tizim tekshiruvi (doctor). Hech narsani o'zgartirmaydi.
#   ./doctor.sh          -> to'liq hisobot
# Har bir tekshiruv: ✅ OK / ⚠️ ogohlantirish / ❌ muammo + tuzatish yo'li.
ROOT="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.rubaistt.dictation"
APP="$HOME/Applications/RubaiSTT Dictation.app"
EXE="$APP/Contents/MacOS/RubaiSTTDictation"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/rubaistt/app.log"
MODEL="$HOME/rubai-stt/models/ggml-rubaistt.bin"
SIGN_CN="${RUBAI_SIGN_CN:-RubaiSTT Local Signing}"
UID_="$(id -u)"
FAIL=0; WARN=0
ok()   { echo "✅ $1"; }
warn() { echo "⚠️  $1"; [ -n "$2" ] && echo "     → $2"; WARN=$((WARN+1)); }
bad()  { echo "❌ $1"; [ -n "$2" ] && echo "     → $2"; FAIL=$((FAIL+1)); }
hr()   { echo; echo "── $1"; }

echo "RubaiSTT Dictation — doctor  ($(date '+%Y-%m-%d %H:%M'))  macOS $(sw_vers -productVersion)"

# ───────────────────────── 1. Ilova va imzo
hr "Ilova va imzo"
if [ -x "$EXE" ]; then
    ok "Ilova joyida: $APP"
else
    bad "Ilova topilmadi: $APP" "bash src/build.sh (yoki ./setup.sh)"
fi

if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$SIGN_CN\""; then
    CERT_SHA="$(security find-identity -v -p codesigning 2>/dev/null | grep "\"$SIGN_CN\"" | awk '{print $2}' | tr 'A-F' 'a-f')"
    ok "Imzolash sertifikati keychain'da yaroqli: \"$SIGN_CN\" ($CERT_SHA)"
else
    if security find-certificate -c "$SIGN_CN" >/dev/null 2>&1; then
        bad "\"$SIGN_CN\" sertifikati bor, lekin ishonchsiz (codesign uchun yaroqsiz)" "./scripts/make_signing_cert.sh  (parol so'raydi)"
    else
        bad "\"$SIGN_CN\" sertifikati yo'q — build ad-hoc imzolanadi, ruxsatlar har build'da yo'qoladi" "./scripts/make_signing_cert.sh && bash src/build.sh"
    fi
    CERT_SHA=""
fi

if [ -d "$APP" ]; then
    if codesign --verify --deep --strict "$APP" 2>/dev/null; then
        ok "Imzo yaxlit (codesign --verify o'tdi)"
    else
        bad "Imzo buzilgan yoki yo'q" "bash src/build.sh"
    fi
    DR="$(codesign -d -r- "$APP" 2>&1 | grep '^designated' | sed 's/^designated => //')"
    AUTH="$(codesign -dvv "$APP" 2>&1 | grep '^Authority=' | head -1 | cut -d= -f2-)"
    IDENT="$(codesign -dvv "$APP" 2>&1 | grep '^Identifier=' | cut -d= -f2-)"
    [ "$IDENT" = "$LABEL" ] && ok "Bundle identifier: $IDENT" || bad "Bundle identifier noto'g'ri: $IDENT" "src/build.sh dagi Info.plist'ni tekshiring"
    if echo "$DR" | grep -q 'cdhash'; then
        bad "Designated requirement cdhash'ga asoslangan (ad-hoc) — har build'da Accessibility ruxsati yo'qoladi" "./scripts/make_signing_cert.sh && bash src/build.sh, keyin Accessibility'ni qayta yoqing"
        echo "     DR: $DR"
    elif echo "$DR" | grep -q "certificate leaf"; then
        ok "Designated requirement barqaror (identifier + sertifikat): $DR"
        DR_SHA="$(echo "$DR" | sed -n 's/.*H"\([0-9a-f]*\)".*/\1/p')"
        if [ -n "$CERT_SHA" ] && [ "$DR_SHA" != "$CERT_SHA" ]; then
            bad "Ilova boshqa sertifikat bilan imzolangan ($DR_SHA ≠ keychain $CERT_SHA)" "bash src/build.sh"
        fi
    else
        warn "Designated requirement kutilmagan: $DR"
    fi
    [ -n "$AUTH" ] && echo "   Authority: $AUTH"
fi

# ───────────────────────── 2. LaunchAgent va jarayon
hr "LaunchAgent va jarayon"
if [ -f "$PLIST" ]; then
    if grep -q "<string>$EXE</string>" "$PLIST"; then
        ok "LaunchAgent plist executable'ga to'g'ridan-to'g'ri ishora qiladi"
    else
        bad "LaunchAgent plist eskirgan (/usr/bin/open yoki boshqa yo'l)" "./scripts/install_launchagent.sh"
    fi
    grep -q "<key>KeepAlive</key><true/>" "$PLIST" && ok "KeepAlive = true" || bad "KeepAlive yoqilmagan — crash'dan keyin qayta ko'tarilmaydi" "./scripts/install_launchagent.sh"
else
    bad "LaunchAgent plist yo'q: $PLIST" "./scripts/install_launchagent.sh"
fi

LC="$(launchctl print "gui/$UID_/$LABEL" 2>/dev/null)"
if [ -n "$LC" ]; then
    STATE="$(echo "$LC" | grep -m1 'state = ' | sed 's/.*state = //')"
    LPID="$(echo "$LC" | grep -m1 '	pid = ' | sed 's/.*pid = //')"
    RUNS="$(echo "$LC" | grep -m1 'runs = ' | sed 's/.*runs = //')"
    LAST="$(echo "$LC" | grep -m1 'last exit' | sed 's/.*last exit code = //')"
    if [ "$STATE" = "running" ]; then
        ok "LaunchAgent yuklangan va ishlayapti (pid $LPID, ishga tushishlar: $RUNS, oxirgi chiqish: $LAST)"
    else
        bad "LaunchAgent yuklangan, lekin holati: $STATE (oxirgi chiqish: $LAST)" "launchctl kickstart -k gui/$UID_/$LABEL; ~/Library/Logs/rubaistt/launchd.err.log ni ko'ring"
    fi
    [ "$RUNS" -gt 3 ] 2>/dev/null && warn "Login'dan beri $RUNS marta qayta ishga tushgan — crash bo'layotgan bo'lishi mumkin" "~/Library/Logs/DiagnosticReports/RubaiSTTDictation-*.ips ni ko'ring"
else
    bad "LaunchAgent yuklanmagan (launchctl print topmadi)" "./scripts/install_launchagent.sh"
fi

PIDS="$(pgrep -f "$EXE" 2>/dev/null)"
N="$(echo "$PIDS" | grep -c . )"
if [ "$N" -eq 1 ]; then
    PP="$(ps -o ppid= -p "$PIDS" | tr -d ' ')"
    ET="$(ps -o etime= -p "$PIDS" | tr -d ' ')"
    if [ "$PP" = "1" ]; then ok "Bitta nusxa ishlayapti (pid $PIDS, launchd farzandi, ish vaqti $ET)"
    else warn "Ilova ishlayapti, lekin launchd'dan emas (ppid $PP) — Terminal yopilsa o'chishi mumkin" "./scripts/install_launchagent.sh"; fi
elif [ "$N" -eq 0 ]; then
    bad "Ilova ishlamayapti" "launchctl kickstart -k gui/$UID_/$LABEL"
else
    bad "$N ta nusxa ishlayapti (ikki marta yozilish sababi!): $(echo $PIDS)" "./scripts/install_launchagent.sh (ortiqchalarini yopadi)"
fi

# SMAppService (login item) + LaunchAgent birga = ikki nusxa xavfi
if command -v sfltool >/dev/null 2>&1; then
    BTM="$(sfltool dumpbtm 2>/dev/null)"
    if echo "$BTM" | grep -B6 "Identifier: 2.$LABEL" 2>/dev/null | grep -q "Type: app"; then
        warn "SMAppService login item ham yoqilgan (LaunchAgent bilan birga) — ikki nusxa ochilishi mumkin" "Ilova keyingi ishga tushganda o'zi o'chiradi; yoki System Settings → General → Login Items'dan olib tashlang"
    else
        ok "Ortiqcha SMAppService login item yo'q"
    fi
fi

# ───────────────────────── 3. Ruxsatlar
hr "Ruxsatlar (TCC)"
TCCDB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
tcc_query() { sqlite3 "$TCCDB" "select auth_value from access where service='$1' and client='$LABEL' order by last_modified desc limit 1;" 2>/dev/null; }
AX_DB="$(tcc_query kTCCServiceAccessibility)"
if [ -n "$AX_DB" ]; then
    [ "$AX_DB" = "2" ] && ok "Accessibility: ruxsat berilgan (TCC bazasi)" || bad "Accessibility: ruxsat YO'Q (TCC bazasi: $AX_DB)" "System Settings → Privacy & Security → Accessibility → RubaiSTT Dictation ni yoqing"
else
    # TCC bazasini o'qib bo'lmaydi (Full Disk Access yo'q) — ilova logidagi oxirgi holatga tayanamiz
    AXL="$(grep -E 'Accessibility holati:|ruxsatlar: AX=' "$LOG" 2>/dev/null | tail -1)"
    if echo "$AXL" | grep -q "holati: BOR\|AX=true"; then
        ok "Accessibility: ruxsat bor (ilova logi, ${AXL%% *})"
    elif [ -n "$AXL" ]; then
        bad "Accessibility: ruxsat YO'Q (ilova logi, ${AXL%% *}) — matn joylashtirilmaydi, faqat clipboard" "System Settings → Privacy & Security → Accessibility → '+' → ~/Applications/RubaiSTT Dictation.app ni qo'shing va yoqing. Eski yozuv bo'lsa '−' bilan o'chirib qayta qo'shing."
    else
        warn "Accessibility holatini aniqlab bo'lmadi (log yo'q)" "Ilovani ishga tushirib, qayta tekshiring"
    fi
fi
MICL="$(grep -E 'ruxsatlar: .*mic=' "$LOG" 2>/dev/null | tail -1 | sed 's/.*mic=//')"
case "$MICL" in
    authorized) ok "Mikrofon: ruxsat bor" ;;
    denied|restricted) bad "Mikrofon: ruxsat rad etilgan" "System Settings → Privacy & Security → Microphone → RubaiSTT Dictation ni yoqing" ;;
    notDetermined) warn "Mikrofon: hali so'ralmagan — birinchi diktovkada macOS so'raydi, 'Allow' bosing" ;;
    *) warn "Mikrofon holati noma'lum (log yo'q)" ;;
esac

# ───────────────────────── 4. Model va whisper.cpp
hr "Model va whisper.cpp"
if [ -f "$MODEL" ]; then
    SZ="$(stat -f %z "$MODEL")"; MB=$((SZ/1024/1024))
    if   [ "$SZ" -gt 1400000000 ]; then ok "Model joyida: $MODEL (${MB} MB, f16)"
    elif [ "$SZ" -gt 700000000 ];  then ok "Model joyida: $MODEL (${MB} MB, q8_0)"
    else bad "Model fayli juda kichik (${MB} MB) — yuklab olish chala qolgan" "rm \"$MODEL\" && ./setup.sh"; fi
else
    bad "Model topilmadi: $MODEL" "./setup.sh"
fi
ML="$(grep 'rubai_load' "$LOG" 2>/dev/null | tail -1)"
if echo "$ML" | grep -q "= 0$"; then ok "Model oxirgi marta muvaffaqiyatli yuklangan (${ML%% *})"
elif [ -n "$ML" ]; then bad "Model oxirgi yuklanishda xato: $ML"; fi
for L in build-static build-x64; do
    if [ -f "$ROOT/whisper.cpp/$L/src/libwhisper.a" ]; then ok "whisper.cpp $L build'i bor"
    else [ "$L" = build-static ] && bad "whisper.cpp $L build'i yo'q" "./setup.sh" || warn "whisper.cpp $L (Intel) build'i yo'q — faqat arm64 ilova (bu Mac uchun yetarli)"; fi
done

# ───────────────────────── 5. Crash va loglar
hr "Crash va loglar"
CR="$(find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -name 'RubaiSTTDictation-*.ips' -mtime -7 2>/dev/null | sort)"
if [ -n "$CR" ]; then
    warn "So'nggi 7 kunda $(echo "$CR" | wc -l | tr -d ' ') ta crash hisoboti:" "$(echo "$CR" | tail -1)"
    LAST_CR="$(echo "$CR" | tail -1)"
    python3 - "$LAST_CR" 2>/dev/null <<'PY'
import json,sys
try:
    d=json.loads(open(sys.argv[1]).read().split('\n',1)[1])
    e=d.get('exception',{}); t=d['threads'][d.get('faultingThread',0)]
    imgs=d['usedImages']
    print("     oxirgisi:", e.get('type'), e.get('signal'), e.get('subtype',''))
    for fr in t['frames'][:4]:
        im=imgs[fr['imageIndex']]; print("       ", im.get('name'), fr.get('symbol') or '')
except Exception as ex: print("     (o'qib bo'lmadi)", ex)
PY
else
    ok "So'nggi 7 kunda crash hisoboti yo'q"
fi
if [ -f "$LOG" ]; then
    ok "Ilova logi: $LOG ($(wc -l < "$LOG" | tr -d ' ') qator)"
    ERRS="$(grep -c 'XATO' "$LOG" 2>/dev/null)"
    [ "${ERRS:-0}" -gt 0 ] && { warn "Logda $ERRS ta XATO yozuvi, oxirgilari:"; grep 'XATO' "$LOG" | tail -3 | sed 's/^/     /'; }
    echo "   oxirgi 3 qator:"; tail -3 "$LOG" | sed 's/^/     /'
else
    warn "Ilova logi hali yo'q: $LOG"
fi

# ───────────────────────── Xulosa
echo
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then echo "🎉 Hammasi joyida."
elif [ "$FAIL" -eq 0 ]; then echo "✅ Jiddiy muammo yo'q, $WARN ta ogohlantirish."
else echo "❌ $FAIL ta muammo, $WARN ta ogohlantirish — yuqoridagi '→' ko'rsatmalarga amal qiling."; fi
exit $FAIL
