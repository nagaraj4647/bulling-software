import 'package:flutter/material.dart';

class ReportPaginationFooter extends StatelessWidget {
  final bool hasMore;
  final bool isLoadingMore;
  final int totalLoaded;
  final VoidCallback onLoadMore;

  const ReportPaginationFooter({
    super.key,
    required this.hasMore,
    required this.isLoadingMore,
    required this.totalLoaded,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore && totalLoaded > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'Showing all $totalLoaded records',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }

    if (!hasMore) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: isLoadingMore
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.arrow_downward, size: 18),
                label: const Text('Load More (20 records)'),
              ),
      ),
    );
  }
}
