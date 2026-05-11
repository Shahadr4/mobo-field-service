// // Example: How to create a screen that filters data by selected company
// // This is a reference implementation - adapt it to your needs
//
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/services/odoo_session_manager.dart';
// import '../../../shared/widgets/snackbars/custom_snackbar.dart';
// import '../providers/company_provider.dart';
// import '../mixins/company_aware_mixin.dart';
//
// /// Example screen showing how to filter data by company
// class CompanyFilteredScreenExample extends StatefulWidget {
//   const CompanyFilteredScreenExample({super.key});
//
//   @override
//   State<CompanyFilteredScreenExample> createState() =>
//       _CompanyFilteredScreenExampleState();
// }
//
// class _CompanyFilteredScreenExampleState
//     extends State<CompanyFilteredScreenExample> with CompanyAwareMixin {
//   List<Map<String, dynamic>> _data = [];
//   bool _loading = false;
//   String? _error;
//
//   @override
//   void initState() {
//     super.initState();
//     // Load data when screen initializes
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadData();
//     });
//   }
//
//   @override
//   void onCompanyChanged(int? newCompanyId) {
//     // This is automatically called when company changes
//     debugPrint('Company changed to: $newCompanyId, reloading data...');
//     _loadData();
//   }
//
//   Future<void> _loadData() async {
//     if (!mounted) return;
//
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//
//     try {
//       final companyId = getCurrentCompanyId();
//
//       if (companyId == null) {
//         setState(() {
//           _error = 'No company selected';
//           _loading = false;
//         });
//         return;
//       }
//
//       final client = await OdooSessionManager.getClientEnsured();
//
//       // Example: Fetch stock pickings for the selected company
//       final result = await client.callKw({
//         'model': 'stock.picking',
//         'method': 'search_read',
//         'args': [
//           [
//             ['company_id', '=', companyId], // Filter by company
//             ['state', 'not in', ['done', 'cancel']],
//           ],
//         ],
//         'kwargs': {
//           'fields': ['name', 'partner_id', 'state', 'scheduled_date'],
//           'limit': 50,
//           'order': 'scheduled_date desc',
//         },
//       });
//
//       if (!mounted) return;
//
//       setState(() {
//         _data = (result as List).cast<Map<String, dynamic>>();
//         _loading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//
//       setState(() {
//         _error = e.toString();
//         _loading = false;
//       });
//
//       CustomSnackbar.showError(
//         context,
//         'Failed to load data: ${e.toString()}',
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Company Filtered Data'),
//         actions: [
//           // Show current company
//           Consumer<CompanyProvider>(
//             builder: (context, provider, _) {
//               final company = provider.selectedCompany;
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: Center(
//                   child: Text(
//                     company?.name ?? 'No company',
//                     style: const TextStyle(fontSize: 12),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//       body: _buildBody(),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _loadData,
//         child: const Icon(Icons.refresh),
//       ),
//     );
//   }
//
//   Widget _buildBody() {
//     if (_loading) {
//       return const Center(
//         child: CircularProgressIndicator(),
//       );
//     }
//
//     if (_error != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, size: 48, color: Colors.red),
//             const SizedBox(height: 16),
//             Text('Error: $_error'),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _loadData,
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     if (_data.isEmpty) {
//       return const Center(
//         child: Text('No data available for this company'),
//       );
//     }
//
//     return RefreshIndicator(
//       onRefresh: _loadData,
//       child: ListView.builder(
//         itemCount: _data.length,
//         itemBuilder: (context, index) {
//           final item = _data[index];
//           return ListTile(
//             leading: const Icon(Icons.inventory_2),
//             title: Text(item['name'] ?? 'Unknown'),
//             subtitle: Text(
//               'State: ${item['state'] ?? 'N/A'}',
//             ),
//             trailing: Text(
//               item['scheduled_date']?.toString().substring(0, 10) ?? '',
//               style: const TextStyle(fontSize: 12),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
