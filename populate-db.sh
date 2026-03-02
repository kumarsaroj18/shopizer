#!/bin/bash

# ============================================================
# Shopizer Database Population Script
# Uses REST API endpoints to seed:
#   - Multiple stores (with required address)
#   - Multiple categories (per store)
#   - Multiple brands / manufacturers (per store)
#   - Multiple products (per store, linked to category & brand)
# ============================================================
# Usage:
#   ./populate-db.sh [OPTIONS]
#
# Options:
#   --help, -h    Show this help message
#
# Environment Variables:
#   BASE_URL      Backend API endpoint (default: http://localhost:8080)
#   ADMIN_USER    Admin username (default: admin@shopizer.com)
#   ADMIN_PASS    Admin password (default: password)
#   FORCE_SUFFIX  Add suffix to codes for re-runs (default: empty)
#
# Examples:
#   ./populate-db.sh
#   BASE_URL=http://api.example.com ./populate-db.sh
#   FORCE_SUFFIX=2 ./populate-db.sh
# ============================================================

usage() {
  sed -n '/^# Usage/,/^# ====/p' "$0" | grep -v '^# ====' | sed 's/^# //'
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

BASE_URL="${BASE_URL:-http://localhost:8080}"
ADMIN_USER="${ADMIN_USER:-admin@shopizer.com}"
ADMIN_PASS="${ADMIN_PASS:-password}"
DEFAULT_STORE="DEFAULT"
# Optional: set FORCE_SUFFIX=2 (or any string) to create all-new codes on re-runs
SFX="${FORCE_SUFFIX:-}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✅ $*${NC}"; }
fail() { echo -e "${RED}  ❌ $*${NC}"; }
info() { echo -e "${YELLOW}  ℹ  $*${NC}"; }

# ─── POST with status check ───────────────────────────────────
# Returns global RESP_CODE and RESP_BODY
# Also sets IS_DUPLICATE=true when response shows a unique constraint violation
do_post() {
  local url="$1" body="$2" auth="$3"
  local raw
  if [ -n "$auth" ]; then
    raw=$(curl -s -w "\n__STATUS__%{http_code}" -X POST "$url" \
      -H "Content-Type: application/json" -H "Authorization: Bearer $auth" -d "$body")
  else
    raw=$(curl -s -w "\n__STATUS__%{http_code}" -X POST "$url" \
      -H "Content-Type: application/json" -d "$body")
  fi
  RESP_CODE=$(echo "$raw" | grep '__STATUS__' | sed 's/__STATUS__//')
  RESP_BODY=$(echo "$raw" | grep -v '__STATUS__')
  # Detect duplicate/conflict: body-based OR Shopizer's 503 for duplicate manufacturer
  IS_DUPLICATE=false
  if echo "$RESP_BODY" | grep -qi "unique\|duplicate\|constraint\|already exist"; then
    IS_DUPLICATE=true
  fi
  # Shopizer returns 503 for duplicate manufacturer code
  if [ "$RESP_CODE" = "503" ]; then
    IS_DUPLICATE=true
  fi
}

# Extract a top-level integer field from JSON without jq
# Usage: extract_id <json> <field>
extract_id() {
  echo "$1" | grep -o "\"$2\":[0-9]*" | head -1 | grep -o '[0-9]*'
}

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       Shopizer Database Population Script                ║"
echo "║  Stores → Categories → Brands → Products                ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo "  Base URL : $BASE_URL"
echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 1 – Authenticate
# ═══════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " STEP 1 – Admin Authentication"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

