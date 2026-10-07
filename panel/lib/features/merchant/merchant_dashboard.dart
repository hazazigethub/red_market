import 'package:flutter/material.dart';
import '../../shell/dashboard_shell.dart';
import 'merchant_home_page.dart';
import 'manage_reels_page.dart';
import 'products_page.dart';
import 'merchant_reports_page.dart';
import 'merchant_promo_page.dart';
import 'merchant_subscriptions_page.dart';
import 'notifications_page.dart' as merchant_notif;
import 'useful_links_page.dart';
import 'store_settings_page.dart';
import 'merchant_bank_account_page.dart';

/// لوحة التاجر — مدخلها lib/main.dart (panel.redmarket.pro)
/// لا تستورد أي شاشة من مجلد الإدارة.
Widget buildMerchantDashboard() {
  return DashboardShell(
    role: 'merchant',
    items: const [
      NavItem('الرئيسية', Icons.dashboard, MerchantHomePage()),
      NavItem('عروضي', Icons.inventory_2, ProductsPage()),
      NavItem('الريلز', Icons.video_library, ManageReelsPage()),
      NavItem('التقارير', Icons.bar_chart, MerchantReportsPage()),
      NavItem('رسائل المتابعين', Icons.campaign, MerchantPromoPage()),
      NavItem(
        'الاشتراكات',
        Icons.card_membership,
        MerchantSubscriptionsPage(),
      ),
      NavItem(
        'الإشعارات',
        Icons.notifications,
        merchant_notif.NotificationsPage(),
      ),
      NavItem('إعدادات المتجر', Icons.settings, StoreSettingsPage()),
      NavItem(
        'الحساب البنكي',
        Icons.account_balance,
        MerchantBankAccountPage(),
      ),
      NavItem('روابط مفيدة', Icons.link, UsefulLinksPage()),
    ],
  );
}
