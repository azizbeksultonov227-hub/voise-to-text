# Audio-Matnga — Windows

O'zbekcha ovozli yozuv. Istalgan ilovada **Ctrl+Alt+D** bosing, gapiring, yana bosing —
matn kursor turgan joyga yoziladi. To'liq oflayn, internetsiz.

macOS versiyasining Windows portlanishi. Bir xil model (`rubaiSTT v2 medium`),
bir xil inference parametrlari.

---

## O'rnatish

Ikkita variant bor:

| Fayl | Hajm | Qachon |
|---|---|---|
| `...-setup.exe` | 8 MB | Internet barqaror bo'lsa — model o'rnatish paytida yuklanadi |
| `...-oflayn-setup.exe` | 749 MB | **Internet sekin yoki uzilib qolsa** — model ichida, ulanish kerak emas |

1. Fayllardan birini yuklab oling va ishga tushiring
2. Birinchi ochilishda Sozlamalar oynasi chiqadi — **mikrofoningizni tanlang**

### Model yuklab olinmasa

Oddiy o'rnatuvchi modelni GitHub'dan oladi. Ulanish uzilsa u uch marta qayta
uradi, keyin xato beradi. Uchta yo'l bor (o'rnatuvchi shu tartibda qaraydi):

1. **Model allaqachon o'rnatilgan** — qayta o'rnatishda qaytadan yuklanmaydi
2. **`ggml-rubaistt.bin` ni `setup.exe` yoniga qo'ying** — o'rnatuvchi uni
   o'zi topadi va internetsiz o'rnatadi. Faylni brauzer yoki yuklab olish
   menejeri bilan alohida olish mumkin (ular uzilishdan keyin davom ettiradi)
3. **Oflayn o'rnatuvchi** — model uning ichida

> **Muhim:** mikrofonni albatta tanlang. Windows'da standart qurilma ba'zan
> "Stereo Mix" bo'lib qoladi — u ovozingizni emas, kompyuter ovozini yozadi.
> Ilova bunday qurilmalarni sariq rangda ogohlantiradi.

### SmartScreen ogohlantirishi

Ilova hozircha kod imzosi sertifikati bilan imzolanmagan, shuning uchun Windows
"Windows protected your PC" deb ogohlantirishi mumkin. Bir martalik yechim:
**"Batafsil ma'lumot" (More info) → "Baribir ishga tushirish" (Run anyway)**.

## Ishlatish

| Amal | Qanday |
|---|---|
| Yozishni boshlash / to'xtatish | **Ctrl+Alt+D** |
| Sozlamalar | Tray ikonkasiga **chap tugma** bilan bosing |
| Menyu (diktovka, log, chiqish) | Tray ikonkasiga **o'ng tugma** |

Tugmani Sozlamalardan o'zgartirish mumkin.

## Talablar

- Windows 10 (1809, build 17763) yoki Windows 11, **64-bit**
- 4 GB RAM (videokarta bilan) / 6 GB (protsessor rejimida)
- ~1 GB disk
- Videokarta tavsiya etiladi — NVIDIA, AMD yoki Intel, farqi yo'q

Videokarta bo'lmasa protsessorda ishlaydi, taxminan **8 marta sekinroq**.

## Tezlik (RTX 3060, 208 s audio)

| Rejim | Vaqt | Realtime |
|---|---|---|
| Vulkan (videokarta) | 25 s | 0.12× |
| Protsessor (Ryzen 7 5800X) | 196 s | 0.94× |

Amalda: 10 soniyalik diktovka videokartada ~1 soniyada matnga aylanadi.

## Aniqlik

Google FLEURS o'zbek datasetida o'lchangan (yangiliklar uslubidagi murakkab matnlar):
**WER 17%** — ya'ni so'zlarning ~83% to'g'ri. Kundalik oddiy gaplarda aniqlik yuqoriroq.

---

## Manbadan build qilish

### Talablar (bir marta)

