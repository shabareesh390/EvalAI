<img width="3264" height="3264" alt="1000324602" src="https://github.com/user-attachments/assets/f5358582-cc22-416a-8dcc-fe746bcd22d8" />
# EvalAI

An intelligent Flutter application for evaluating student exams using Google Gemini AI.

## Features
- Exam extraction from Key Answer PDFs
- Automated evaluation and grading using Gemini AI
- Secure Firebase authentication and storage

## Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone <repository_url>
   cd evalai
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**
   - Copy `.env.example` to `.env`.
   - Update `.env` with your own `GEMINI_API_KEY`, `FIREBASE_WEB_API_KEY`, and `FIREBASE_ANDROID_API_KEY`.

4. **Firebase Configuration:**
   - Place your `google-services.json` in `android/app/` (for Android).
   - Place your `GoogleService-Info.plist` in `ios/Runner/` (for iOS).

5. **Run the App:**
   ```bash
   flutter run
   ```

## Security Note
This project reads sensitive API keys from the `.env` file via `flutter_dotenv`. Never commit your `.env`, `google-services.json`, or `GoogleService-Info.plist` files to version control.
