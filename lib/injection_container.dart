import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/database_helper.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  
  // Database
  final databaseHelper = DatabaseHelper();
  await databaseHelper.initDatabase();
  sl.registerLazySingleton(() => databaseHelper);
  
  // سيتم إضافة باقي التسجيلات لاحقاً
}
