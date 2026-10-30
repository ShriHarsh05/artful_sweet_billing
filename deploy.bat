@echo off
echo ========================================================
echo   Deploying RASHI ENTERPRISES Biller to Firebase Hosting
echo   Target: https://artful-sweets-billing.web.app
echo ========================================================
echo.
call C:\Users\670371973\AppData\Roaming\npm\firebase.cmd deploy --only hosting
echo.
pause
