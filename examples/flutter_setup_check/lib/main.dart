import 'package:flutter/material.dart';

import 'packages.dart';

void main() => runApp(const SetupCheckApp());

class SetupCheckApp extends StatelessWidget {
  const SetupCheckApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: SetupCheckPage());
}

class SetupCheckPage extends StatefulWidget {
  const SetupCheckPage({super.key});
  @override
  State<SetupCheckPage> createState() => _SetupCheckPageState();
}

class _SetupCheckPageState extends State<SetupCheckPage> {
  final controller = TextEditingController();
  String preview = 'まだ入力を確認していません';
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yorisoi 開発環境チェック')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('選定SDK: ${packageChecks.length}種類'),
        const Text('SDKのimportとFlutter UIを確認するサンプルです。API接続・音声機能の成功を示しません。'),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '日本語入力テスト'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            setState(
              () => preview = text.isEmpty ? 'テキストを入力してください' : '入力確認: $text',
            );
          },
          child: const Text('入力を確認'),
        ),
        SelectableText(preview),
        for (final package in packageChecks)
          ListTile(title: Text(package.name), subtitle: Text(package.purpose)),
      ],
    ),
  );
}
