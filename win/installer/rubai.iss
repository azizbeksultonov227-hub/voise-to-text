; RubaiSTT Diktovka — Windows o'rnatuvchisi (Inno Setup 6).
;
; Model (785 MB) o'rnatuvchi ichiga QO'SHILMAYDI — u o'rnatish paytida
; yuklab olinadi. Sabablari:
;   1) 800 MB .exe ni tarqatish qiyin, har yangilanishda qayta yuklanadi;
;   2) o'rnatish paytida yuklash administrator huquqi ostida ketadi, ya'ni
;      model Program Files ichiga tushadi va ilova keyin ruxsat so'ramaydi;
;   3) o'rnatuvchining o'zi ~30 MB bo'lib qoladi.
;
; Build: iscc rubai.iss  (SourceDir = build natijasi)

#define AppName        "RubaiSTT Diktovka"
#define AppVersion     "1.0.0"
#define AppPublisher   "RubaiSTT"
#define AppExe         "RubaiSTT.exe"
#define AppUrl         "https://github.com/MuhammadMirrr/uzbek-dictation"
#define ModelUrl       "https://github.com/MuhammadMirrr/uzbek-dictation/releases/download/v1.0/ggml-rubaistt.bin"
#define ModelSha256    "1b02df434902015e1464611a7748927e42fcb55c49791c85239cf713c8edc1a3"
#define ModelSize      823369796