AUTH_RESP=$(curl -s -X POST "$BASE_URL/api/v1/private/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}")
TOKEN=$(echo "$AUTH_RESP" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  fail "Authentication failed. Is the app running at $BASE_URL?"
  echo "  Response: $AUTH_RESP"
  exit 1
fi
ok "Authenticated as $ADMIN_USER"

# ═══════════════════════════════════════════════════════════════
# STEP 2 – Create stores
#   Required fields: code, name, email, phone + address.country
# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " STEP 2 – Creating Stores"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# create_store <code> <name> <email> <phone> <country> <state> <city> <zip>
create_store() {
  local code="$1" name="$2" email="$3" phone="$4"
  local country="${5:-US}" state="${6:-CA}" city="${7:-Los Angeles}" zip="${8:-90001}"
  do_post "$BASE_URL/api/v1/private/store" "{
    \"code\": \"${code}${SFX}\",
    \"name\": \"$name\",
    \"email\": \"$email\",
    \"phone\": \"$phone\",
    \"defaultLanguage\": \"en\",
    \"currency\": \"USD\",
    \"inBusinessSince\": \"2024-01-01\",
    \"retailer\": true,
    \"dimension\": \"IN\",
    \"weight\": \"LB\",
    \"supportedLanguages\": [\"en\"],
    \"address\": {
      \"country\": \"$country\",
      \"stateProvince\": \"$state\",
      \"city\": \"$city\",
      \"address\": \"100 Main Street\",
      \"postalCode\": \"$zip\"
    }
  }" "$TOKEN"
  if [ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]; then
    ok "Store created: $name (${code}${SFX})"
  elif [ "$IS_DUPLICATE" = true ] || [ "$RESP_CODE" = "500" ]; then
    info "Store ${code}${SFX} already exists — skipping"
  else
    fail "Store ${code}${SFX} failed (HTTP $RESP_CODE): $RESP_BODY"
  fi
}

create_store "ELECTRONICS${SFX}" "Electronics Hub"    "admin@electronichub.com" "+1-800-555-0101" "US" "CA" "San Francisco" "94105"
create_store "FASHION${SFX}"     "Fashion World"      "admin@fashionworld.com"  "+1-800-555-0202" "US" "NY" "New York"      "10001"
create_store "HOMESTORE${SFX}"   "Home and Garden Co" "admin@homegarden.com"    "+1-800-555-0303" "US" "TX" "Austin"        "73301"
info "DEFAULT store already exists — will also be seeded"

# ═══════════════════════════════════════════════════════════════
# STEP 3 – Create categories
# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " STEP 3 – Creating Categories"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Sets global CATEGORY_ID
create_category() {
  local store="$1" code="$2" sort="$3" name="$4" url="$5"
  do_post "$BASE_URL/api/v1/private/category?store=$store" "{
    \"code\": \"${code}${SFX}\",
    \"sortOrder\": $sort,
    \"visible\": true,
    \"descriptions\": [{
      \"language\": \"en\",
      \"name\": \"$name\",
      \"friendlyUrl\": \"${url}${SFX}\",
      \"title\": \"$name\"
    }]
  }" "$TOKEN"
  CATEGORY_ID=$(extract_id "$RESP_BODY" "id")
  if [ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]; then
    ok "[$store] Category: $name (id=$CATEGORY_ID)"
  elif [ "$IS_DUPLICATE" = true ]; then
    info "[$store] Category '${code}${SFX}' already exists — id may be missing, linking skipped"
    CATEGORY_ID=""
  else
    fail "[$store] Category $name failed (HTTP $RESP_CODE): $RESP_BODY"
    CATEGORY_ID=""
  fi
}

info "DEFAULT store categories"
create_category "$DEFAULT_STORE" "electronics"  1 "Electronics"       "electronics"
CAT_DEF_ELEC=$CATEGORY_ID
create_category "$DEFAULT_STORE" "books"        2 "Books"             "books"
CAT_DEF_BOOKS=$CATEGORY_ID
create_category "$DEFAULT_STORE" "clothing"     3 "Clothing"          "clothing"
CAT_DEF_CLOTH=$CATEGORY_ID
create_category "$DEFAULT_STORE" "home-garden"  4 "Home and Garden"   "home-garden"
CAT_DEF_HOME=$CATEGORY_ID
create_category "$DEFAULT_STORE" "sports"       5 "Sports and Outdoors" "sports-outdoors"
CAT_DEF_SPORTS=$CATEGORY_ID

