import 'app.dart';
import 'features/admin/admin_dashboard.dart';

/// مدخل لوحة الإدارة — admin.redmarket.pro
Future<void> main() =>
    runPanel(role: 'super_admin', dashboard: buildAdminDashboard);
