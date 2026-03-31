@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  make_msix.cmd - Build an MSIX package for Copilot Cat
REM ============================================================
REM
REM  Usage:
REM    pkg\make_msix.cmd [build_dir] [/sign]
REM
REM  Arguments:
REM    build_dir   Path containing copilot-cat.exe (default: build\Release)
REM    /sign       Create and apply a self-signed test certificate
REM
REM  Examples:
REM    pkg\make_msix.cmd                          -- static build, no signing
REM    pkg\make_msix.cmd build\Release /sign      -- static + test cert
REM    pkg\make_msix.cmd build-dynamic\Release     -- dynamic build with Qt DLLs
REM
REM  Output:
REM    pkg\copilot-cat.msix
REM

set "BUILD_DIR=%~1"
if "%BUILD_DIR%"=="" set "BUILD_DIR=build\Release"

set "SIGN_PACKAGE=0"
for %%a in (%*) do (
    if /i "%%a"=="/sign" set "SIGN_PACKAGE=1"
)

set "PKG_DIR=%~dp0"
set "REPO_ROOT=%PKG_DIR%.."
set "STAGING=%PKG_DIR%staging"
set "OUTPUT=%PKG_DIR%copilot-cat.msix"
set "EXE_PATH=%REPO_ROOT%\%BUILD_DIR%\copilot-cat.exe"

REM ---- Validate exe exists ----
if not exist "%EXE_PATH%" (
    echo ERROR: copilot-cat.exe not found at: %EXE_PATH%
    echo.
    echo Build the project first:
    echo   cmake --build build --config Release
    echo.
    echo Or specify the build directory:
    echo   pkg\make_msix.cmd build-dynamic\Release
    exit /b 1
)

REM ---- Generate placeholder icons if missing ----
if not exist "%PKG_DIR%Assets\StoreLogo.png" (
    echo Generating placeholder icons...
    python "%PKG_DIR%gen_icons.py"
    if errorlevel 1 (
        echo WARNING: Icon generation failed. Create Assets\ PNGs manually.
    )
    echo.
)

REM ---- Find MakeAppx.exe ----
set "MAKEAPPX="

REM Check if MakeAppx is on PATH
where MakeAppx.exe >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%p in ('where MakeAppx.exe') do (
        set "MAKEAPPX=%%p"
        goto :found_makeappx
    )
)

REM Search Windows SDK paths (newest version first)
set "SDK_ROOT=C:\Program Files (x86)\Windows Kits\10\bin"
if exist "%SDK_ROOT%" (
    for /f "delims=" %%d in ('dir /b /o-n "%SDK_ROOT%\10.*" 2^>nul') do (
        if exist "%SDK_ROOT%\%%d\x64\MakeAppx.exe" (
            set "MAKEAPPX=%SDK_ROOT%\%%d\x64\MakeAppx.exe"
            goto :found_makeappx
        )
    )
)

if "%MAKEAPPX%"=="" (
    echo ERROR: MakeAppx.exe not found.
    echo.
    echo Install the Windows SDK:
    echo   https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/
    echo.
    echo Or add it to PATH:
    echo   set PATH=C:\Program Files ^(x86^)\Windows Kits\10\bin\10.0.22621.0\x64;%%PATH%%
    exit /b 1
)

:found_makeappx
echo Using MakeAppx: %MAKEAPPX%

REM ---- Find SignTool.exe (same directory as MakeAppx) ----
set "SIGNTOOL="
for %%i in ("%MAKEAPPX%") do set "SDK_BIN_DIR=%%~dpi"
if exist "%SDK_BIN_DIR%SignTool.exe" (
    set "SIGNTOOL=%SDK_BIN_DIR%SignTool.exe"
)

REM ---- Clean and create staging directory ----
echo.
echo Preparing staging directory...
if exist "%STAGING%" rmdir /s /q "%STAGING%"
mkdir "%STAGING%"
mkdir "%STAGING%\Assets"

REM ---- Copy exe (and Qt DLLs if present) ----
echo Copying application files...
copy /y "%EXE_PATH%" "%STAGING%\" >nul

