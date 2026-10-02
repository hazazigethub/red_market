// panel/lib/features/invoices/invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('يجب تسجيل الدخول')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ========== عدادات الإحصائيات ==========
              _buildStatsRow(context),
              const SizedBox(height: 24),

              // ========== جدول الفواتير ==========
              const Text(
                'قائمة الفواتير',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              _buildInvoicesTable(context, supabase, currentUser.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(
          title: 'إجمالي الفواتير',
          value: '0',
          icon: Icons.receipt,
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'المدفوعة',
          value: '0.00 ر.س',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'المعلقة',
          value: '0.00 ر.س',
          icon: Icons.pending,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEDEFF3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
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
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesTable(
    BuildContext context,
    SupabaseClient supabase,
    String userId,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchInvoices(supabase, userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'خطأ: ${snapshot.error}',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          );
        }

        final invoices = snapshot.data ?? [];

        if (invoices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد فواتير',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Cairo',
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
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
              columnSpacing: 16,
              dataRowHeight: 56,
              columns: const [
                DataColumn(
                  label: Text(
                    'رقم الفاتورة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'التاريخ',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الإجمالي',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الحالة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الإجراء',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              rows: invoices
                  .map((invoice) => _buildInvoiceRow(context, invoice))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildInvoiceRow(BuildContext context, Map<String, dynamic> invoice) {
    final status = invoice['status'] ?? 'draft';
    final statusColor = _getStatusColor(status);
    final total = (invoice['total_amount'] ?? 0).toDouble();
    final date = DateTime.parse(
      invoice['invoice_date'] ?? DateTime.now().toIso8601String(),
    );

    return DataRow(
      cells: [
        DataCell(
          Text(
            invoice['invoice_number'] ?? '',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        DataCell(
          Text(
            DateFormat('dd/MM/yyyy', 'ar').format(date),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        DataCell(
          Text(
            '${total.toStringAsFixed(2)} ر.س',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(51),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getStatusText(status),
              style: TextStyle(
                fontFamily: 'Cairo',
                color: statusColor,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.download, size: 18),
                onPressed: () => _downloadPDF(context, invoice),
                tooltip: 'تحميل PDF',
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: () => _viewInvoice(context, invoice),
                tooltip: 'عرض الفاتورة',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchInvoices(
    SupabaseClient supabase,
    String userId,
  ) async {
    try {
      // احصل على معرّف التاجر من الملف الشخصي
      final profile = await supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return [];

      // احصل على الفواتير
      final invoices = await supabase
          .from('invoices')
          .select()
          .eq('merchant_id', profile['id'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(invoices);
    } catch (e) {
      debugPrint('خطأ جلب الفواتير: $e');
      return [];
    }
  }

  void _viewInvoice(BuildContext context, Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'الفاتورة: ${invoice['invoice_number']}',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInvoiceDetail('رقم الفاتورة:', invoice['invoice_number']),
              _buildInvoiceDetail('التاريخ:', invoice['invoice_date']),
              _buildInvoiceDetail(
                'الإجمالي:',
                '${(invoice['total_amount'] ?? 0).toStringAsFixed(2)} ر.س',
              ),
              _buildInvoiceDetail(
                'ضريبة القيمة المضافة:',
                '${(invoice['vat_amount'] ?? 0).toStringAsFixed(2)} ر.س',
              ),
              _buildInvoiceDetail('الحالة:', _getStatusText(invoice['status'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(fontFamily: 'Cairo')),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadPDF(BuildContext context, Map<String, dynamic> invoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'جاري تحميل الفاتورة...',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
    // TODO: تطبيق تحميل PDF
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'issued':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'مسودة';
      case 'issued':
        return 'مُصدرة';
      case 'paid':
        return 'مدفوعة';
      case 'pending':
        return 'قيد الانتظار';
      case 'overdue':
        return 'متأخرة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }
}
