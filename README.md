<img width="3264" height="3264" alt="1000324606" src="https://github.com/user-attachments/assets/6305d3ad-9e83-4751-81db-8bab7b467692" />
<img width="3264" height="3264" alt="1000324604" src="https://github.com/user-attachments/assets/8acdf368-6c26-403e-aa4b-935f9a84e8a6" />
<img width="3264" height="3264" alt="1000324605" src="https://github.com/user-attachments/assets/fdee322d-04f9-40c5-af85-b779667960c3" />
<img width="3264" height="3264" alt="1000324603" src="https://github.com/user-attachments/assets/70f9d250-2e6f-4c24-81c7-2c65196122e2" />
<img width="3264" height="3264" alt="1000324602" src="https://github.com/user-attachments/assets/cf04538e-c72e-4062-9ba4-db06484cac6e" />

<img width="3264" height="3264" alt="1000324606" src="https://github.com/user-attachments/assets/d0e5adb1-cee5-4543-8553-1a5d68366509" />
<img width="3264" height="3264" alt="1000324604" src="https://github.com/user-attachments/assets/ca5e96f5-c2c4-440e-bcf6-1ec218f466aa" />
<img width="3264" height="3264" alt="1000324603" src="https://github.com/user-attachments/assets/9dfc8d28-59b9-4510-b36d-01d25db5f30b" />
<img width="3264" height="3264" alt="1000324602" src="https://github.com/user-attachments/assets/fd576dbb-dd8f-4f23-9215-16b3ed4e0b25" />
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