[Setup]
AppId={{7F3A9C21-4E56-4B8D-9A17-2C6E5D8B1A40}
AppName={#AppName}
AppVersion={#AppVersion}
; Busiz Windows "Ilovalar" ro'yxatida "... version 1.0.0" deb ko'rsatadi.
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
DefaultDirName={autopf}\RubaiSTT
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=..\..\dist
OutputBaseFilename=RubaiSTT-Diktovka-{#AppVersion}-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

; 64-bitli ilova; 32-bitli Windows'da o'rnatilmaydi.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Windows 10 1809 (build 17763) dan pastda ishlamaydi — WASAPI va DWM
; funksiyalari yetishmaydi.
MinVersion=10.0.17763

; Ilova Program Files ga o'rnatiladi -> administrator huquqi kerak.
PrivilegesRequired=admin

[Languages]
Name: "uz"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
uz.CreateDesktopIcon=Ish stolida yorliq yaratilsin
uz.AutoStart=Kompyuter yonganda avtomatik ishga tushsin
uz.LaunchApp={#AppName} ni ishga tushirish
uz.DownloadingModel=Til modeli yuklab olinmoqda (785 MB)...
uz.ModelFailed=Model yuklab olinmadi.%n%nInternetga ulanishni tekshirib, o'rnatishni qaytadan boshlang.%n%nXato: %1

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "Qo'shimcha:"

; Avtostart bu yerda EMAS — ilovaning o'zi birinchi ishga tushganda yoqadi.
;
; Sabab: o'rnatuvchi administrator huquqi bilan ishlaydi, shuning uchun
; undagi HKCU administratorning registr uyasiga ishora qiladi, ilovani
; o'rnatayotgan foydalanuvchinikiga emas. Natijada avtostart noto'g'ri
; profilga yozilib, ishlamas edi. Ilova esa oddiy foydalanuvchi huquqida
; ishlaydi va HKCU'ni to'g'ri topadi.

[Files]
; Ilova va whisper.cpp kutubxonalari.
Source: "{#SourceDir}\RubaiSTT.exe";       DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\whisper.dll";        DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\ggml.dll";           DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\ggml-base.dll";      DestDir: "{app}"; Flags: ignoreversion

; GPU backend (NVIDIA + AMD + Intel).
Source: "{#SourceDir}\ggml-vulkan.dll";    DestDir: "{app}"; Flags: ignoreversion

; CPU backendining barcha variantlari. Ilova ishga tushganda protsessorga
; mos kelganini o'zi tanlaydi — shu sababli 2011 yildan keyingi har qanday
; x64 kompyuterda ishlaydi.
Source: "{#SourceDir}\ggml-cpu-*.dll";     DestDir: "{app}"; Flags: ignoreversion

; Visual C++ runtime.
;
; MSVCP140.dll / VCRUNTIME140.dll toza Windows'da YO'Q — ular Visual C++
; Redistributable bilan keladi. Ularsiz ilova umuman ochilmaydi
; ("VCRUNTIME140.dll topilmadi"). Ishlab chiqish mashinasida bor bo'lgani
; uchun bu xato sinovda ko'rinmaydi.
;
; Ilova yoniga qo'yamiz (Microsoft ruxsat bergan app-local deployment) —
; alohida redistributable o'rnatish va qayta yuklash shart emas.
; build.ps1 ularni Visual Studio redist papkasidan nusxalaydi.
Source: "{#SourceDir}\msvcp140*.dll";      DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\vcruntime140*.dll";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\concrt140.dll";      DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\vccorlib140.dll";    DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

Source: "..\..\LICENSE";                   DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Dirs]
Name: "{app}\models"

[Icons]
Name: "{group}\{#AppName}";                Filename: "{app}\{#AppExe}"
Name: "{group}\{#AppName} ni o'chirish";   Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";          Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; runasoriginaluser — ilova administrator emas, o'rnatayotgan
; FOYDALANUVCHI nomidan ishga tushadi. Busiz sozlamalar va avtostart
; administrator profiliga yozilib qolardi.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchApp}"; \
    Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallDelete]
; Model o'rnatuvchi bilan kelmagani uchun [Files] uni bilmaydi — qo'lda
; o'chiramiz, aks holda 785 MB fayl diskda qolib ketadi.
Type: files;      Name: "{app}\models\ggml-rubaistt.bin"
Type: dirifempty; Name: "{app}\models"

[Code]
var
  DownloadPage: TDownloadWizardPage;
  ModelDownloaded: Boolean;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax <> 0 then
    DownloadPage.SetProgress(Progress, ProgressMax);
  Result := True;
end;

// Model allaqachon o'rnatilganmi (qayta o'rnatish yoki yangilash holati).
//
// Busiz har qayta o'rnatishda 785 MB qaytadan yuklanardi. Hajmi bo'yicha
// tekshiramiz — buzuq yoki chala yuklangan fayl o'tib ketmasligi uchun.
function ModelAlreadyInstalled(): Boolean;
var
  Path: String;
  Size: Int64;
begin
  Result := False;
  Path := ExpandConstant('{app}\models\ggml-rubaistt.bin');
  if not FileExists(Path) then
    Exit;
  if not FileSize64(Path, Size) then
    Exit;
  Result := (Size = {#ModelSize});
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(
    SetupMessage(msgWizardPreparing),
    ExpandConstant('{cm:DownloadingModel}'),
    @OnDownloadProgress);
end;

// Oynali (odatiy) o'rnatish: progress ko'rsatib yuklaymiz.
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  ModelDownloaded := False;

  if CurPageID <> wpReady then
    Exit;

  // Model joyida bo'lsa qayta yuklamaymiz — 785 MB tejaladi.
  if ModelAlreadyInstalled() then
    Exit;

  DownloadPage.Clear;
  DownloadPage.Add('{#ModelUrl}', 'ggml-rubaistt.bin', '{#ModelSha256}');
  DownloadPage.Show;
  try
    try
      DownloadPage.Download;
      ModelDownloaded := True;
    except
      SuppressibleMsgBox(
        FmtMessage(ExpandConstant('{cm:ModelFailed}'), [GetExceptionMessage]),
        mbCriticalError, MB_OK, IDOK);
      Result := False;
    end;
  finally
    DownloadPage.Hide;
  end;
end;

// Jimgina o'rnatish (/SILENT, /VERYSILENT).
//
// MUHIM: NextButtonClick sehrgar hodisasi — jim rejimda sehrgar ishlamaydi
// va u UMUMAN chaqirilmaydi. Shu sababli model yuklanmay qolib, ilova
// "Model fayli topilmadi" deb ishlamas edi. PrepareToInstall esa ikkala
// rejimda ham chaqiriladi.
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';

  if not WizardSilent() then
    Exit;                       // oynali rejimda yuqoridagi kod ishlagan

  ModelDownloaded := False;
  if ModelAlreadyInstalled() then
    Exit;

  try
    DownloadTemporaryFile('{#ModelUrl}', 'ggml-rubaistt.bin', '{#ModelSha256}', nil);
    ModelDownloaded := True;
  except
    Result := FmtMessage(ExpandConstant('{cm:ModelFailed}'), [GetExceptionMessage]);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Src, Dst: String;
begin
  if CurStep <> ssPostInstall then
    Exit;

  // Model qayta yuklanmagan bo'lsa (allaqachon joyida) — hech narsa qilmaymiz.
  if not ModelDownloaded then
    Exit;

  // Yuklab olingan model o'rnatish papkasiga ko'chiriladi.
  //
  // Model Program Files ichida saqlanadi — bu yo'l har doim lotin
  // harflarda. whisper.cpp fayl yo'lini char* sifatida ochadi, shuning
  // uchun foydalanuvchi papkasi (C:\Users\Аброр\...) xavfli bo'lardi.
  Src := ExpandConstant('{tmp}\ggml-rubaistt.bin');
  Dst := ExpandConstant('{app}\models\ggml-rubaistt.bin');

  if not CopyFile(Src, Dst, False) then
    SuppressibleMsgBox(
      'Model o''rnatish papkasiga ko''chirilmadi. Diskda joy yetarlimi?',
      mbCriticalError, MB_OK, IDOK);
end;
