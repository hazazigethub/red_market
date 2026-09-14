import ReelsViewer from '@/components/ReelsViewer';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'الريلز — رد ماركت',
  description: 'شاهد أحدث مقاطع المتاجر على رد ماركت',
};

export default function ReelsPage() {
  return <ReelsViewer />;
}
