import 'package:annoto/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  static const routeName = '/processing';

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Processing',
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('The extraction pipeline state will be shown here.'),
          ],
        ),
      ),
    );
  }
}
