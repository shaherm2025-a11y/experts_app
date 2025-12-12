import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/expert.dart';

class ExpertCard extends StatelessWidget {
  final Expert expert;
  final VoidCallback onDelete;

  const ExpertCard({super.key, required this.expert, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(
          expert.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${expert.jobTitle} • ${expert.email}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              expert.canViewAll == 1
                  ? "👁️ يرى جميع الردود"
                  : "🙈 يرى فقط ردوده السابقة",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