```powershell
winget install Kitware.CMake
winget install KhronosGroup.VulkanSDK
winget install JRSoftware.InnoSetup
winget install Microsoft.VisualStudio.2022.BuildTools --override `
    "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
```

### Build

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1
```

whisper.cpp'ni Vulkan bilan yig'adi → ilovani build qiladi → o'rnatuvchi yasaydi.
Natija: `dist\Audio-Matnga-1.0.0-setup.exe`

Foydali bayroqlar:

| Bayroq | Vazifasi |
|---|---|
| `-SkipWhisper` | whisper.cpp allaqachon yig'ilgan bo'lsa o'tkazib yuboradi |
| `-NoInstaller` | faqat `.exe` yasaydi, o'rnatuvchisiz |
| `-WorkDir <yo'l>` | build artefaktlari papkasi (standart `D:\rubai`) |

### Yordamchi vositalar

```powershell
# Yadroni tekshirish
rubai-cli.exe audio.wav --model <yo'l>    # fayldan transkripsiya
rubai-cli.exe --mics                      # mikrofonlar ro'yxati
rubai-cli.exe --record 5                  # 5 soniya yozib transkripsiya

# Aniqlikni o'lchash (FLEURS datasetida)
python win\tools\bench_accuracy.py --cli <whisper-cli.exe> --model <model> -n 20
```

---

## Kod tuzilishi

```
win/
  core/                UI'dan mustaqil yadro
    whisper_bridge.c   whisper.cpp ustidan C shim (macOS bilan bir xil parametrlar)
    engine.cpp         model yuklash, isitish, navbat, RAM'ni bo'shatish
    audio_capture.cpp  WASAPI: mikrofon -> 16 kHz mono float32
    samples.cpp        signal normalizatsiyasi va sifat tekshiruvi
    config.cpp         sozlamalar fayli
    wav.cpp            WAV o'quvchi (testlar uchun)
    util.cpp           kodlash, yo'llar, log
  ui/
    app.cpp            WinMain, tray, hotkey, asosiy oqim
    overlay.cpp        suzuvchi holat oynasi (fokusni o'g'irlamaydi)
    settings_window.cpp
    inserter.cpp       clipboard + Ctrl+V / Unicode yozish
    autostart.cpp      registry Run kaliti
  installer/rubai.iss  Inno Setup
  tools/               ikonka yasash, aniqlik o'lchash
```

Fayllar va papkalar:

| Nima | Qayerda |
|---|---|
| Sozlamalar | `%APPDATA%\Audio-Matnga\settings.ini` |
| Log | `%LOCALAPPDATA%\Audio-Matnga\dictation.log` |
| Model | `<o'rnatilgan papka>\models\ggml-rubaistt.bin` |

---

## macOS versiyasidan farqlar

**Yo'q qilingan murakkabliklar:** Accessibility ruxsati, Gatekeeper, notarize —
Windows'da bularning hech biri kerak emas.

**Qo'shilgan funksiyalar:**

- **Mikrofon tanlash** — Windows'da standart qurilma "Stereo Mix" bo'lib qolishi
  mumkin, u ovoz o'rniga kompyuter ovozini yozadi
- **"Jim oqim" aniqlash** — Iriun, OBS, VB-Cable va ulanmagan Bluetooth
  qurilmalari `OK` holatida ko'rinib, aslida sukunat beradi
- **Bluetooth HFP ogohlantirishi** — quloqchin mikrofoni 8–16 kHz ga tushadi
- **GPU quvurini oldindan isitish** — Vulkan birinchi ishga tushishda shader'larni
  kompilyatsiya qiladi (~12 s). Bu ilova ochilganda fonda bajariladi, aks holda
  foydalanuvchining birinchi diktovkasi juda sekin bo'lardi
- **Kirill/lotin bo'lmagan yo'llar** — model ASCII yo'lda saqlanadi, chunki
  whisper.cpp fayl yo'lini `char*` sifatida ochadi

## Litsenziya

MIT. Model va whisper.cpp o'z litsenziyalari ostida.
