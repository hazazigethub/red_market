// panel/lib/features/admin/payment_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminPaymentDashboard extends ConsumerStatefulWidget {
  const AdminPaymentDashboard({super.key});

  @override
  ConsumerState<AdminPaymentDashboard> createState() => _AdminPaymentDashboardState();
}

class _AdminPaymentDashboardState extends ConsumerState<AdminPaymentDashboard> {
  late String _selectedPeriod = '7days';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المدفوعات'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ========== عدادات رئيسية ==========
              _buildKPICards(),
              const SizedBox(height: 32),

              // ========== الرسوم البيانية ==========
              _buildPaymentsChart(),
              const SizedBox(height: 32),

              // ========== جدول آخر المدفوعات ==========
              _buildRecentPaymentsTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPICards() {
    return Row(
      children: [
        _buildKPICard(
          title: 'إجمالي المدفوعات',
          value: '0.00 ر.س',
          icon: Icons.account_balance_wallet,
          color: Colors.green,
        ),
        const SizedBox(width: 16),
        _buildKPICard(
          title: 'عدد المعاملات',
          value: '0',
          icon: Icons.trending_up,
          color: Colors.blue,
        ),
        const SizedBox(width: 16),
        _buildKPICard(
          title: 'معدل النجاح',
          value: '0%',
          icon: Icons.check_circle,
          color: Colors.orange,
        ),
        const SizedBox(width: 16),
        _buildKPICard(
          title: 'المعاملات الفاشلة',
          value: '0',
          icon: Icons.error,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEDEFF3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF757575),
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الاتجاهات المالية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEDEFF3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    const FlSpot(0, 3),
                    const FlSpot(1, 2),
                    const FlSpot(2, 5),
                    const FlSpot(3, 3.1),
                    const FlSpot(4, 4),
                    const FlSpot(5, 5.5),
                    const FlSpot(6, 4),
                  ],
                  isCurved: true,
                  color: AppColors.brand,
                  dotData: FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPaymentsTable() {
    final supabase = Supabase.instance.client;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'آخر المدفوعات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchRecentPayments(supabase),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final payments = snapshot.data ?? [];

            if (payments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFEDEFF3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'لا توجد مدفوعات',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFEDEFF3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  dataRowHeight: 56,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'معرّف الدفعة',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'التاجر',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'المبلغ',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'النوع',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الحالة',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'التاريخ',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: payments
                    .map((payment) => _buildPaymentRow(payment))
                    .toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  DataRow _buildPaymentRow(Map<String, dynamic> payment) {
    final status = payment['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final total = (payment['total_amount'] ?? 0).toDouble();
    final date = DateTime.parse(payment['created_at'] ?? DateTime.now().toIso8601String());

    return DataRow(
      cells: [
        DataCell(
          Text(
            (payment['id'] as String).substring(0, 8),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            'تاجر ${(payment['merchant_id'] as String).substring(0, 8)}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            '${total.toStringAsFixed(2)} ر.س',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(
          Text(
            _getPaymentTypeText(payment['payment_type']),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(51),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getStatusText(status),
              style: TextStyle(
                fontFamily: 'Cairo',
                color: statusColor,
                fontSize: 11,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            DateFormat('dd/MM/yyyy HH:mm', 'ar').format(date),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentPayments(
    SupabaseClient supabase,
  ) async {
    try {
      final payments = await supabase
        .from('payments')
        .select()
        .order('created_at', ascending: false)
        .limit(20);

      return List<Map<String, dynamic>>.from(payments);
    } catch (e) {
      debugPrint('خطأ جلب المدفوعات: $e');
      return [];
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'processing':
        return 'جاري المعالجة';
      case 'completed':
        return 'مكتملة';
      case 'failed':
        return 'فاشلة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  String _getPaymentTypeText(String type) {
    switch (type) {
      case 'subscription':
        return 'اشتراك';
      case 'banner_booking':
        return 'حجز بنر';
      case 'splash_ad':
        return 'إعلان الشاشة';
      default:
        return type;
    }
  }
}
