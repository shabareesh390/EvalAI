import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routes/app_router.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/evalai.png',
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  .animate()
                  .scale(
                duration: 800.ms,
                curve: Curves.elasticOut,
              )
                  .fadeIn(duration: 500.ms),

              const SizedBox(height: 32),
              Text(
                'EvalAI',
                style: AppTextStyles.displayLarge.copyWith(
                  color: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

              const SizedBox(height: 12),
              Text(
                'Smart Evaluation, Simplified',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

              const SizedBox(height: 80),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
