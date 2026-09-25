import { env } from "@/lib/env";

export function publicUrl(path: string | null | undefined, bucket = "expo-public"): string | null {
  if (!path) return null;
  if (/^https?:\/\//.test(path)) return path;
  return `${env.supabaseUrl}/storage/v1/object/public/${bucket}/${path}`;
}

export function thumb(path: string | null | undefined, width = 600): string | null {
  if (!path) return null;
  if (/^https?:\/\//.test(path)) return path;
  return `${env.supabaseUrl}/storage/v1/render/image/public/expo-public/${path}?width=${width}&resize=cover`;
}

export const recordingUrl = (path: string | null | undefined) => publicUrl(path, "expo-recordings");
