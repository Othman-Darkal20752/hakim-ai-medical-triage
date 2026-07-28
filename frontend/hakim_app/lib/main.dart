import 'package:flutter/material.dart';

import 'app.dart';
import 'core/localization/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocaleController.instance.initialize();

  runApp(const HakimApp());
}
