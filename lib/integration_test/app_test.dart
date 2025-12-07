// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prayer_times_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App creates main screen without crashing', (tester) async {
    // تشغيل التطبيق
    app.main();
    // الانتظار حتى تستقر الواجهة (وهذا يكفي لكشف انهيار الإقلاع)
    await tester.pumpAndSettle();

    // التحقق من ظهور عنصر معين (اختياري)
    expect(find.text('أوقات الصلاة'), findsOneWidget);
  });
}
