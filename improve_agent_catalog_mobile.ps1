$root = "D:\My Project\KatalogA"

$py = @'
from pathlib import Path
import shutil

root = Path(r"D:\My Project\KatalogA")

TEXT_EXTS = {".py", ".html", ".js", ".css", ".txt", ".md"}

# 1) Valyuta yozuvlarini "сомон" ga o'tkazish
replacements = {
    "сомонӣ": "сомон",
    "сомони": "сомон",
    "сум": "сомон",
    "so'm": "somon",
    "so‘m": "somon",
    "so’m": "somon",

    r"\u0441\u043e\u043c\u043e\u043d\u04e3": r"\u0441\u043e\u043c\u043e\u043d",
    r"\u0441\u0443\u043c": r"\u0441\u043e\u043c\u043e\u043d",
}

updated_files = []

for path in root.rglob("*"):
    if path.is_file() and path.suffix.lower() in TEXT_EXTS:
        try:
            text = path.read_text(encoding="utf-8")
        except:
            continue

        original = text
        for old, new in replacements.items():
            text = text.replace(old, new)

        if text != original:
            path.write_text(text, encoding="utf-8")
            updated_files.append(str(path))

# 2) Agent katalog template ni topish
catalog_candidates = [
    root / "app" / "templates" / "agent" / "catalog.html",
    root / "app" / "templates" / "agent" / "index.html",
]

catalog_file = None
for c in catalog_candidates:
    if c.exists():
        catalog_file = c
        break

if not catalog_file:
    for p in (root / "app" / "templates").rglob("*.html"):
        if "agent" in str(p).lower() and "catalog" in p.name.lower():
            catalog_file = p
            break

style_marker = "/* KATALOGAA_AGENT_MOBILE_POLISH_V2 */"

style_block = r'''
<style>
/* KATALOGAA_AGENT_MOBILE_POLISH_V2 */

.product-grid,
.products-grid,
.catalog-grid,
.cards-grid {
  display: grid !important;
  grid-template-columns: repeat(auto-fit, minmax(175px, 1fr)) !important;
  gap: 16px !important;
  align-items: stretch !important;
}

.product-card,
.catalog-card,
.item-card,
.product-item {
  border-radius: 20px !important;
  overflow: hidden !important;
  box-shadow: 0 8px 24px rgba(12, 27, 63, 0.08) !important;
  transition: transform .18s ease, box-shadow .18s ease !important;
  height: 100% !important;
}

.product-card:hover,
.catalog-card:hover,
.item-card:hover,
.product-item:hover {
  transform: translateY(-2px) !important;
  box-shadow: 0 12px 28px rgba(12, 27, 63, 0.12) !important;
}

.product-card img,
.catalog-card img,
.item-card img,
.product-image,
.product-thumb,
.card-image img {
  width: 100% !important;
  height: 145px !important;
  object-fit: contain !important;
  object-position: center !important;
  background: #f8fafc !important;
  border-radius: 14px !important;
  padding: 10px !important;
}

.product-title,
.card-title,
.product-name,
.item-title {
  font-weight: 800 !important;
  text-align: center !important;
  line-height: 1.25 !important;
  min-height: 44px !important;
  display: -webkit-box !important;
  -webkit-line-clamp: 2 !important;
  -webkit-box-orient: vertical !important;
  overflow: hidden !important;
  margin-bottom: 8px !important;
}

.product-price,
.card-price,
.item-price,
.price {
  text-align: center !important;
  font-weight: 800 !important;
  color: #16a34a !important;
  font-size: 26px !important;
  line-height: 1.1 !important;
  white-space: nowrap !important;
  margin-bottom: 12px !important;
}

.qty-controls,
.order-controls,
.counter-controls,
.quantity-controls,
.product-actions {
  display: grid !important;
  grid-template-columns: 50px 1fr 50px !important;
  gap: 8px !important;
  align-items: center !important;
  margin-top: auto !important;
}

.qty-btn,
.counter-btn,
.minus-btn,
.plus-btn,
.quantity-btn,
.product-actions button {
  min-width: 50px !important;
  min-height: 50px !important;
  border-radius: 14px !important;
  border: none !important;
  background: #0f172a !important;
  color: #fff !important;
  font-size: 28px !important;
  font-weight: 900 !important;
  line-height: 1 !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
  cursor: pointer !important;
  touch-action: manipulation !important;
  -webkit-tap-highlight-color: transparent !important;
  user-select: none !important;
  padding: 0 !important;
}

.qty-btn:hover,
.counter-btn:hover,
.minus-btn:hover,
.plus-btn:hover,
.quantity-btn:hover,
.product-actions button:hover {
  filter: brightness(1.05) !important;
}

.qty-count,
.qty-value,
.counter-value,
.quantity-value {
  min-height: 50px !important;
  border-radius: 14px !important;
  background: #f3f4f6 !important;
  color: #0f172a !important;
  font-weight: 800 !important;
  font-size: 22px !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  padding: 0 8px !important;
}

.categories-row,
.category-list,
.category-tabs,
.filters-row {
  display: flex !important;
  gap: 10px !important;
  overflow-x: auto !important;
  padding-bottom: 6px !important;
  scrollbar-width: thin !important;
}

.categories-row::-webkit-scrollbar,
.category-list::-webkit-scrollbar,
.category-tabs::-webkit-scrollbar,
.filters-row::-webkit-scrollbar {
  height: 6px !important;
}

.category-chip,
.category-btn,
.category-tab,
.filters-row a,
.filters-row button {
  white-space: nowrap !important;
  flex: 0 0 auto !important;
}

.cart-fab,
.order-fab,
.floating-cart,
.cart-button-fixed {
  right: 16px !important;
  bottom: 16px !important;
  min-height: 54px !important;
  padding: 0 18px !important;
  border-radius: 999px !important;
  font-weight: 800 !important;
  box-shadow: 0 10px 24px rgba(22, 163, 74, 0.30) !important;
}

.hero-title,
.catalog-title,
.page-title {
  line-height: 1.08 !important;
}

.hero-subtitle,
.catalog-subtitle,
.page-subtitle {
  line-height: 1.45 !important;
}

@media (max-width: 992px) {
  .product-grid,
  .products-grid,
  .catalog-grid,
  .cards-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
  }
}

@media (max-width: 768px) {
  .product-grid,
  .products-grid,
  .catalog-grid,
  .cards-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
    gap: 12px !important;
  }

  .product-card,
  .catalog-card,
  .item-card,
  .product-item {
    border-radius: 16px !important;
  }

  .product-card img,
  .catalog-card img,
  .item-card img,
  .product-image,
  .product-thumb,
  .card-image img {
    height: 120px !important;
    padding: 8px !important;
  }

  .product-title,
  .card-title,
  .product-name,
  .item-title {
    font-size: 19px !important;
    min-height: 40px !important;
  }

  .product-price,
  .card-price,
  .item-price,
  .price {
    font-size: 22px !important;
  }

  .qty-controls,
  .order-controls,
  .counter-controls,
  .quantity-controls,
  .product-actions {
    grid-template-columns: 46px 1fr 46px !important;
    gap: 6px !important;
  }

  .qty-btn,
  .counter-btn,
  .minus-btn,
  .plus-btn,
  .quantity-btn,
  .product-actions button {
    min-width: 46px !important;
    min-height: 46px !important;
    font-size: 26px !important;
    border-radius: 12px !important;
  }

  .qty-count,
  .qty-value,
  .counter-value,
  .quantity-value {
    min-height: 46px !important;
    font-size: 20px !important;
    border-radius: 12px !important;
  }
}

@media (max-width: 520px) {
  .product-grid,
  .products-grid,
  .catalog-grid,
  .cards-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
    gap: 10px !important;
  }

  .product-card img,
  .catalog-card img,
  .item-card img,
  .product-image,
  .product-thumb,
  .card-image img {
    height: 108px !important;
  }

  .product-title,
  .card-title,
  .product-name,
  .item-title {
    font-size: 17px !important;
    min-height: 36px !important;
  }

  .product-price,
  .card-price,
  .item-price,
  .price {
    font-size: 19px !important;
  }

  .qty-btn,
  .counter-btn,
  .minus-btn,
  .plus-btn,
  .quantity-btn,
  .product-actions button {
    min-width: 42px !important;
    min-height: 42px !important;
    font-size: 24px !important;
  }

  .qty-count,
  .qty-value,
  .counter-value,
  .quantity-value {
    min-height: 42px !important;
    font-size: 18px !important;
  }

  .cart-fab,
  .order-fab,
  .floating-cart,
  .cart-button-fixed {
    right: 12px !important;
    bottom: 12px !important;
    min-height: 48px !important;
    padding: 0 14px !important;
    font-size: 15px !important;
  }
}
</style>
'''