info "ELECTRONICS store categories"
create_category "ELECTRONICS" "laptops"     1 "Laptops and Computers"    "laptops-computers"
CAT_ELEC_LAPTOPS=$CATEGORY_ID
create_category "ELECTRONICS" "smartphones" 2 "Smartphones and Tablets"  "smartphones-tablets"
CAT_ELEC_PHONES=$CATEGORY_ID
create_category "ELECTRONICS" "audio"       3 "Audio and Headphones"     "audio-headphones"
CAT_ELEC_AUDIO=$CATEGORY_ID
create_category "ELECTRONICS" "cameras"     4 "Cameras and Photography"  "cameras-photography"
CAT_ELEC_CAMERAS=$CATEGORY_ID
create_category "ELECTRONICS" "gaming"      5 "Gaming"                   "gaming"
CAT_ELEC_GAMING=$CATEGORY_ID

info "FASHION store categories"
create_category "FASHION" "mens-fashion"    1 "Mens Fashion"      "mens-fashion"
CAT_FASH_MENS=$CATEGORY_ID
create_category "FASHION" "womens-fashion"  2 "Womens Fashion"    "womens-fashion"
CAT_FASH_WOMENS=$CATEGORY_ID
create_category "FASHION" "footwear"        3 "Footwear"          "footwear"
CAT_FASH_FOOTWEAR=$CATEGORY_ID
create_category "FASHION" "accessories"     4 "Accessories"       "accessories"
CAT_FASH_ACC=$CATEGORY_ID

info "HOMESTORE categories"
create_category "HOMESTORE" "furniture"  1 "Furniture"         "furniture"
CAT_HOME_FURN=$CATEGORY_ID
create_category "HOMESTORE" "kitchen"    2 "Kitchen and Dining" "kitchen-dining"
CAT_HOME_KITCH=$CATEGORY_ID
create_category "HOMESTORE" "garden"     3 "Garden and Outdoor" "garden-outdoor"
CAT_HOME_GARD=$CATEGORY_ID
create_category "HOMESTORE" "bedding"    4 "Bedding and Bath"   "bedding-bath"
CAT_HOME_BED=$CATEGORY_ID

# ═══════════════════════════════════════════════════════════════
# STEP 4 – Create brands (manufacturers)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " STEP 4 – Creating Brands (Manufacturers)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

create_brand() {
  local store="$1" code="$2" name="$3" url="$4" sort="${5:-1}"
  do_post "$BASE_URL/api/v1/private/manufacturer?store=$store" "{
    \"code\": \"${code}${SFX}\",
    \"order\": $sort,
    \"descriptions\": [{
      \"language\": \"en\",
      \"name\": \"$name\",
      \"friendlyUrl\": \"${url}${SFX}\",
      \"title\": \"$name\"
    }]
  }" "$TOKEN"
  if [ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]; then
    ok "[$store] Brand: $name (code=${code}${SFX})"
  elif [ "$IS_DUPLICATE" = true ]; then
    info "[$store] Brand '${code}${SFX}' already exists — skipping"
  else
    fail "[$store] Brand $name failed (HTTP $RESP_CODE): $RESP_BODY"
  fi
}

info "DEFAULT store brands"
create_brand "$DEFAULT_STORE" "apple"   "Apple"         "apple"   1
create_brand "$DEFAULT_STORE" "samsung" "Samsung"       "samsung" 2
create_brand "$DEFAULT_STORE" "nike"    "Nike"          "nike"    3
create_brand "$DEFAULT_STORE" "penguin" "Penguin Books" "penguin" 4
create_brand "$DEFAULT_STORE" "coleman" "Coleman"       "coleman" 5

info "ELECTRONICS store brands"
create_brand "ELECTRONICS" "apple"    "Apple"    "apple"    1
create_brand "ELECTRONICS" "dell"     "Dell"     "dell"     2
create_brand "ELECTRONICS" "sony"     "Sony"     "sony"     3
create_brand "ELECTRONICS" "bose"     "Bose"     "bose"     4
create_brand "ELECTRONICS" "logitech" "Logitech" "logitech" 5
create_brand "ELECTRONICS" "canon"    "Canon"    "canon"    6
create_brand "ELECTRONICS" "nvidia"   "NVIDIA"   "nvidia"   7

info "FASHION store brands"
create_brand "FASHION" "nike"   "Nike"   "nike"   1
create_brand "FASHION" "adidas" "Adidas" "adidas" 2
create_brand "FASHION" "zara"   "Zara"   "zara"   3
create_brand "FASHION" "levis"  "Levis"  "levis"  4
create_brand "FASHION" "gucci"  "Gucci"  "gucci"  5

