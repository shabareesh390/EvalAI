import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'features/exam/providers/exam_provider.dart';
import 'features/exam/providers/student_provider.dart';
import 'features/evaluation/providers/evaluation_provider.dart';

class EvalAIApp extends StatelessWidget {
  const EvalAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ExamProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => EvaluationProvider()),
      ],
      child: MaterialApp(
        title: 'EvalAI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: AppRoutes.splash,
      ),
    );
  }
}