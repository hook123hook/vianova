@echo off
REM ViaNova - view-only cuzdani (vianova-watch) olusturur.
REM Hazirlik: ana (final) cuzdanindan su iki degeri al
REM   1) address     : monero-wallet-cli'de "address" komutu (veya cuzdanin goruyusu)
REM   2) viewkey     : monero-wallet-cli'de "viewkey" komutu (genellikle .keys dosyasindan gelir)
REM Bu betik PAROLLARI terminale sen yapistirirsin; hicbir yere yazilmaz, limitede kalmaz.
setlocal
cd /d "%~dp0"

REM Node secimi:
REM   A) Public node (monerod GEREKMEZ) : set DAEMON=http://node.moneroworld.com:18081
REM   B) Kendi node'un (TAILS PC)      : set DAEMON=http://192.168.1.197:18081
set DAEMON=http://node.moneroworld.com:18081

REM Performans: sync'i cuzdanin ilk kullanim anindan baslat. Gerekirse ELEDEK YUKARIDAKI
REM satira ekle: --restore-height <bugunku-yukseklik>   (orn. --restore-height 4000000)
echo.
echo ViaNova watch (view-only) cuzdani olusturuluyor.
echo Ana cuzdanin address + viewkey degerlerini gireceksin, sonra cuzdan sifresi.
echo.
bin\monero-wallet-cli.exe --generate-from-view-key vianova-watch --daemon-address %DAEMON% --subaddress-lookahead 2:500 --restore-height 3200000

if not exist "%~dp0vianova-watch.keys" (
  echo.
  echo [!] vianova-watch olusturulamadi. Yukaridaki hatalara bak.
  exit /b 1
)

echo.
echo [OK] vianova-watch.keys hazir.
echo Sonraki adimlar:
echo   1) start.local.bat  (wallet-rpc + bridge ayakta kalsin)
echo   2) npm run doctor   (her sey [OK] mi?)
echo   3) npm run seed     (adres havuzunu doldur)
echo.