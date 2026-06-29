import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final Icon icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: .min,
          children: <Widget>[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                child: icon,
              ),
              title: Text(title),
              subtitle: Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