info "HOMESTORE brands"
create_brand "HOMESTORE" "ikea"       "IKEA"       "ikea"       1
create_brand "HOMESTORE" "kitchenaid" "KitchenAid" "kitchenaid" 2
create_brand "HOMESTORE" "dyson"      "Dyson"      "dyson"      3
create_brand "HOMESTORE" "weber"      "Weber"      "weber"      4

# ═══════════════════════════════════════════════════════════════
# STEP 5 – Create products and link to categories
# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " STEP 5 – Creating Products"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# create_product <store> <sku> <name> <url> <desc> <price> <qty> <brand_code> <cat_id>
create_product() {
  local store="$1" sku="$2" name="$3" url="$4"
  local desc="$5" price="$6" qty="$7" mfr="$8" cat_id="$9"

  do_post "$BASE_URL/api/v1/private/product?store=$store" "{
    \"sku\": \"${sku}${SFX}\",
    \"price\": $price,
    \"quantity\": $qty,
    \"available\": true,
    \"visible\": true,
    \"productShipeable\": true,
    \"productSpecifications\": { \"manufacturer\": \"${mfr}${SFX}\" },
    \"descriptions\": [{
      \"language\": \"en\",
      \"name\": \"$name\",
      \"friendlyUrl\": \"${url}${SFX}\",
      \"title\": \"$name\",
      \"description\": \"$desc\"
    }]
  }" "$TOKEN"

  local pid
  pid=$(extract_id "$RESP_BODY" "id")

  if [ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]; then
    ok "[$store] Product: $name (id=$pid) sku=${sku}${SFX} price=\$$price"
    if [ -n "$cat_id" ] && [ -n "$pid" ]; then
      local link_code
      link_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "$BASE_URL/api/v1/private/product/$pid/category/$cat_id?store=$store" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")
      if [ "$link_code" = "200" ] || [ "$link_code" = "201" ]; then
        info "  Linked product $pid \u2192 category $cat_id"
      else
        fail "  Link failed product $pid \u2192 category $cat_id (HTTP $link_code)"
      fi
    fi
  elif [ "$IS_DUPLICATE" = true ]; then
    info "[$store] Product '${sku}${SFX}' already exists \u2014 skipping"
  else
    fail "[$store] Product '$name' failed (HTTP $RESP_CODE): $RESP_BODY"
  fi
}

# ── DEFAULT store ─────────────────────────────────────────────
info "DEFAULT store products"
create_product "$DEFAULT_STORE" \
  "DEF-LAPTOP-001" "MacBook Pro 14" "macbook-pro-14" \
  "Apple M3 Pro, 18GB RAM, 512GB SSD" \
  1999.99 25 "apple" "$CAT_DEF_ELEC"

create_product "$DEFAULT_STORE" \
  "DEF-PHONE-001" "Samsung Galaxy S24 Ultra" "samsung-galaxy-s24-ultra" \
  "200MP camera, 12GB RAM, titanium frame, S Pen included" \
  1299.99 40 "samsung" "$CAT_DEF_ELEC"

create_product "$DEFAULT_STORE" \
  "DEF-SHOES-001" "Nike Air Max 270" "nike-air-max-270" \
  "Lightweight running shoe with large Air unit for comfort" \
  149.99 80 "nike" "$CAT_DEF_CLOTH"

create_product "$DEFAULT_STORE" \
  "DEF-BOOK-001" "Clean Code Handbook" "clean-code-handbook" \
  "A must-read guide for software craftsmen and developers" \
  39.99 150 "penguin" "$CAT_DEF_BOOKS"

create_product "$DEFAULT_STORE" \
  "DEF-CAMP-001" "Coleman 4-Person Tent" "coleman-4-person-tent" \
  "Weatherproof dome tent easy setup great for family camping" \
  129.99 35 "coleman" "$CAT_DEF_SPORTS"

create_product "$DEFAULT_STORE" \
  "DEF-JACKT-001" "Nike Windrunner Jacket" "nike-windrunner-jacket" \
  "Iconic pullover windbreaker with bold colour-blocked design" \
  89.99 60 "nike" "$CAT_DEF_CLOTH"

