$root = "D:\My Project\KatalogA"

Set-Content -Encoding UTF8 -Path "$root\app\templates\agent\catalog.html" -Value @'
<!DOCTYPE html>
<html lang="uz">
<head>
    <meta charset="UTF-8">
    <title>Agent katalog - KatalogA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="/static/css/style.css" rel="stylesheet">
</head>
<body class="agent-body">

<div class="agent-header">
    <div class="agent-header-inner">
        <div>
            <div class="agent-logo">KatalogA</div>
            <div class="agent-subtitle">Agent katalog paneli</div>
        </div>

        <a class="agent-logout" href="/agent/logout">Chiqish</a>
    </div>
</div>

<div class="agent-container">
    <div class="agent-title-box">
        <h1>Mahsulotlar katalogi</h1>
        <p>Mahsulot rasmi, nomi va narxini ko‘rish uchun qulay katalog.</p>
    </div>

    <div class="agent-category-scroll">
        <a href="/agent" class="agent-category-pill {% if not selected_category %}active{% endif %}">
            Hammasi
        </a>

        {% for category in categories %}
        <a href="/agent?category={{ category.id }}" class="agent-category-pill {% if selected_category == category.id|string %}active{% endif %}">
            {{ category.name }}
        </a>
        {% endfor %}
    </div>

    <div class="agent-products-grid">
        {% for product in products %}
        <div class="agent-product-card">
            <div class="agent-product-image-box">
                {% if product.image %}
                <img class="agent-product-image" src="/static/uploads/{{ product.image }}" alt="{{ product.name }}">
                {% else %}
                <div class="agent-no-image">Rasm yo‘q</div>
                {% endif %}
            </div>

            <div class="agent-product-info">
                <h3>{{ product.name }}</h3>
                <div class="agent-product-price">{{ product.price }} so‘m</div>
            </div>
        </div>
        {% else %}
        <div class="agent-empty">
            <h3>Mahsulot topilmadi</h3>
            <p>Bu kategoriyada hozircha mahsulot yo‘q.</p>
        </div>
        {% endfor %}
    </div>
</div>

</body>
</html>
'@

Add-Content -Encoding UTF8 -Path "$root\app\static\css\style.css" -Value @'

/* =========================
   AGENT MOBILE CATALOG DESIGN
   ========================= */

.agent-body {
    background: #f3f5f7;
    color: #111827;
    padding-bottom: 32px;
}

.agent-header {
    position: sticky;
    top: 0;
    z-index: 50;
    background: rgba(17, 24, 39, 0.96);
    backdrop-filter: blur(12px);
    color: white;
    box-shadow: 0 10px 30px rgba(15, 23, 42, 0.18);
}

.agent-header-inner {
    width: min(1180px, 94%);
    margin: 0 auto;
    min-height: 74px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 14px;
}

.agent-logo {
    font-size: 24px;
    font-weight: 900;
    letter-spacing: -0.5px;
}

.agent-subtitle {
    font-size: 13px;
    opacity: 0.78;
    margin-top: 4px;
}

.agent-logout {
    background: rgba(255,255,255,0.12);
    color: white;
    padding: 10px 14px;
    border-radius: 999px;
    font-size: 14px;
    font-weight: 700;
}

.agent-container {
    width: min(1180px, 94%);
    margin: 0 auto;
}

.agent-title-box {
    margin: 22px 0 16px;
    background: linear-gradient(135deg, #ffffff, #f9fafb);
    padding: 22px;
    border-radius: 24px;
    box-shadow: 0 12px 34px rgba(15, 23, 42, 0.07);
}

.agent-title-box h1 {
    margin: 0;
    font-size: 32px;
    letter-spacing: -0.8px;
}

.agent-title-box p {
    margin: 8px 0 0;
    color: #6b7280;
    line-height: 1.5;
}

.agent-category-scroll {
    display: flex;
    gap: 10px;
    overflow-x: auto;
    padding: 4px 0 16px;
    margin-bottom: 8px;
    scrollbar-width: none;
}

.agent-category-scroll::-webkit-scrollbar {
    display: none;
}

.agent-category-pill {
    flex: 0 0 auto;
    background: white;
    color: #111827;
    padding: 11px 16px;
    border-radius: 999px;
    font-size: 14px;
    font-weight: 800;
    box-shadow: 0 6px 18px rgba(15, 23, 42, 0.08);
    border: 1px solid #eef2f7;
}

.agent-category-pill.active {
    background: #111827;
    color: white;
    border-color: #111827;
}

.agent-products-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 18px;
}

