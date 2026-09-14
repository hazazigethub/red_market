export type Product = {
  id: string;
  name: string | null;
  description: string | null;
  price: number | null;
  old_price: number | null;
  discount_price: number | null;
  image_url: string | null;
  images_url: string[] | null;
  product_url: string | null;
  store_name: string | null;
  merchant_id: string | null;
  category: string | null;
  category_id: string | null;
  store_category: string | null;
  is_offer: boolean | null;
  is_flash_sale: boolean | null;
  flash_sale_expiry: string | null;
  flash_sale_start: string | null;
  is_featured: boolean | null;
  is_available: boolean | null;
  is_banned: boolean | null;
  likes_count: number | null;
  views_count: number | null;
  created_at: string | null;
};

export type Merchant = {
  id: string;
  store_name: string | null;
  logo_url: string | null;
  store_description: string | null;
  store_url: string | null;
  store_category_id: string | null;
  is_subscription_active: boolean | null;
  followers_count: number | null;
};

export type Category = {
  id: string;
  name: string | null;
  parent_id: string | null;
  is_visible: boolean | null;
};
