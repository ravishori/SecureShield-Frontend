@echo off
echo ========================================
echo SecureShield AI - Build Test
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Flutter Clean
flutter clean
echo.

echo Step 2: Get Dependencies
flutter pub get
echo.

echo Step 3: Run Flutter
flutter run
echo.

pause
