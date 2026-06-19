import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // ── Mock data — will be replaced with Firestore data ──────────────────
  final double _classAverage = 72.5;
  final double _highestScore = 95.0;
  final double _lowestScore  = 38.0;
  final double _passPercent  = 78.0;

  // Bar chart data — marks distribution
  final List<BarData> _barData = [
    BarData(range: '0-20',  count: 2,  color: AppColors.error),
    BarData(range: '21-40', count: 4,  color: AppColors.warning),
    BarData(range: '41-60', count: 8,  color: AppColors.info),
    BarData(range: '61-80', count: 15, color: AppColors.primary),
    BarData(range: '81-100',count: 11, color: AppColors.success),
  ];

  // Pie chart data — subject performance
  final List<PieData> _pieData = [
    PieData(subject: 'Physics',   percentage: 72, color: AppColors.primary),
    PieData(subject: 'Chemistry', percentage: 68, color: AppColors.success),
    PieData(subject: 'Maths',     percentage: 81, color: AppColors.warning),
    PieData(subject: 'Biology',   percentage: 65, color: AppColors.error),
  ];

  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Summary Cards ──────────────────────────────────────────────
          _buildSummaryCards(),

          const SizedBox(height: 28),

          // ── Marks Distribution ─────────────────────────────────────────
          Text('Marks Distribution', style: AppTextStyles.headlineMedium)
              .animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

          _buildBarChart(),

          const SizedBox(height: 28),

          // ── Subject Performance ────────────────────────────────────────
          Text('Subject Performance', style: AppTextStyles.headlineMedium)
              .animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 16),

          _buildPieChart(),

          const SizedBox(height: 28),

          // ── Common Mistakes ────────────────────────────────────────────
          Text('Common Mistakes', style: AppTextStyles.headlineMedium)
              .animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 16),

          _buildCommonMistakes(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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

  // ── Bar Chart ──────────────────────────────────────────────────────────
  Widget _buildBarChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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

  // ── Pie Chart ──────────────────────────────────────────────────────────
  Widget _buildPieChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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

          // Legend
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

  // ── Common Mistakes ────────────────────────────────────────────────────
  Widget _buildCommonMistakes() {
    final mistakes = [
      _MistakeItem(
        question: 'Question 3',
        mistake: '78% of students missed the chemical equation',
        impact: 'High',
        color: AppColors.error,
      ),
      _MistakeItem(
        question: 'Question 5',
        mistake: '65% of students skipped diagram labels',
        impact: 'Medium',
        color: AppColors.warning,
      ),
      _MistakeItem(
        question: 'Question 7',
        mistake: '45% of students gave incomplete definitions',
        impact: 'Low',
        color: AppColors.info,
      ),
    ];

    return Column(
      children: mistakes.asMap().entries.map((entry) {
        final mistake = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
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

// ── Local Data Models ──────────────────────────────────────────────────────
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