create_product "$DEFAULT_STORE" \
  "DEF-GARDEN-001" "Coleman Garden Shears" "coleman-garden-shears" \
  "Heavy-duty garden shears with ergonomic grip" \
  34.99 90 "coleman" "$CAT_DEF_HOME"

# ── ELECTRONICS store ─────────────────────────────────────────
info "ELECTRONICS store products"
create_product "ELECTRONICS" \
  "ELEC-LAPTOP-001" "MacBook Air M3 15" "macbook-air-m3-15" \
  "Fanless design all-day battery 15-inch Liquid Retina display" \
  1299.99 30 "apple" "$CAT_ELEC_LAPTOPS"

create_product "ELECTRONICS" \
  "ELEC-LAPTOP-002" "Dell XPS 15 OLED" "dell-xps-15-oled" \
  "Intel Core i9 RTX 4070 32GB DDR5 1TB NVMe 3.5K OLED display" \
  2199.99 20 "dell" "$CAT_ELEC_LAPTOPS"

create_product "ELECTRONICS" \
  "ELEC-LAPTOP-003" "Dell Inspiron 15" "dell-inspiron-15" \
  "Budget laptop Intel Core i5 8GB RAM 512GB SSD Windows 11" \
  549.99 50 "dell" "$CAT_ELEC_LAPTOPS"

create_product "ELECTRONICS" \
  "ELEC-PHONE-001" "iPhone 15 Pro Max" "iphone-15-pro-max" \
  "A17 Pro chip 48MP triple camera titanium design Action button" \
  1199.99 60 "apple" "$CAT_ELEC_PHONES"

create_product "ELECTRONICS" \
  "ELEC-PHONE-002" "Sony Xperia 1 V" "sony-xperia-1-v" \
  "4K OLED display Zeiss optics triple camera headphone jack 12GB RAM" \
  1099.99 25 "sony" "$CAT_ELEC_PHONES"

create_product "ELECTRONICS" \
  "ELEC-AUDIO-001" "Bose QuietComfort 45" "bose-qc45" \
  "World-class noise cancellation 24-hour battery comfortable fit" \
  329.99 80 "bose" "$CAT_ELEC_AUDIO"

create_product "ELECTRONICS" \
  "ELEC-AUDIO-002" "Sony WH-1000XM5" "sony-wh1000xm5" \
  "Industry-leading noise cancelling 30-hour battery USB-C quick charge" \
  399.99 70 "sony" "$CAT_ELEC_AUDIO"

create_product "ELECTRONICS" \
  "ELEC-AUDIO-003" "Logitech G Pro X Headset" "logitech-gpro-x" \
  "Pro-grade gaming headset Blue VO microphone DTS 7.1 Surround" \
  129.99 100 "logitech" "$CAT_ELEC_AUDIO"

create_product "ELECTRONICS" \
  "ELEC-CAM-001" "Canon EOS R6 Mark II" "canon-eos-r6-mkii" \
  "40fps burst 24.2MP full-frame CMOS Dual Pixel CMOS AF II" \
  2499.99 15 "canon" "$CAT_ELEC_CAMERAS"

create_product "ELECTRONICS" \
  "ELEC-CAM-002" "Sony Alpha A7 IV" "sony-alpha-a7iv" \
  "33MP full-frame 4K 60fps video 10fps burst advanced AF" \
  2499.99 18 "sony" "$CAT_ELEC_CAMERAS"

create_product "ELECTRONICS" \
  "ELEC-GAME-001" "NVIDIA RTX 4080 Super" "nvidia-rtx-4080-super" \
  "16GB GDDR6X DLSS 3 4K gaming powerhouse with ray tracing" \
  999.99 20 "nvidia" "$CAT_ELEC_GAMING"

create_product "ELECTRONICS" \
  "ELEC-GAME-002" "Logitech G915 TKL Keyboard" "logitech-g915-tkl" \
  "Tenkeyless lightspeed wireless low-profile GL switches RGB" \
  229.99 55 "logitech" "$CAT_ELEC_GAMING"

# ── FASHION store ─────────────────────────────────────────────
info "FASHION store products"
create_product "FASHION" \
  "FASH-M-001" "Nike Dri-FIT Polo Shirt" "nike-dri-fit-polo" \
  "Sweat-wicking polo moisture management technology" \
  85.00 90 "nike" "$CAT_FASH_MENS"

