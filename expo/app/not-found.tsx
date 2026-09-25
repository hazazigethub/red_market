import Link from "next/link";
export default function NotFound() {
  return (
    <div className="container-x flex flex-col items-center gap-4 py-24 text-center">
      <p className="font-heading text-6xl font-extrabold text-primary">404</p>
      <h1 className="text-2xl font-bold">الصفحة غير موجودة</h1>
      <p className="text-muted">ربما انتهى المعرض أو تغيّر الرابط.</p>
      <Link href="/" className="btn-primary">العودة للمعارض</Link>
    </div>
  );
}
