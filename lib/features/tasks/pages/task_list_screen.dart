import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/task_provider.dart';
import '../widgets/task_list_body.dart';
import '../widgets/task_search_bar.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const _TaskListScreenWrapper());

  @override
  Widget build(BuildContext context) => const _TaskListScreenWrapper();
}

class _TaskListScreenWrapper extends StatelessWidget {
  const _TaskListScreenWrapper();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskProvider()..init(),
      child: const _TaskListView(),
    );
  }
}

class _TaskListView extends StatefulWidget {
  const _TaskListView();

  @override
  State<_TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<_TaskListView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        TaskSearchBar(ctrl: _searchCtrl, isDark: isDark),
        const Expanded(child: TaskListBody()),
      ],
    );
  }
}
