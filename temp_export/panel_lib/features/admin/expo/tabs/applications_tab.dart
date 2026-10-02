import 'package:flutter/material.dart';

import '../expo_common.dart';

const Map<String, String> kParticipationKind = {
  'free_pro_annual': 'مجانية · الاحترافية السنوية',
  'code': 'كود',
  'payment': 'دفع',
};

/// بطاقة مشارك (مشتركة بين صفحة المعرض وقائمة المشاركين الجدد)
Widget expoParticipantCard(Map<String, dynamic> p, {bool showExhibition = false}) {
  final store = p['store'] is Map ? p['store'] as Map : const {};
  final booth = p['booths'] is Map ? p['booths'] as Map : const {};
  final hall = booth['exhibition_halls'] is Map ? booth['exhibition_halls']['name'] : null;
  final logo = store['logo_url'] as String?;
  final kind = '${p['kind']}';
  final isNew = p['admin_seen_at'] == null;
  return ExpoCard(
    borderColor: isNew ? kBrand.withValues(alpha: 0.35) : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: kBrand.withValues(alpha: 0.08),
            backgroundImage: logo != null ? NetworkImage(logo) : null,
            child: logo == null
                ? const Icon(Icons.storefront_outlined, color: kBrand, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${store['name'] ?? 'متجر'}',
                    style: const TextStyle(
                        fontFamily: kExpoFont,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                expoSub(showExhibition && p['exhibitions'] is Map
                    ? '${p['exhibitions']['title']} · ${expoFmtDateTime(p['created_at'])}'
                    : expoFmtDateTime(p['created_at'])),
              ],
            ),
          ),
          if (isNew) expoChip('جديد', kBrand),
        ]),
        const SizedBox(height: 12),
        kExpoDivider,
        const SizedBox(height: 10),
        Wrap(spacing: 18, runSpacing: 6, children: [
          expoStat(Icons.payments_outlined,
              '${kParticipationKind[kind] ?? kind}${p['promo_code'] != null ? ' ${p['promo_code']}' : ''}'),
          expoStat(Icons.sell_outlined,
              kind == 'free_pro_annual' ? 'بدون رسوم' : '${p['price']} ريال'),
          expoStat(Icons.place_outlined,
              booth['map_slot'] == null ? 'بدون موقع' : '${hall ?? ''} · ${booth['map_slot']}'),
        ]),
      ],
    ),
  );
}

/// المشاركون في معرض واحد
class ApplicationsTab extends StatefulWidget {
  final String exhibitionId;
  const ApplicationsTab({super.key, required this.exhibitionId});

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  Future<List<Map<String, dynamic>>> _load() => expoDb
      .from('participation_purchases')
      .select('*, store(name, logo_url), booths(map_slot, exhibition_halls(name))')
      .eq('exhibition_id', widget.exhibitionId)
      .order('created_at', ascending: false);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final list = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            expoHeader('المشاركون', count: list.length),
            if (list.isEmpty)
              expoEmpty('لا مشاركين بعد', icon: Icons.how_to_reg_outlined)
            else
              expoGrid(list.map((p) => expoParticipantCard(p)).toList(), maxCols: 2),
          ],
        );
      },
    );
  }
}
