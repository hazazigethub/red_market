import 'package:flutter/material.dart';
import '../../shell/dashboard_shell.dart';
import 'categories_page.dart';
import 'admin_home_page.dart';
import 'new_merchants_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_analytics_visits_screen.dart';
import 'admin_customer_screen.dart';
import 'admin_products_screen.dart';
import 'admin_merchants_screen.dart';
import 'admin_analytics_merchants_screen.dart';
import 'admin_analytics_products_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_newsletter_screen.dart';
import 'discount_codes_screen.dart';
import 'admin_analytics_customer_screen.dart';
import 'admin_analytics_merchant_categories_screen.dart';
import 'admin_analytics_product_categories_screen.dart';

/// لوحة الإدارة — مدخلها lib/main_admin.dart (admin.redmarket.pro)
/// لا تستورد أي شاشة من مجلد التاجر.
Widget buildAdminDashboard() {
  return DashboardShell(
    role: 'super_admin',
    items: const [
      NavItem('الرئيسية', Icons.dashboard, AdminHomePage()),
      NavItem('التصنيفات', Icons.category, AdminCategoriesScreen()),
      NavItem('إدارة العملاء', Icons.people, AdminUsersScreen()),
      NavItem('إدارة التجار', Icons.storefront, AdminMerchantsScreen()),
      NavItem(
        'التجار الجدد',
        Icons.fiber_new_outlined,
        NewMerchantsScreen(),
      ),
      NavItem('إدارة العروض', Icons.inventory, AdminProductsScreen()),
      NavItem(
        'تحليلات العملاء',
        Icons.analytics,
        AdminAnalyticsUsersScreen(),
      ),
      NavItem(
        'تصنيفات المتاجر',
        Icons.storefront,
        AdminAnalyticsMerchantCategoriesScreen(),
      ),
      NavItem(
        'تصنيفات العروض',
        Icons.inventory_2,
        AdminAnalyticsProductCategoriesScreen(),
      ),
      NavItem(
        'الإشعارات',
        Icons.notifications,
        AdminNotificationsScreen(),
      ),
      NavItem(
        'النشرة الأسبوعية',
        Icons.campaign,
        AdminNewsletterScreen(),
      ),
      NavItem('أكواد الخصم', Icons.local_offer, DiscountCodesScreen()),
      NavItem('التجار', Icons.store, AdminAnalyticsMerchantsScreen()),
      NavItem(
        'العروض',
        Icons.shopping_bag,
        AdminAnalyticsProductsScreen(),
      ),
      NavItem('البلاغات', Icons.flag, AdminReportsScreen()),
      NavItem(
        'الزيارات',
        Icons.trending_up,
        AdminAnalyticsVisitsScreen(),
      ),
      NavItem('البنرات', Icons.ad_units, AdminBannersScreen()),
      NavItem('الإعلانات', Icons.campaign, AdminAnnouncementsScreen()),
      NavItem('الإعدادات', Icons.settings, AdminSettingsScreen()),
    ],
  );
}
