import 'package:flutter/material.dart';
import '../models/expert.dart';
import '../services/api_service.dart';
import 'add_expert_screen.dart';
import '../widgets/expert_card.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Expert> experts = [];

  void _loadExperts() async {
    final data = await ApiService.getExperts();
    setState(() => experts = data);
  }

  @override
  void initState() {
    super.initState();
    _loadExperts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddExpertScreen()),
              );
              _loadExperts();
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: experts.length,
        itemBuilder: (context, index) {
          final expert = experts[index];
          return ExpertCard(
            expert: expert,
            onDelete: () async {
              await ApiService.deleteExpert(expert.id!);
              _loadExperts();
            },
          );
        },
      ),
    );
  }
}
