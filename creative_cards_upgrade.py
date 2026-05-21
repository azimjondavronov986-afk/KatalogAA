from pathlib import Path
import re

root = Path(r"D:\My Project\KatalogA")
catalog = root / "app" / "templates" / "agent" / "catalog.html"

if not catalog.exists():
    raise SystemExit("catalog.html topilmadi")

html = catalog.read_text(encoding="utf-8")

# Oldingi shu upgrade block bo'lsa o'chirib qayta yozamiz
html = re.sub(
    r"\n?<!-- CREATIVE_CARD_UI_UPGRADE_START -->.*?<!-- CREATIVE_CARD_UI_UPGRADE_END -->\n?",
    "\n",
    html,
    flags=re.DOTALL
)

css_block = r'''
<!-- CREATIVE_CARD_UI_UPGRADE_START -->
<style>
/* =========================
   CREATIVE AGENT CATALOG UI
   ========================= */

body {
    background:
        radial-gradient(circle at top left, rgba(34,197,94,0.10), transparent 24%),
        radial-gradient(circle at top right, rgba(37,99,235,0.08), transparent 26%),
        linear-gradient(180deg, #f7fbfa 0%, #eef3f8 100%) !important;
}

/* Grid */
body .products-grid,
body .product-grid,
body .catalog-grid,
body .agent-products-grid,
body .cards-grid {
    display: grid !important;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)) !important;
    gap: 20px !important;
    align-items: stretch !important;
}

/* Card */
body .product-card,
body .catalog-card,
body .agent-card,
body .agent-mini-card,
body .product-item {
    position: relative !important;
    overflow: hidden !important;
    border-radius: 24px !important;
    border: 1px solid rgba(15, 23, 42, 0.06) !important;
    background: linear-gradient(180deg, #ffffff 0%, #f8fbff 100%) !important;
    box-shadow:
        0 14px 30px rgba(15, 23, 42, 0.08),
        0 4px 12px rgba(15, 23, 42, 0.04) !important;
    padding: 14px 14px 16px !important;
    transition: transform 0.22s ease, box-shadow 0.22s ease !important;
}

body .product-card::before,
body .catalog-card::before,
body .agent-card::before,
body .agent-mini-card::before,
body .product-item::before {
    content: "" !important;
    position: absolute !important;
    top: 0 !important;
    left: 0 !important;
    right: 0 !important;
    height: 6px !important;
    background: linear-gradient(90deg, #22c55e 0%, #10b981 35%, #2563eb 100%) !important;
    opacity: 0.95 !important;
}

body .product-card:hover,
body .catalog-card:hover,
body .agent-card:hover,
body .agent-mini-card:hover,
body .product-item:hover {
    transform: translateY(-4px) !important;
    box-shadow:
        0 18px 38px rgba(15, 23, 42, 0.12),
        0 6px 16px rgba(15, 23, 42, 0.06) !important;
}

/* Image area */
body .product-card .image-box,
body .catalog-card .image-box,
body .agent-card .image-box,
body .agent-mini-card .image-box,
body .product-item .image-box,
body .product-card .product-image-wrap,
body .catalog-card .product-image-wrap,
body .agent-card .product-image-wrap,
body .agent-mini-card .product-image-wrap,
body .product-item .product-image-wrap,
body .product-card .product-thumb,
body .catalog-card .product-thumb,
body .agent-card .product-thumb,
body .agent-mini-card .product-thumb,
body .product-item .product-thumb {
    background:
        radial-gradient(circle at top left, rgba(34,197,94,0.10), transparent 32%),
        linear-gradient(180deg, #fbfdff 0%, #eef4fb 100%) !important;
    border-radius: 18px !important;
    min-height: 138px !important;
    display: flex !important;
    align-items: center !important;
    justify-content: center !important;
    padding: 14px !important;
    margin-bottom: 12px !important;
    border: 1px solid rgba(37, 99, 235, 0.06) !important;
}

body .product-card img,
body .catalog-card img,
body .agent-card img,
body .agent-mini-card img,
body .product-item img {
    width: 100% !important;
    height: 118px !important;
    object-fit: contain !important;
    display: block !important;
    margin: 0 auto !important;
    filter: drop-shadow(0 6px 10px rgba(15,23,42,0.08)) !important;
}

/* Title */
body .product-card .product-title,
body .catalog-card .product-title,
body .agent-card .product-title,
body .agent-mini-card .product-title,
body .product-item .product-title,
body .product-card .product-name,
body .catalog-card .product-name,
body .agent-card .product-name,
body .agent-mini-card .product-name,
body .product-item .product-name,
body .product-card h3,
body .catalog-card h3,
body .agent-card h3,
body .agent-mini-card h3,
body .product-item h3 {
    margin: 0 0 10px 0 !important;
    text-align: center !important;
    font-size: 17px !important;
    line-height: 1.25 !important;
    font-weight: 800 !important;
    color: #0f172a !important;
    min-height: 42px !important;
    display: flex !important;
    align-items: center !important;
    justify-content: center !important;
}

/* Price */
body .product-card .product-price,
body .catalog-card .product-price,
body .agent-card .product-price,
body .agent-mini-card .product-price,
body .product-item .product-price,
body .product-card .price,
body .catalog-card .price,
body .agent-card .price,
body .agent-mini-card .price,
body .product-item .price {
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    gap: 6px !important;
    margin: 0 auto 12px auto !important;
    padding: 8px 14px !important;
    border-radius: 999px !important;
    background: linear-gradient(180deg, #ecfdf5 0%, #dcfce7 100%) !important;
    color: #16a34a !important;
    font-size: 15px !important;
    font-weight: 800 !important;
    box-shadow: inset 0 1px 0 rgba(255,255,255,0.75) !important;
}

/* Qty control wrap */
body .qty-control {
    display: flex !important;
    justify-content: center !important;
    align-items: center !important;
    gap: 8px !important;
    margin-top: 2px !important;
    padding: 8px !important;
    border-radius: 18px !important;
    background: linear-gradient(180deg, #f4f8fd 0%, #edf3fb 100%) !important;
    border: 1px solid rgba(15, 23, 42, 0.05) !important;
    width: fit-content !important;
    margin-left: auto !important;
    margin-right: auto !important;
}

/* Buttons */
body .qty-btn,
body .minus-btn,
body .plus-btn {
    width: 34px !important;
    height: 34px !important;
    min-width: 34px !important;
    min-height: 34px !important;
    max-width: 34px !important;
    max-height: 34px !important;
    border: none !important;
    border-radius: 12px !important;
    background: linear-gradient(180deg, #162554 0%, #0f1d49 100%) !important;
    color: #ffffff !important;
    font-size: 21px !important;
    font-weight: 900 !important;
    line-height: 1 !important;
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    box-shadow: 0 8px 16px rgba(15, 29, 73, 0.18) !important;
    cursor: pointer !important;
    transition: transform 0.18s ease, box-shadow 0.18s ease, background 0.18s ease !important;
}

body .qty-btn:hover,
body .minus-btn:hover,
body .plus-btn:hover {
    transform: translateY(-1px) !important;
    box-shadow: 0 10px 18px rgba(15, 29, 73, 0.24) !important;
}

body .qty-number,
body .qty-value {
    width: 34px !important;
    height: 34px !important;
    min-width: 34px !important;
    min-height: 34px !important;
    border-radius: 12px !important;
    background: #ffffff !important;
    color: #0f172a !important;
    border: 1px solid rgba(15,23,42,0.08) !important;
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    font-size: 16px !important;
    font-weight: 800 !important;
    box-shadow: inset 0 1px 2px rgba(15,23,42,0.04) !important;
}

/* Category chips */
body .category-chip,
body .filter-btn,
body .category-filter a,
body .category-filter button {
    border-radius: 999px !important;
    padding: 10px 18px !important;
    font-weight: 700 !important;
    border: 1px solid rgba(15,23,42,0.06) !important;
    background: rgba(255,255,255,0.82) !important;
    box-shadow: 0 8px 18px rgba(15,23,42,0.05) !important;
    backdrop-filter: blur(8px) !important;
}

/* Mobile */
@media (max-width: 768px) {
    body .products-grid,
    body .product-grid,
    body .catalog-grid,
    body .agent-products-grid,
    body .cards-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
        gap: 14px !important;
    }

    body .product-card,
    body .catalog-card,
    body .agent-card,
    body .agent-mini-card,
    body .product-item {
        border-radius: 20px !important;
        padding: 12px 12px 14px !important;
    }

    body .product-card img,
    body .catalog-card img,
    body .agent-card img,
    body .agent-mini-card img,
    body .product-item img {
        height: 102px !important;
    }

    body .product-card .product-title,
    body .catalog-card .product-title,
    body .agent-card .product-title,
    body .agent-mini-card .product-title,
    body .product-item .product-title,
    body .product-card .product-name,
    body .catalog-card .product-name,
    body .agent-card .product-name,
    body .agent-mini-card .product-name,
    body .product-item .product-name,
    body .product-card h3,
    body .catalog-card h3,
    body .agent-card h3,
    body .agent-mini-card h3,
    body .product-item h3 {
        font-size: 15px !important;
        min-height: 38px !important;
    }

    body .product-card .product-price,
    body .catalog-card .product-price,
    body .agent-card .product-price,
    body .agent-mini-card .product-price,
    body .product-item .product-price,
    body .product-card .price,
    body .catalog-card .price,
    body .agent-card .price,
    body .agent-mini-card .price,
    body .product-item .price {
        font-size: 14px !important;
        padding: 7px 12px !important;
    }

    body .qty-btn,
    body .minus-btn,
    body .plus-btn,
    body .qty-number,
    body .qty-value {
        width: 32px !important;
        height: 32px !important;
        min-width: 32px !important;
        min-height: 32px !important;
        font-size: 18px !important;
        border-radius: 11px !important;
    }
}

@media (max-width: 520px) {
    body .products-grid,
    body .product-grid,
    body .catalog-grid,
    body .agent-products-grid,
    body .cards-grid {
        gap: 12px !important;
    }

    body .product-card .image-box,
    body .catalog-card .image-box,
    body .agent-card .image-box,
    body .agent-mini-card .image-box,
    body .product-item .image-box,
    body .product-card .product-image-wrap,
    body .catalog-card .product-image-wrap,
    body .agent-card .product-image-wrap,
    body .agent-mini-card .product-image-wrap,
    body .product-item .product-image-wrap,
    body .product-card .product-thumb,
    body .catalog-card .product-thumb,
    body .agent-card .product-thumb,
    body .agent-mini-card .product-thumb,
    body .product-item .product-thumb {
        min-height: 118px !important;
        padding: 10px !important;
        margin-bottom: 10px !important;
    }

    body .product-card img,
    body .catalog-card img,
    body .agent-card img,
    body .agent-mini-card img,
    body .product-item img {
        height: 92px !important;
    }
}
</style>
<!-- CREATIVE_CARD_UI_UPGRADE_END -->
'''

if "</body>" in html:
    html = html.replace("</body>", css_block + "\n</body>")
else:
    html += "\n" + css_block

catalog.write_text(html, encoding="utf-8")

print("OK: creative card design upgrade applied")
print(catalog)