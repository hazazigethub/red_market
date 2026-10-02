'use client';

import { useEffect } from 'react';
import { logVisit, type PageName } from '@/lib/analytics';

type Props = {
  page: PageName;
  merchantId?: string | null;
  categoryId?: string | null;
  categoryName?: string | null;
};

/**
 * مكوّن صامت يسجّل زيارة الصفحة عند فتحها.
 * لا يعرض شيئاً، ويُوضع في أي صفحة خادم.
 */
export default function VisitLogger({
  page,
  merchantId = null,
  categoryId = null,
  categoryName = null,
}: Props) {
  useEffect(() => {
    logVisit(page, { merchantId, categoryId, categoryName });
  }, [page, merchantId, categoryId, categoryName]);

  return null;
}
