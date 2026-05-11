import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/example_field_delay_provider.dart';
import '../model/product_model.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';

class ExampleFieldDelayPage extends StatefulWidget {
  const ExampleFieldDelayPage({super.key});

  @override
  State<ExampleFieldDelayPage> createState() => _ExampleFieldDelayPageState();
}

class _ExampleFieldDelayPageState extends State<ExampleFieldDelayPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExampleFieldDelayProvider>().loadProducts();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final provider = context.read<ExampleFieldDelayProvider>();
    if (!provider.hasMore || provider.isLoading || provider.isLoadingMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      provider.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExampleFieldDelayProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Example Field Delay'),
        actions: [
          // Pagination controls on AppBar
          Builder(
            builder: (context) {
              final provider = context.watch<ExampleFieldDelayProvider>();
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final start = (provider.offset - provider.products.length + 1).clamp(1, provider.offset == 0 ? 1 : provider.offset);
              final end = provider.offset;
              final paginationText = '${start}-${end}';

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PaginationControls(
                  canGoToPreviousPage: provider.offset > provider.limit && !provider.isLoading,
                  canGoToNextPage: provider.hasMore && !provider.isLoading,
                  onPreviousPage: () => context.read<ExampleFieldDelayProvider>().prevPage(),
                  onNextPage: () => context.read<ExampleFieldDelayProvider>().nextPage(),
                  paginationText: paginationText,
                  isDark: isDark,
                  theme: theme,
                ),
              );
            },
          ),
          IconButton(
            onPressed: () =>
                context.read<ExampleFieldDelayProvider>().refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(ExampleFieldDelayProvider state, ThemeData theme) {
    if (state.isLoading && state.products.isEmpty) {
      return ListShimmer.buildListShimmer(
        context,
        itemCount: 10,
        type: ShimmerType.product,
      );
    }

    if (state.error != null && state.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading products', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  context.read<ExampleFieldDelayProvider>().refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ExampleFieldDelayProvider>().refresh(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        // +1 for footer (loading/error/end)
        itemCount: state.products.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index < state.products.length) {
            final product = state.products[index];
            return _ProductCard(product: product);
          }

          // Footer
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.loadMoreError != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Failed to load more: ${state.loadMoreError}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<ExampleFieldDelayProvider>().loadMore(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!state.hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No more products',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            );
          }

          // Default spacer if nothing to show in footer yet
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = product.displayName.isNotEmpty
        ? product.displayName
        : product.name;
    final code = product.defaultCode;
    final price = product.listPrice.toString();
    final qty = product.qtyAvailable.toString();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: product.image128 != null && product.image128 != ''
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(product.image128!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(Icons.image_outlined, color: theme.hintColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (code.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      code,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$$price',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(
                            0.3,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Qty: $qty',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