if catalog_file and catalog_file.exists():
    html = catalog_file.read_text(encoding="utf-8")
    if style_marker not in html:
        if "</head>" in html:
            html = html.replace("</head>", style_block + "\n</head>")
        elif "</body>" in html:
            html = html.replace("</body>", style_block + "\n</body>")
        catalog_file.write_text(html, encoding="utf-8")
        updated_files.append(str(catalog_file))

# 3) Agar JS ichida "сомонй" yoki boshqa xatolik bo'lsa, tozalash
js_candidates = [
    root / "app" / "static" / "js" / "agent_cart.js",
    root / "app" / "static" / "js" / "agent.js",
]

for js_file in js_candidates:
    if js_file.exists():
        js = js_file.read_text(encoding="utf-8")
        old = js
        js = js.replace("сомонӣ", "сомон")
        js = js.replace("сомони", "сомон")
        js = js.replace("сум", "сомон")
        if js != old:
            js_file.write_text(js, encoding="utf-8")
            updated_files.append(str(js_file))

# 4) __pycache__ larni tozalash
for p in root.rglob("__pycache__"):
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)

print("UPDATED FILES:")
for f in updated_files:
    print(" -", f)

print("\nOK: Agent katalog sahifasi yaxshilandi, valyuta 'сомон' bo'ldi, +/- mobilga moslashtirildi.")
'@

$fixPath = "$root\improve_agent_catalog_mobile.py"
Set-Content -Encoding UTF8 -Path $fixPath -Value $py

cd $root
python $fixPath

Write-Host ""
Write-Host "✅ Agent katalog sahifasi yaxshilandi!" -ForegroundColor Green
Write-Host "✅ Valyuta 'сомон' ga o'tdi!" -ForegroundColor Green
Write-Host "✅ +/- tugmalar mobilga moslashtirildi!" -ForegroundColor Green
Write-Host ""
Write-Host "Endi GitHubga push qiling." -ForegroundColor Yellow