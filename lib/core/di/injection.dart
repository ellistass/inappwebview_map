import 'package:get_it/get_it.dart';

import 'modules/directions_di.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  registerDirections(getIt);
}
