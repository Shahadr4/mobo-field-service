import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/const/app_colors.dart';
import '../model/employee_model.dart';
import '../model/employee_stats_model.dart';
import '../service/employee_stats_service.dart';
import '../widgets/detail/employee_contact_card.dart';
import '../widgets/detail/employee_detail_shimmer.dart';
import '../widgets/detail/employee_donut_chart.dart';
import '../widgets/detail/employee_hero_card.dart';
import '../widgets/detail/employee_hours_row.dart';
import '../widgets/detail/employee_stats_grid.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final AssigneeModel assignee;
  const EmployeeDetailScreen({super.key, required this.assignee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final _service = EmployeeStatsService();
  EmployeeStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _service.fetchStats(widget.assignee.id);
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final stats = await _service.fetchStats(widget.assignee.id);
    if (mounted) setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        title: Text(
          'Employee Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _refresh,
        child: _isLoading
            ? const EmployeeDetailShimmer()
            : _Body(
                assignee: widget.assignee,
                stats: _stats ?? const EmployeeStats.empty(),
                isDark: isDark,
                cardBg: cardBg,
                shadow: shadow,
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AssigneeModel assignee;
  final EmployeeStats stats;
  final bool isDark;
  final Color cardBg;
  final BoxShadow shadow;

  const _Body({
    required this.assignee,
    required this.stats,
    required this.isDark,
    required this.cardBg,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeeHeroCard(
            assignee: assignee,
            isDark: isDark,
            cardBg: cardBg,
            shadow: shadow,
          ),
          const SizedBox(height: 16),
          EmployeeContactCard(
            assignee: assignee,
            isDark: isDark,
            cardBg: cardBg,
            shadow: shadow,
          ),
          const SizedBox(height: 20),
          Text(
            'Field Service Overview',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          EmployeeDonutChart(
            stats: stats,
            isDark: isDark,
            cardBg: cardBg,
            shadow: shadow,
          ),
          const SizedBox(height: 16),
          EmployeeHoursRow(
            stats: stats,
            isDark: isDark,
            cardBg: cardBg,
            shadow: shadow,
          ),
          const SizedBox(height: 12),



          EmployeeStatsGrid(stats: stats),

        ],
      ),
    );
  }
}
