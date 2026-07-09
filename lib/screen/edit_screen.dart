import 'package:flutter/material.dart';

class EditScreen extends StatefulWidget {
  const EditScreen({super.key});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Edit'),
            actions: [
              IconButton(icon: const Icon(Icons.save), onPressed: () {}),
            ],
          ),
          SliverList(delegate: SliverChildListDelegate([const Text('Edit')])),
        ],
      ),
    );
  }
}
