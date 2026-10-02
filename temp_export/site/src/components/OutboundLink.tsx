'use client';

import type { CSSProperties, ReactNode } from 'react';
import { logStoreClick } from '@/lib/tracking';

type Props = {
  href: string;
  source: 'product' | 'store';
  productId?: string | number | null;
  merchantId?: string | null;
  className?: string;
  style?: CSSProperties;
  children: ReactNode;
};

/// رابط إلى متجر التاجر يسجّل الانتقال ثم يفتح المتجر
export default function OutboundLink({
  href,
  source,
  productId,
  merchantId,
  className,
  style,
  children,
}: Props) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={className}
      style={style}
      onClick={() => {
        void logStoreClick({ productId, merchantId, source });
      }}
    >
      {children}
    </a>
  );
}
