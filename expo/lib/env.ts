export const env = {
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "http://localhost:54321",
  supabaseAnonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "anon",
  cookieDomain: process.env.NEXT_PUBLIC_COOKIE_DOMAIN || undefined,
  redmarketUrl: process.env.NEXT_PUBLIC_REDMARKET_URL ?? "https://redmarket.pro",
  loginPath: process.env.NEXT_PUBLIC_REDMARKET_LOGIN_PATH ?? "/login",
  productUrlTemplate:
    process.env.NEXT_PUBLIC_PRODUCT_URL_TEMPLATE ?? "https://redmarket.pro/products/{slug}",
  siteUrl: process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",
  /** customer-xxxx.cloudflarestream.com */
  cfStreamSubdomain: process.env.NEXT_PUBLIC_CF_STREAM_SUBDOMAIN ?? "",
  /** "local" (default): sign-in page on the Expo site with the same Supabase accounts (email + password).
   *  "redmarket": send users to Red Market's web login and share the session cookie on .redmarket.pro. */
  authMode: (process.env.NEXT_PUBLIC_AUTH_MODE ?? "local") as "local" | "redmarket",
};

export const functionsUrl = `${env.supabaseUrl}/functions/v1`;

export function loginUrl(returnPath: string): string {
  if (env.authMode === "local") return `/login?next=${encodeURIComponent(returnPath)}`;
  const back = `${env.siteUrl}${returnPath}`;
  return `${env.redmarketUrl}${env.loginPath}?redirect=${encodeURIComponent(back)}`;
}

export function productUrl(p: { url?: string | null; slug?: string | null; product_id?: string; id?: string }): string {
  if (p.url && /^https?:\/\//.test(p.url)) return p.url;
  const id = p.product_id ?? p.id ?? "";
  return env.productUrlTemplate.replace("{slug}", p.slug ?? id).replace("{id}", id);
}