.agent-product-card {
    background: white;
    border-radius: 24px;
    overflow: hidden;
    box-shadow: 0 10px 28px rgba(15, 23, 42, 0.08);
    border: 1px solid #edf0f4;
    transition: transform .18s ease, box-shadow .18s ease;
}

.agent-product-card:hover {
    transform: translateY(-3px);
    box-shadow: 0 16px 38px rgba(15, 23, 42, 0.13);
}

.agent-product-image-box {
    width: 100%;
    aspect-ratio: 1 / 1;
    background: linear-gradient(135deg, #f8fafc, #eef2f7);
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    padding: 12px;
}

.agent-product-image {
    width: 100%;
    height: 100%;
    object-fit: contain;
    display: block;
    border-radius: 16px;
}

.agent-no-image {
    width: 100%;
    height: 100%;
    border-radius: 16px;
    background: #e5e7eb;
    color: #6b7280;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
}

.agent-product-info {
    padding: 14px 15px 16px;
}

.agent-product-info h3 {
    margin: 0 0 8px;
    font-size: 17px;
    line-height: 1.28;
    min-height: 44px;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    color: #111827;
}

.agent-product-price {
    font-size: 19px;
    font-weight: 900;
    color: #16a34a;
    letter-spacing: -0.3px;
}

.agent-empty {
    grid-column: 1 / -1;
    background: white;
    border-radius: 24px;
    padding: 28px;
    text-align: center;
    box-shadow: 0 10px 28px rgba(15, 23, 42, 0.08);
}

.agent-empty h3 {
    margin: 0 0 6px;
}

.agent-empty p {
    margin: 0;
    color: #6b7280;
}

/* Tablet */
@media (max-width: 1024px) {
    .agent-products-grid {
        grid-template-columns: repeat(3, minmax(0, 1fr));
    }
}

/* Mobile */
@media (max-width: 680px) {
    .agent-header-inner {
        min-height: 66px;
    }

    .agent-logo {
        font-size: 21px;
    }

    .agent-subtitle {
        font-size: 12px;
    }

    .agent-title-box {
        margin: 14px 0 12px;
        padding: 18px;
        border-radius: 20px;
    }

    .agent-title-box h1 {
        font-size: 24px;
    }

    .agent-title-box p {
        font-size: 14px;
    }

    .agent-products-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 12px;
    }

    .agent-product-card {
        border-radius: 18px;
    }

    .agent-product-image-box {
        padding: 9px;
        aspect-ratio: 1 / 1;
    }

    .agent-product-image {
        border-radius: 12px;
    }

    .agent-product-info {
        padding: 11px 11px 13px;
    }

    .agent-product-info h3 {
        font-size: 14px;
        min-height: 38px;
        margin-bottom: 6px;
    }

    .agent-product-price {
        font-size: 15px;
    }

    .agent-category-pill {
        padding: 9px 13px;
        font-size: 13px;
    }

    .agent-logout {
        padding: 8px 11px;
        font-size: 13px;
    }
}

/* Very small phones */
@media (max-width: 380px) {
    .agent-products-grid {
        grid-template-columns: 1fr 1fr;
        gap: 10px;
    }

    .agent-product-info h3 {
        font-size: 13px;
    }

    .agent-product-price {
        font-size: 14px;
    }
}
'@

Get-ChildItem -Path $root -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force

Write-Host ""
Write-Host "✅ Agent sahifasi mobilga mos chiroyli dizaynga o'tkazildi!" -ForegroundColor Green
Write-Host "✅ Mahsulot rasmi katta bo'lsa ham standart kvadrat joyga sig'adi." -ForegroundColor Green
Write-Host ""
Write-Host "Tekshirish:"
Write-Host "http://127.0.0.1:8000/agent/login"