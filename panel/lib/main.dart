import 'app.dart';
import 'features/merchant/merchant_dashboard.dart';

/// مدخل لوحة التاجر — panel.redmarket.pro
Future<void> main() =>
    runPanel(role: 'merchant', dashboard: buildMerchantDashboard);
