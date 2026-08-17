import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/library_screen.dart';
import 'ui/theme.dart';

class PlayerApp extends StatelessWidget {
  const PlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.bgBase,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    return MaterialApp(
      title: 'Pomento',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LibraryScreen(),
    );
  }
}