create_product "FASHION" \
  "FASH-M-002" "Levis 511 Slim Fit Jeans" "levis-511-slim-jeans" \
  "Classic slim fit from hip to ankle Flex stretch denim" \
  69.99 120 "levis" "$CAT_FASH_MENS"

create_product "FASHION" \
  "FASH-M-003" "Adidas Originals Hoodie" "adidas-originals-hoodie" \
  "Trefoil emblem kangaroo pocket fleece-lined comfort" \
  75.00 80 "adidas" "$CAT_FASH_MENS"

create_product "FASHION" \
  "FASH-W-001" "Zara Floral Midi Dress" "zara-floral-midi-dress" \
  "Feminine floral print midi dress V-neckline ruffle hem" \
  59.99 70 "zara" "$CAT_FASH_WOMENS"

create_product "FASHION" \
  "FASH-W-002" "Nike Womens Leggings" "nike-womens-leggings" \
  "High-waisted Dri-FIT leggings 7/8 length with pockets" \
  65.00 95 "nike" "$CAT_FASH_WOMENS"

create_product "FASHION" \
  "FASH-FOOT-001" "Nike Air Force 1 Low" "nike-air-force-1-low" \
  "Timeless basketball shoe leather upper Air sole unit" \
  110.00 100 "nike" "$CAT_FASH_FOOTWEAR"

create_product "FASHION" \
  "FASH-FOOT-002" "Adidas Superstar Sneakers" "adidas-superstar" \
  "Legendary shell toe full-grain leather serrated 3-Stripes" \
  100.00 110 "adidas" "$CAT_FASH_FOOTWEAR"

create_product "FASHION" \
  "FASH-ACC-001" "Gucci GG Canvas Tote" "gucci-gg-canvas-tote" \
  "Iconic GG Supreme canvas Web stripe accent zip-top closure" \
  890.00 20 "gucci" "$CAT_FASH_ACC"

create_product "FASHION" \
  "FASH-ACC-002" "Levis Canvas Backpack" "levis-canvas-backpack" \
  "Durable canvas backpack laptop compartment Levis logo patch" \
  45.00 60 "levis" "$CAT_FASH_ACC"

# ── HOMESTORE ─────────────────────────────────────────────────
info "HOMESTORE products"
create_product "HOMESTORE" \
  "HOME-FURN-001" "IKEA BESTA Storage" "ikea-besta-storage" \
  "Versatile storage unit with doors white frame Lappviken door" \
  299.99 25 "ikea" "$CAT_HOME_FURN"

create_product "HOMESTORE" \
  "HOME-FURN-002" "IKEA POANG Armchair" "ikea-poang-armchair" \
  "Layer-glued bent birch frame resilience light beige cushion" \
  199.99 30 "ikea" "$CAT_HOME_FURN"

create_product "HOMESTORE" \
  "HOME-FURN-003" "IKEA KALLAX Shelf" "ikea-kallax-shelf" \
  "4x4 cube shelf organiser in white perfect for living room" \
  189.99 40 "ikea" "$CAT_HOME_FURN"

create_product "HOMESTORE" \
  "HOME-KIT-001" "KitchenAid Artisan Stand Mixer" "kitchenaid-artisan-mixer" \
  "5.5-quart stainless steel bowl 10-speed settings" \
  449.99 20 "kitchenaid" "$CAT_HOME_KITCH"

create_product "HOMESTORE" \
  "HOME-KIT-002" "KitchenAid K400 Blender" "kitchenaid-k400-blender" \
  "Intelli-Speed motor control 5-speed 56oz jar self-cleaning" \
  199.99 35 "kitchenaid" "$CAT_HOME_KITCH"

create_product "HOMESTORE" \
  "HOME-KIT-003" "Dyson Hot Cool HP07" "dyson-hot-cool-hp07" \
  "Purifies heats and cools HEPA H13 filtration" \
  549.99 18 "dyson" "$CAT_HOME_KITCH"

create_product "HOMESTORE" \
  "HOME-GARD-001" "Weber Spirit II E-310 Grill" "weber-spirit-ii-e310" \
  "3-burner gas grill 30000 BTU porcelain-enameled grates" \
  599.99 12 "weber" "$CAT_HOME_GARD"

