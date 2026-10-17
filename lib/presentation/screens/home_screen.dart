import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yorisoi')),
      body: const Center(
        child: Text('今日はどんな気分ですか？'),
      ),
    );
  }
}
