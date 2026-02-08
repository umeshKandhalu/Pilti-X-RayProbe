# Clinical Decision Support System - Setup Guide

## 1. Environment Verification

We have installed a **local version of Flutter** in the `tools/` directory to avoid system conflicts.
You do NOT need to install Flutter globally.

Ensure you have run `xcode-select --install` successfully (which you confirmed).

## 2. Dependencies
You should have Homebrew installed (if not, the script `install_dependencies.sh` attempted it).
For the app, we use the local Flutter SDK.

## 3. Run the Backend

Open a new terminal window:
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```
The API will run at `http://127.0.0.1:8000`.

## 4. Run the Mobile App

Open a **separate** terminal window:
```bash
cd app
# Run using the local Flutter SDK
../tools/flutter/bin/flutter run
```

### Run on Web
To run the web version (even without Chrome/Edge installed locally):
```bash
../tools/flutter/bin/flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```
Access it at `http://localhost:8080`.

*Note: The backend API (127.0.0.1) might be blocked by browser CORS policies when running on web. You may need to handle CORS in the backend or use a proxy.*

## 5. Troubleshooting
If `flutter run` fails with signing errors on iOS, open `ios/Runner.xcworkspace` in Xcode and select your Development Team in Signing & Capabilities.
