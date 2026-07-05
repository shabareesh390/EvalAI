import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  double _classAverage = 0.0;
  double _highestScore = 0.0;
  double _lowestScore  = 0.0;
  double _passPercent  = 0.0;

  List<BarData> _barData = [
    BarData(range: '0-20',  count: 0,  color: AppColors.error),
    BarData(range: '21-40', count: 0,  color: AppColors.warning),
    BarData(range: '41-60', count: 0,  color: AppColors.info),
    BarData(range: '61-80', count: 0, color: AppColors.primary),
    BarData(range: '81-100',count: 0, color: AppColors.success),
  ];

  List<PieData> _pieData = [];
  List<_MistakeItem> _mistakes = [];

  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final firestoreService = FirestoreService();
      final evals = await firestoreService.fetchAllEvaluationsForTeacher(user.uid);

      if (evals.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      double totalPercentage = 0;
      double maxScore = 0;
      double minScore = 100;
      int passCount = 0;

      int b0_20 = 0, b21_40 = 0, b41_60 = 0, b61_80 = 0, b81_100 = 0;
      Map<String, List<double>> examScores = {};

      for (var eval in evals) {
        double pct = eval.percentage;
        totalPercentage += pct;
        if (pct > maxScore) maxScore = pct;
        if (pct < minScore) minScore = pct;
        if (eval.isPassed) passCount++;

        if (pct <= 20) {
          b0_20++;
        } else if (pct <= 40) {
          b21_40++;
        } else if (pct <= 60) {
          b41_60++;
        } else if (pct <= 80) {
          b61_80++;
        } else {
          b81_100++;
        }

        if (!examScores.containsKey(eval.examName)) {
          examScores[eval.examName] = [];
        }
        examScores[eval.examName]!.add(pct);
      }

      // Bar Chart
      final newBarData = [
        BarData(range: '0-20',  count: b0_20,  color: AppColors.error),
        BarData(range: '21-40', count: b21_40,  color: AppColors.warning),
        BarData(range: '41-60', count: b41_60,  color: AppColors.info),
        BarData(range: '61-80', count: b61_80, color: AppColors.primary),
        BarData(range: '81-100',count: b81_100, color: AppColors.success),
      ];

      // Pie Chart
      final List<Color> pieColors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.error, AppColors.info];
      final List<PieData> newPieData = [];
      int colorIndex = 0;
      examScores.forEach((examName, scores) {
        double avg = scores.reduce((a, b) => a + b) / scores.length;
        newPieData.add(PieData(subject: examName, percentage: avg, color: pieColors[colorIndex % pieColors.length]));
        colorIndex++;
      });

      // Weaknesses (Extract top 3 recent)
      final List<_MistakeItem> newMistakes = [];
      for (var eval in evals) {
        for (var q in eval.questionResults) {
          if (q.weaknesses.trim().isNotEmpty && q.weaknesses.length > 5) {
             if (newMistakes.length < 3) {
                newMistakes.add(_MistakeItem(
                  question: eval.examName.isNotEmpty ? eval.examName : 'Exam',
                  mistake: q.weaknesses,
                  impact: 'High',
                  color: AppColors.error,
                ));
             }
          }
        }
      }

      if (mounted) {
        setState(() {
          _classAverage = totalPercentage / evals.length;
          _highestScore = maxScore;
          _lowestScore = evals.isNotEmpty ? minScore : 0.0;
          _passPercent = (passCount / evals.length) * 100;
          _barData = newBarData;
          _pieData = newPieData;
          _mistakes = newMistakes;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Error fetching analytics: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Analytics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [

          _buildSummaryCards(),

          const SizedBox(height: 28),


          Text('Marks Distribution', style: AppTextStyles.headlineMedium)
              .animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

          _buildBarChart(),

          const SizedBox(height: 28),


          Text('Subject Performance', style: AppTextStyles.headlineMedium)
              .animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 16),

          _buildPieChart(),

          const SizedBox(height: 28),


          Text('Common Mistakes', style: AppTextStyles.headlineMedium)
              .animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 16),

          _buildCommonMistakes(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }


  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        _buildSummaryCard(
          label: 'Class Average',
          value: '${_classAverage.toStringAsFixed(1)}%',
          icon: Icons.bar_chart_rounded,
          color: AppColors.primary,
          bgColor: AppColors.primary.withValues(alpha: 0.08),
          delay: 0,
        ),
        _buildSummaryCard(
          label: 'Highest Score',
          value: '${_highestScore.toInt()}%',
          icon: Icons.emoji_events_outlined,
          color: AppColors.success,
          bgColor: AppColors.successLight,
          delay: 100,
        ),
        _buildSummaryCard(
          label: 'Lowest Score',
          value: '${_lowestScore.toInt()}%',
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
          bgColor: AppColors.errorLight,
          delay: 200,
        ),
        _buildSummaryCard(
          label: 'Pass Rate',
          value: '${_passPercent.toInt()}%',
          icon: Icons.check_circle_outline,
          color: AppColors.warning,
          bgColor: AppColors.warningLight,
          delay: 300,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.numericMedium),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
      delay: Duration(milliseconds: delay),
      duration: 400.ms,
    )
        .slideY(begin: 0.3, end: 0);
  }


  Widget _buildBarChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score Range Distribution', style: AppTextStyles.titleMedium),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 20,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${_barData[groupIndex].count} students',
                        AppTextStyles.caption.copyWith(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: AppTextStyles.caption,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < _barData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _barData[index].range,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _barData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.count.toDouble(),
                        color: entry.value.color,
                        width: 32,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms, duration: 400.ms);
  }


  Widget _buildPieChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedPieIndex = -1;
                        return;
                      }
                      _touchedPieIndex = pieTouchResponse
                          .touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: _pieData.asMap().entries.map((entry) {
                  final isTouched = entry.key == _touchedPieIndex;
                  return PieChartSectionData(
                    value: entry.value.percentage,
                    color: entry.value.color,
                    radius: isTouched ? 80 : 65,
                    title: '${entry.value.percentage.toInt()}%',
                    titleStyle: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontSize: isTouched ? 14 : 12,
                    ),
                  );
                }).toList(),
                sectionsSpace: 3,
                centerSpaceRadius: 40,
              ),
            ),
          ),

          const SizedBox(height: 16),


          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _pieData.map((data) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: data.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(data.subject, style: AppTextStyles.caption),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms, duration: 400.ms);
  }


  Widget _buildCommonMistakes() {
    if (_mistakes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
        ),
        child: const Center(
          child: Text('No common mistakes identified yet.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ).animate().fadeIn(delay: 350.ms, duration: 400.ms);
    }

    return Column(
      children: _mistakes.asMap().entries.map((entry) {
        final mistake = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mistake.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mistake.question, style: AppTextStyles.titleMedium),
                      const SizedBox(height: 4),
                      Text(mistake.mistake, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: mistake.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mistake.impact,
                    style: AppTextStyles.caption.copyWith(
                      color: mistake.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(
            delay: Duration(milliseconds: 450 + (entry.key * 100)),
            duration: 400.ms,
          )
              .slideX(begin: 0.2, end: 0),
        );
      }).toList(),
    );
  }
}


class BarData {
  final String range;
  final int count;
  final Color color;
  BarData({required this.range, required this.count, required this.color});
}

class PieData {
  final String subject;
  final double percentage;
  final Color color;
  PieData({required this.subject, required this.percentage, required this.color});
}

class _MistakeItem {
  final String question;
  final String mistake;
  final String impact;
  final Color color;
  _MistakeItem({
    required this.question,
    required this.mistake,
    required this.impact,
    required this.color,
  });
}
