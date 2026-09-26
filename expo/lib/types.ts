export type ExhibitionStatus = "draft" | "scheduled" | "live" | "ended" | "archived";
export type LeadStatus = "new" | "contacted" | "qualified" | "negotiation" | "won" | "lost";
export type LeadSource = "inquiry_form" | "chat" | "catalog_download" | "stream" | "product_interest" | "qr";
export type MemberRole = "owner" | "manager" | "agent";

export interface Exhibition {
  id: string; organizer_id: string; slug: string; title: string; description: string | null;
  logo_path: string | null; cover_path: string | null; category_id: number | null;
  location_type: "virtual" | "hybrid" | "onsite"; venue: string | null; city: string | null;
  starts_at: string; ends_at: string; timezone: string; status: ExhibitionStatus;
  is_featured: boolean; applications_open: boolean; require_approval: boolean; chat_enabled: boolean;
  max_booths: number | null;
}

export interface Hall { id: string; exhibition_id: string; name: string; sort_order: number; map_layout: { cols?: number; rows?: number } }

export interface Booth {
  id: string; exhibition_id: string; hall_id: string | null; store_id: string; slug: string;
  name: string; tagline: string | null; about: string | null; logo_path: string | null; cover_path: string | null;
  tier: "standard" | "premium" | "sponsor"; map_slot: string | null;
  contact: { phone?: string; whatsapp?: string; email?: string; website?: string };
  status: "draft" | "published" | "hidden"; likes_count: number; follows_count: number; views_count: number;
}

export interface BoothProduct {
  product_id: string; name: string; price: number | null; expo_price: number | null; image_url: string | null;
  slug: string | null; is_highlighted: boolean; expo_badge: string | null; sort_order: number;
  url: string | null; // Red Market product page (products.product_url)
}

export interface BoothMedia {
  id: string; booth_id: string; type: "image" | "video" | "catalog"; storage_path: string;
  thumbnail_path: string | null; title: string | null; sort_order: number; is_gated: boolean; size_bytes: number | null;
}

export interface Session {
  id: string; exhibition_id: string; hall_id: string | null; title: string; description: string | null;
  type: "keynote" | "panel" | "workshop" | "talk"; starts_at: string; ends_at: string;
  capacity: number | null; registered_count: number; status: "scheduled" | "live" | "ended" | "cancelled";
  cover_path: string | null;
}

export interface Speaker {
  id: string; exhibition_id: string; full_name: string; job_title: string | null; company: string | null;
  bio: string | null; photo_path: string | null; links: Record<string, string>; sort_order: number;
}

export interface Sponsor {
  id: string; exhibition_id: string; booth_id: string | null; name: string; logo_path: string | null;
  website_url: string | null; tier: "platinum" | "gold" | "silver" | "partner"; sort_order: number;
}

export interface LiveStream {
  id: string; exhibition_id: string; booth_id: string | null; session_id: string | null; title: string;
  status: "scheduled" | "live" | "ended" | "failed"; scheduled_at: string | null; started_at: string | null;
  ended_at: string | null; recording_path: string | null; current_viewers: number; peak_viewers: number;
  likes_count: number; pinned_product_id: string | null; cf_input_id: string | null;
}

export interface Lead {
  id: string; exhibition_id: string; booth_id: string; visitor_id: string | null; full_name: string;
  phone: string | null; email: string | null; company: string | null; message: string | null;
  source: LeadSource; status: LeadStatus; score: number; assigned_to: string | null; chat_id: string | null;
  consent_at: string; created_at: string; last_activity_at: string;
}

export interface Message {
  id: number; chat_id: string; sender_id: string; sender_name?: string; kind: string; body: string;
  created_at: string; deleted_at?: string | null;
}
