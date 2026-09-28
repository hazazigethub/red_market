export type Banner = {
  id: string;
  image_url: string | null;
  product_id?: string | null;
  merchant_id?: string | null;
  category_id?: string | null;
  /// معرّف الحجز — للبنرات المؤجّرة فقط، وبه يُتتبّع الظهور والنقر
  booking_id?: string | null;
  /// وجهة البنر: store أو product أو category
  target_type?: string | null;
  /// رابط خارجي (مثل صفحة معرض) — له الأولوية إن وُجد
  link_url?: string | null;
};

/// يحدد وجهة البنر
export function bannerHref(b: Banner): string | null {
  if (b.link_url && b.link_url.startsWith('https://')) return b.link_url;
  // البنرات المحجوزة: الوجهة صريحة
  if (b.target_type === 'product' && b.product_id) {
    return `/offer/${b.product_id}`;
  }
  if (b.target_type === 'store' && b.merchant_id) {
    return `/store/${b.merchant_id}`;
  }

  // البنرات الداخلية: أول ربط متاح
  if (b.product_id) return `/offer/${b.product_id}`;
  if (b.merchant_id) return `/store/${b.merchant_id}`;
  if (b.category_id) return `/category-offers/${b.category_id}`;
  return null;
}
