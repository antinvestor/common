import 'package:flutter/material.dart';

import 'breadcrumb.dart';

/// Standard page header with breadcrumb and title.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.breadcrumbs,
    this.actions,
  });

  final String title;
  final List<String> breadcrumbs;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Breadcrumb(items: breadcrumbs),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ],
    );
  }
}
