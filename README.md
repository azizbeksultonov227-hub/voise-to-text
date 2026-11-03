# 🎙️ Audio-Matnga — O'zbekcha ovozli yozuv

Istalgan ilovada (Telegram, brauzer, hujjat — qayerda kursor bo'lsa) tugmani bosib o'zbekcha gapiring — matn avtomatik o'sha joyga lotin alifbosida yoziladi.

> **Bu nusxa haqida:** asl loyiha [MuhammadMirrr/uzbek-dictation](https://github.com/MuhammadMirrr/uzbek-dictation)
> (muallif: Muhammad Mirqobilov, MIT litsenziya) GitHub'dan o'chirilgan. Bu repo o'sha kodning
> ishlaydigan nusxasi. Tayyor DMG/EXE **bu yerda yo'q** — macOS'da pastdagi
> [manbadan o'rnatish](#-ornatish--install) usuli bilan 5-10 daqiqada o'rnatiladi. Model fayli
> (1.4 GB) [Releases](https://github.com/azizbeksultonov227-hub/voise-to-text/releases) bo'limida.

| Platforma | Tugma | O'rnatish | Texnik hujjat |
|---|---|---|---|
| **macOS** 13+ | ⌃⌥D | `./setup.sh` (pastda) | shu hujjat |
| **Windows** 10/11 | Ctrl+Alt+D | manbadan build | [win/README.md](win/README.md) |

Ikkala versiya bir xil modeldan (`rubaiSTT v2 medium`) va bir xil inference parametrlaridan
foydalanadi — natijalar bir xil bo'ladi. Tizimning o'rnatilgan diktovkasi kabi, lekin
**o'zbek tili uchun maxsus**, **butunlay oflayn** (internetsiz), va **bepul**.

> **Nom haqida:** mahsulot nomi — **Audio-Matnga**. Windows ilovasi shu nom bilan
> o'rnatiladi. macOS ilovasining bundle nomi hozircha `RubaiSTT Dictation.app`
> bo'lib qolgan: uni o'zgartirsak, mavjud Mac foydalanuvchilari Accessibility
> ruxsatini qaytadan berishga majbur bo'ladi va avtostart uziladi.

> System-wide Uzbek speech-to-text dictation for **macOS and Windows**. Press the hotkey
> anywhere, speak Uzbek, and the transcribed text is typed into the focused field.
> Powered by the [rubaiSTT](https://huggingface.co/islomov/rubaistt_v2_medium) model running
> locally via [whisper.cpp](https://github.com/ggml-org/whisper.cpp) — Metal on macOS,
> Vulkan on Windows. Fully offline.

---

## 🗂 Repozitoriy tuzilishi

```
src/          macOS ilovasi (Swift + C shim)
win/          Windows ilovasi (C++20 + Win32)   -> win/README.md
scripts/      macOS release skriptlari
web/          yuklab olish sahifasi
assets/       ikonkalar
```

Windows portining texnik tafsilotlari, o'lchangan ko'rsatkichlar va sinovda topilgan
xatolar: [WINDOWS-PORT-PLAN.md](WINDOWS-PORT-PLAN.md)

---

## ✨ Xususiyatlar / Features

- 🌐 **Tizim bo'ylab** — istalgan ilovada ishlaydi (global hotkey **⌃⌥D**)
- 🇺🇿 **O'zbek tiliga maxsus** — `rubaiSTT v2 medium` modeli, lotin alifbosi
- ⚡ **Metal tezlashtirish** — Apple Silicon GPU'da tez · Intel'da CPU bilan ishlaydi (universal)
- 🔌 **To'liq oflayn** — hech qanday server/internet kerak emas, ovoz qurilmangizdan chiqmaydi
- 🪶 **Yengil** — menyu-bar ilovasi; model 3 daqiqa ishlatilmasa RAM'dan bo'shaydi
- ⌨️ **Sozlanadigan tugma** — diktovka tugmasini Sozlamalar oynasidan o'zgartirish mumkin (standart ⌃⌥D)

## 📋 Talablar / Requirements

- macOS 13+ · **Universal** — Apple Silicon (M1–M5, Metal bilan tez) yoki Intel (CPU, sekinroq)
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools (`xcode-select --install`)
- ~2 GB disk (model ~1.4 GB)

## 🚀 O'rnatish / Install

### A) Tayyor DMG — hozircha yo'q

Asl muallifning Developer ID bilan imzolangan DMG'si eski repo bilan birga o'chib ketgan. Bu
nusxada DMG yo'q; pastdagi **B** usuli bilan o'rnating (terminal kerak, lekin hammasi avtomatik).

### B) Manbadan o'rnatish (asosiy usul)

```bash
git clone https://github.com/azizbeksultonov227-hub/voise-to-text.git
cd voise-to-text
./setup.sh
```

`setup.sh` avtomatik: kerakli vositalarni o'rnatadi → whisper.cpp'ni Metal bilan build qiladi → modelni yuklaydi → doimiy imzolash sertifikati yaratadi (bir marta, parol so'raydi) → ilovani build qilib `~/Applications` ga o'rnatadi → LaunchAgent (login'da avto-ishga tushish, crash'dan keyin o'zi ko'tariladi) → `doctor.sh` bilan holatni ko'rsatadi.

Qayta ishga tushirish xavfsiz: mavjud build'lar, model va ruxsatlar saqlanadi.

### Tekshirish — `doctor.sh`

```bash
./doctor.sh
```

Imzo, LaunchAgent, ruxsatlar (Accessibility/Mikrofon), model, crash hisobotlari — har biri ✅/❌ va tuzatish yo'li bilan. Loglar: `~/Library/Logs/rubaistt/app.log`.

### Oxirgi qadam — Accessibility ruxsati

Matn avtomatik joylashishi uchun (⌘V yuborish) bir marta ruxsat bering:

1. **System Settings → Privacy & Security → Accessibility**
2. **"RubaiSTT Dictation"** ni qo'shing (`+`) va **yoqing** ✅

Birinchi yozishda **mikrofon** ruxsati ham so'raladi — ruxsat bering.

## 🎯 Ishlatish / Usage

1. Istalgan joyda kursorni yozish maydoniga qo'ying
2. **⌃⌥D** bosing → 🔴 gapiring → **⌃⌥D** yana bosing
3. Matn o'sha joyga yoziladi

Menyu-bardagi 🎙️ ikonadan ham boshqarish mumkin.

## 📦 Tarqatish / Release (developer)

Imzolangan + notarize qilingan DMG yasash:

```bash
# Bir martalik: notarize uchun keychain profil
xcrun notarytool store-credentials rubai-notary \
    --apple-id "siz@example.com" --team-id "TEAMID" \
    --password "xxxx-xxxx-xxxx-xxxx"   # app-specific parol

brew install create-dmg     # chiroyli DMG foni uchun (ixtiyoriy)
./scripts/release.sh        # build → Developer ID imzo → notarize → DMG
```

Natija: `dist/RubaiSTT-Dictation.dmg`. Skript "Developer ID Application" sertifikatini avtomatik topadi; model `.app` ichiga joylanadi.

## ⚠️ Eslatma / Notes

- Tayyor DMG **Developer ID bilan imzolangan** (hardened runtime). Notarize keyinroq qo'shiladi — shu sababli birinchi ochishda yuqoridagi bir martalik qadam kerak. Manbadan build (`setup.sh`) esa login keychain'dagi **self-signed "RubaiSTT Local Signing"** sertifikati bilan imzolanadi — har build bir xil sertifikat, shuning uchun macOS Accessibility/Mikrofon ruxsatlari qayta build'dan keyin ham saqlanadi (ad-hoc imzoda har build ruxsatni buzardi).
- App Store'ga **chiqmaydi** — tizim bo'ylab matn yozish (synthetic ⌘V) sandbox'da taqiqlangan; shuning uchun Developer ID orqali tarqatiladi.
- **Universal binary** — Apple Silicon (Metal GPU) va Intel (CPU). Intel'da sezilarli sekinroq, lekin ishlaydi.

## 🛠 Texnik tafsilotlar

- **Model:** [`islomov/rubaistt_v2_medium`](https://huggingface.co/islomov/rubaistt_v2_medium) → ggml **q8_0** (8-bit) ga siqilgan — ~820 MB, ~700 MB kamroq RAM, aniqlik deyarli o'zgarmaydi
- **Inference:** whisper.cpp + Metal, beam search (maksimal aniqlik)
- **Til:** `uz`, lotin alifbosi
- **UI:** Swift / AppKit, menyu-bar (LSUIElement), global hotkey Carbon orqali
- **Matn kiritish:** clipboard + ⌘V (CGEvent) — Accessibility ruxsati kerak

## 📄 Litsenziya

MIT (`LICENSE`). Model va whisper.cpp o'z litsenziyalari ostida.

## 🙏 Minnatdorchilik

- [rubaiSTT](https://huggingface.co/islomov/rubaistt_v2_medium) — Sardor Islomov (o'zbek STT modeli)
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) — Georgi Gerganov
- [OpenAI Whisper](https://github.com/openai/whisper)