create_product "HOMESTORE" \
  "HOME-GARD-002" "Weber Q1200 Portable Grill" "weber-q1200-grill" \
  "Compact 2-burner portable grill 8500 BTU glass-reinforced body" \
  199.99 25 "weber" "$CAT_HOME_GARD"

create_product "HOMESTORE" \
  "HOME-BED-001" "Dyson V15 Detect Vacuum" "dyson-v15-detect" \
  "Laser reveals dust HEPA filtration LCD real-time particle counts" \
  749.99 22 "dyson" "$CAT_HOME_BED"

create_product "HOMESTORE" \
  "HOME-BED-002" "IKEA GULLABERG Pillow Set" "ikea-gullaberg-pillows" \
  "Set of 2 pillows lyocell shell polyester fibre medium support" \
  39.99 80 "ikea" "$CAT_HOME_BED"

# ═══════════════════════════════════════════════════════════════
# STEP 6 – Register customers
# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " STEP 6 – Registering Customers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

register_customer() {
  local store="$1" email="$2" fname="$3" lname="$4" gender="$5" country="$6"
  do_post "$BASE_URL/api/v1/customer/register" "{
    \"emailAddress\": \"$email\",
    \"password\": \"password123\",
    \"gender\": \"$gender\",
    \"language\": \"en\",
    \"storeCode\": \"$store\",
    \"billing\": {\"firstName\": \"$fname\", \"lastName\": \"$lname\", \"country\": \"$country\"}
  }" ""
  if [ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]; then
    ok "[$store] Customer: $fname $lname ($email)"
  elif [ "$IS_DUPLICATE" = true ] || [ "$RESP_CODE" = "500" ]; then
    # Shopizer returns 500 for duplicate email addresses
    info "[$store] Customer $email already exists — skipping"
  else
    fail "[$store] Customer $email failed (HTTP $RESP_CODE): $RESP_BODY"
  fi
}

register_customer "$DEFAULT_STORE"         "john.doe2@example.com"      "John"   "Doe"     "M" "US"
register_customer "$DEFAULT_STORE"         "jane.smith2@example.com"    "Jane"   "Smith"   "F" "CA"
register_customer "$DEFAULT_STORE"         "bob.wilson2@example.com"    "Bob"    "Wilson"  "M" "GB"
register_customer "$DEFAULT_STORE"         "alice.johnson2@example.com" "Alice"  "Johnson" "F" "US"
register_customer "$DEFAULT_STORE"         "tom.brown2@example.com"     "Tom"    "Brown"   "M" "AU"
register_customer "ELECTRONICS${SFX}"      "tech.fan2@example.com"      "Tech"   "Fan"     "M" "US"
register_customer "ELECTRONICS${SFX}"      "gadget.lover2@example.com"  "Gadget" "Lover"   "F" "DE"
register_customer "FASHION${SFX}"          "style.queen2@example.com"   "Style"  "Queen"   "F" "FR"
register_customer "FASHION${SFX}"          "trendy.guy2@example.com"    "Trendy" "Guy"     "M" "IT"
register_customer "HOMESTORE${SFX}"        "home.maker2@example.com"    "Home"   "Maker"   "F" "US"

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              Population Complete!                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Stores     : 4  (DEFAULT, ELECTRONICS, FASHION,        ║"
echo "║                    HOMESTORE)                           ║"
echo "║  Categories : 19  (across all stores)                   ║"
echo "║  Brands     : 21  (across all stores)                   ║"
echo "║  Products   : 34  (linked to categories and brands)     ║"
echo "║  Customers  : 10  (across all stores)                   ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Useful endpoints:                                       ║"
echo "║  GET $BASE_URL/api/v1/category?store=DEFAULT"
echo "║  GET $BASE_URL/api/v1/products?store=ELECTRONICS"
echo "║  GET $BASE_URL/api/v1/manufacturers?store=FASHION"
echo "║  GET $BASE_URL/api/v1/store/ELECTRONICS"
echo "║  Customer login: john.doe2@example.com / password123    ║"
echo "╚══════════════════════════════════════════════════════════╝"
