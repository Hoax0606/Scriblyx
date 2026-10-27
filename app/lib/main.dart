import 'package:flutter/material.dart';

import 'config/dependencies.dart';
import 'ui/home/widgets/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  runApp(ScriblyxApp(dependencies: dependencies));
}

class ScriblyxApp extends StatelessWidget {
  const ScriblyxApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scriblyx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B6EA5),
      ),
      home: HomeScreen(
        listViewModel: dependencies.listViewModel,
        editViewModel: dependencies.editViewModel,
        buildEditor: dependencies.editorFactory.buildEditor,
      ),
    );
  }
}