REM Copy all DLLs, plugins, and QML modules if this is a dynamic build
REM (windeployqt places them next to the exe)
set "BUILD_ABS=%REPO_ROOT%\%BUILD_DIR%"
if exist "%BUILD_ABS%\Qt6Core.dll" (
    echo Detected dynamic Qt build -- copying DLLs and plugins...
    xcopy /s /y /q "%BUILD_ABS%\*.dll" "%STAGING%\" >nul 2>&1
    if exist "%BUILD_ABS%\platforms" xcopy /s /y /q /i "%BUILD_ABS%\platforms" "%STAGING%\platforms" >nul 2>&1
    if exist "%BUILD_ABS%\imageformats" xcopy /s /y /q /i "%BUILD_ABS%\imageformats" "%STAGING%\imageformats" >nul 2>&1
    if exist "%BUILD_ABS%\iconengines" xcopy /s /y /q /i "%BUILD_ABS%\iconengines" "%STAGING%\iconengines" >nul 2>&1
    if exist "%BUILD_ABS%\styles" xcopy /s /y /q /i "%BUILD_ABS%\styles" "%STAGING%\styles" >nul 2>&1
    if exist "%BUILD_ABS%\tls" xcopy /s /y /q /i "%BUILD_ABS%\tls" "%STAGING%\tls" >nul 2>&1
    if exist "%BUILD_ABS%\qml" xcopy /s /y /q /i "%BUILD_ABS%\qml" "%STAGING%\qml" >nul 2>&1
    REM Copy VC runtime DLLs if present
    for %%f in ("%BUILD_ABS%\vcruntime*.dll" "%BUILD_ABS%\msvcp*.dll" "%BUILD_ABS%\concrt*.dll") do (
        if exist "%%f" copy /y "%%f" "%STAGING%\" >nul
    )
)

REM ---- Copy manifest and assets ----
echo Copying manifest and assets...
copy /y "%PKG_DIR%AppxManifest.xml" "%STAGING%\" >nul
xcopy /s /y /q "%PKG_DIR%Assets\*" "%STAGING%\Assets\" >nul

REM ---- Build MSIX ----
echo.
echo Building MSIX package...
if exist "%OUTPUT%" del /q "%OUTPUT%"
"%MAKEAPPX%" pack /d "%STAGING%" /p "%OUTPUT%" /o
if errorlevel 1 (
    echo.
    echo ERROR: MakeAppx pack failed.
    exit /b 1
)

echo.
echo MSIX package created: %OUTPUT%

REM ---- Optional: Sign with test certificate ----
if "%SIGN_PACKAGE%"=="1" (
    if "%SIGNTOOL%"=="" (
        echo WARNING: SignTool.exe not found -- skipping signing.
        goto :skip_sign
    )

    set "CERT_PFX=%PKG_DIR%test-cert.pfx"
    set "CERT_PASS=CopilotCatTest"

    REM Create self-signed cert if it does not exist
    if not exist "!CERT_PFX!" (
        echo.
        echo Creating self-signed test certificate...
        powershell -Command ^
            "$cert = New-SelfSignedCertificate -Type Custom -Subject 'CN=PLACEHOLDER' -KeyUsage DigitalSignature -FriendlyName 'Copilot Cat Test' -CertStoreLocation 'Cert:\CurrentUser\My' -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}'); Export-PfxCertificate -Cert $cert -FilePath '!CERT_PFX!' -Password (ConvertTo-SecureString -String '!CERT_PASS!' -Force -AsPlainText)"
        if errorlevel 1 (
            echo WARNING: Certificate creation failed. Run as Administrator or create manually.
            goto :skip_sign
        )
    )

    echo Signing MSIX with test certificate...
    "%SIGNTOOL%" sign /fd SHA256 /a /f "!CERT_PFX!" /p "!CERT_PASS!" "%OUTPUT%"
    if errorlevel 1 (
        echo WARNING: Signing failed. The unsigned MSIX is still usable for Store submission.
    ) else (
        echo Package signed successfully with test certificate.
    )
)
:skip_sign

REM ---- Clean up staging ----
echo Cleaning up staging directory...
rmdir /s /q "%STAGING%"

REM ---- Print next steps ----
echo.
echo ============================================================
echo  Next Steps
echo ============================================================
echo.
echo  LOCAL TESTING (sideload):
echo    1. Enable Developer Mode in Windows Settings
echo    2. If unsigned, sign with: pkg\make_msix.cmd %BUILD_DIR% /sign
echo    3. Install the test cert: double-click pkg\test-cert.pfx
echo       Install to Local Machine ^> Trusted People store
echo    4. Double-click pkg\copilot-cat.msix to install
echo.
echo  MICROSOFT STORE SUBMISSION:
echo    1. Create an app in Partner Center:
echo       https://partner.microsoft.com/dashboard
echo    2. Update pkg\AppxManifest.xml:
echo       - Set Identity Name to reserved app name
echo       - Set Publisher to your publisher ID (CN=...)
echo       - Set PublisherDisplayName to your publisher name
echo    3. Replace placeholder icons in pkg\Assets\ with real artwork
echo    4. Rebuild: pkg\make_msix.cmd %BUILD_DIR%
echo    5. Upload pkg\copilot-cat.msix to Partner Center
echo.
echo  Note: Store submission does NOT require local signing --
echo  Microsoft signs the package during certification.
echo ============================================================

endlocal
