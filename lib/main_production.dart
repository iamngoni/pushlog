import 'package:pushlog/app/app.dart';
import 'package:pushlog/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
