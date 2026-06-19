import 'package:flutter/material.dart';
import '../../features/authentication/screens/splash_screen.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/signup_screen.dart';
import '../../features/authentication/screens/forgot_password_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/settings_screen.dart';
import '../../features/exam/screens/upload_sheets_screen.dart';
import '../../features/exam/screens/student_management_screen.dart';
import '../../features/evaluation/screens/ocr_screen.dart';
import '../../features/evaluation/screens/evaluation_screen.dart';
import '../../features/evaluation/screens/evaluate_student_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../core/models/question_model.dart';
import '../../features/students/screens/bulk_add_students_screen.dart';
import '../../features/exam/screens/create_exam_screen.dart'; // The new AI Exam Screen

class AppRoutes {
  AppRoutes._();
  static const String splash              = '/';
  static const String login               = '/login';
  static const String signup              = '/signup';
  static const String forgotPassword      = '/forgot-password';
  static const String dashboard           = '/dashboard';
  static const String createExam          = '/create-exam';
  static const String uploadSheets        = '/upload-sheets';
  static const String ocrProcessing       = '/ocr-processing';
  static const String evaluation          = '/evaluation';
  static const String evaluateStudent     = '/evaluate-student';
  static const String results             = '/results';
  static const String analytics           = '/analytics';
  static const String settings            = '/settings';
  static const String studentManagement   = '/students';
  static const String bulkAddStudents     = '/bulk-add-students'; // New Route Added!
}

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _buildRoute(const SplashScreen(), settings);
      case AppRoutes.login:
        return _buildRoute(const LoginScreen(), settings);
      case AppRoutes.signup:
        return _buildRoute(const SignupScreen(), settings);
      case AppRoutes.forgotPassword:
        return _buildRoute(const ForgotPasswordScreen(), settings);
      case AppRoutes.dashboard:
        return _buildRoute(const DashboardScreen(), settings);
      case AppRoutes.settings:
        return _buildRoute(const SettingsScreen(), settings);
      case AppRoutes.createExam:
        return _buildRoute(const CreateExamScreen(), settings);
      case AppRoutes.uploadSheets:
        return _buildRoute(const UploadSheetsScreen(), settings);
      case AppRoutes.studentManagement:
        return _buildRoute(const StudentManagementScreen(), settings);
      case AppRoutes.bulkAddStudents: // New Switch Case Added!
        return _buildRoute(const BulkAddStudentsScreen(), settings);
      case AppRoutes.ocrProcessing:
        return _buildRoute(const OcrScreen(), settings);
      case AppRoutes.evaluateStudent:
        return _buildRoute(const EvaluateStudentScreen(), settings);
      case AppRoutes.evaluation:
        final args = settings.arguments as Map<String, dynamic>;
        return _buildRoute(
          EvaluationScreen(
            questions: args['questions'] as List<QuestionModel>,
            extractedText: args['extractedText'] as String,
          ),
          settings,
        );
      case AppRoutes.analytics:
        return _buildRoute(const AnalyticsScreen(), settings);
      default:
        return _buildRoute(
          const Scaffold(body: Center(child: Text('Route not found'))),
          settings,
        );
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(
      Widget page, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}