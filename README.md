<img width="3264" height="3264" alt="1000324602" src="https://github.com/user-attachments/assets/ca9e53f1-a237-4efc-8bf9-292c1f1a3ea8" />
<img width="3264" height="3264" alt="1000324603" src="https://github.com/user-attachments/assets/79b7c787-b339-4dd4-97de-304d8724b756" />
<img width="3264" height="3264" alt="1000324604" src="https://github.com/user-attachments/assets/4057c7f0-951b-48f3-881a-fc6bf7c6c0b8" />
<img width="3264" height="3264" alt="1000324605" src="https://github.com/user-attachments/assets/01937c91-ddb3-48d7-9312-351548266957" />
<img width="3264" height="3264" alt="1000324606" src="https://github.com/user-attachments/assets/462bf14f-5e5d-4939-a981-6ef925e1d620" />
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
