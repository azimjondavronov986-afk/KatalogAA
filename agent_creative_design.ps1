$root = "D:\My Project\KatalogA"

Set-Content -Encoding UTF8 -Path "$root\app\templates\agent\catalog.html" -Value @'
<!DOCTYPE html>
<html lang="uz">
<head>
    <meta charset="UTF-8">
    <title>Agent katalogi - KatalogA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="/static/css/style.css" rel="stylesheet">
    <link href="/static/css/agent_creative.css" rel="stylesheet">
</head>
<body class="agent-creative-body">

<div class="agent-creative-header">
    <div class="agent-creative-header-inner">
        <div>
            <div class="agent-brand-mark">KatalogA</div>
            <div class="agent-brand-text">Agent katalogi</div>
        </div>

        <a class="agent-exit-btn" href="/agent/logout">Chiqish</a>
    </div>
</div>

<div class="agent-creative-wrap">

    <section class="agent-hero-card">
        <div class="hero-glow hero-glow-one"></div>
        <div class="hero-glow hero-glow-two"></div>

        <div class="hero-content">
            <span class="hero-label">Katalog rejimi</span>
            <h1>Mahsulotlar ro'yxati</h1>
            <p>Agentlar uchun qulay, tez va mobilga mos mahsulot katalogi.</p>
        </div>
    </section>

    <div class="agent-category-bar">
        <a href="/agent" class="agent-cat-btn {% if not selected_category %}active{% endif %}">
            Hammasi
        </a>

        {% for category in categories %}
        <a href="/agent?category={{ category.id }}" class="agent-cat-btn {% if selected_category == category.id|string %}active{% endif %}">
            {{ category.name }}
        </a>
        {% endfor %}
    </div>

    <div class="agent-products-creative-grid">
        {% for product in products %}
        <div class="agent-mini-card">
            <div class="agent-mini-image-box">
                {% if product.image %}
                <img class="agent-mini-image" src="/static/uploads/{{ product.image }}" alt="{{ product.name }}">
                {% else %}
                <div class="agent-mini-no-image">Rasm yo'q</div>
                {% endif %}
            </div>

            <div class="agent-mini-info">
                <h3>{{ product.name }}</h3>
                <div class="agent-mini-price">{{ product.price }} so'm</div>
            </div>
        </div>
        {% else %}
        <div class="agent-empty-box">
            <h3>Mahsulot topilmadi</h3>
            <p>Bu kategoriyada hozircha mahsulot yo'q.</p>
        </div>
        {% endfor %}
    </div>

</div>

</body>
</html>
'@

Set-Content -Encoding UTF8 -Path "$root\app\static\css\agent_creative.css" -Value @'
/* ==============================
   AGENT CREATIVE CATALOG DESIGN
   ============================== */

.agent-creative-body {
    margin: 0;
    min-height: 100vh;
    background:
        radial-gradient(circle at top left, rgba(34, 197, 94, 0.16), transparent 34%),
        radial-gradient(circle at top right, rgba(59, 130, 246, 0.16), transparent 32%),
        linear-gradient(180deg, #f8fafc 0%, #eef2f7 100%);
    color: #111827;
    padding-bottom: 34px;
}

.agent-creative-header {
    position: sticky;
    top: 0;
    z-index: 80;
    background: rgba(255, 255, 255, 0.78);
    backdrop-filter: blur(18px);
    border-bottom: 1px solid rgba(226, 232, 240, 0.9);
    box-shadow: 0 10px 30px rgba(15, 23, 42, 0.06);
}

.agent-creative-header-inner {
    width: min(1120px, 94%);
    margin: 0 auto;
    min-height: 68px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 14px;
}

.agent-brand-mark {
    font-size: 24px;
    font-weight: 950;
    letter-spacing: -0.7px;
    color: #111827;
}

.agent-brand-text {
    margin-top: 2px;
    font-size: 13px;
    font-weight: 700;
    color: #64748b;
}

.agent-exit-btn {
    border: 1px solid rgba(15, 23, 42, 0.08);
    background: #111827;
    color: #ffffff;
    padding: 9px 14px;
    border-radius: 999px;
    font-size: 13px;
    font-weight: 850;
    box-shadow: 0 8px 22px rgba(15, 23, 42, 0.18);
}

.agent-creative-wrap {
    width: min(1120px, 94%);
    margin: 0 auto;
}

.agent-hero-card {
    position: relative;
    overflow: hidden;
    margin: 18px 0 14px;
    padding: 22px;
    border-radius: 28px;
    background:
        linear-gradient(135deg, rgba(17, 24, 39, 0.98), rgba(31, 41, 55, 0.96)),
        #111827;
    color: #ffffff;
    box-shadow: 0 18px 42px rgba(15, 23, 42, 0.18);
}

.hero-content {
    position: relative;
    z-index: 2;
}

.hero-label {
    display: inline-flex;
    align-items: center;
    padding: 7px 11px;
    border-radius: 999px;
    background: rgba(34, 197, 94, 0.18);
    color: #bbf7d0;
    font-size: 12px;
    font-weight: 900;
    letter-spacing: 0.2px;
    margin-bottom: 10px;
}

.agent-hero-card h1 {
    margin: 0;
    font-size: 34px;
    line-height: 1.05;
    letter-spacing: -1px;
    font-weight: 950;
}

.agent-hero-card p {
    margin: 10px 0 0;
    max-width: 560px;
    color: rgba(255, 255, 255, 0.76);
    font-size: 15px;
    line-height: 1.55;
}

.hero-glow {
    position: absolute;
    border-radius: 999px;
    filter: blur(2px);
    opacity: 0.88;
}

.hero-glow-one {
    width: 150px;
    height: 150px;
    right: -38px;
    top: -38px;
    background: rgba(34, 197, 94, 0.34);
}

.hero-glow-two {
    width: 120px;
    height: 120px;
    right: 88px;
    bottom: -54px;
    background: rgba(59, 130, 246, 0.34);
}

.agent-category-bar {
    display: flex;
    gap: 9px;
    overflow-x: auto;
    padding: 5px 2px 16px;
    margin-bottom: 4px;
    scrollbar-width: none;
}

.agent-category-bar::-webkit-scrollbar {
    display: none;
}

.agent-cat-btn {
    flex: 0 0 auto;
    padding: 9px 14px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.88);
    border: 1px solid rgba(226, 232, 240, 0.95);
    color: #111827;
    font-size: 13px;
    font-weight: 900;
    box-shadow: 0 8px 18px rgba(15, 23, 42, 0.06);
}

.agent-cat-btn.active {
    background: #16a34a;
    color: #ffffff;
    border-color: #16a34a;
    box-shadow: 0 10px 22px rgba(22, 163, 74, 0.28);
}

.agent-products-creative-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(145px, 1fr));
    gap: 14px;
}

.agent-mini-card {
    background: rgba(255, 255, 255, 0.94);
    border: 1px solid rgba(226, 232, 240, 0.95);
    border-radius: 22px;
    overflow: hidden;
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.07);
    transition: transform 0.18s ease, box-shadow 0.18s ease;
}

.agent-mini-card:hover {
    transform: translateY(-3px);
    box-shadow: 0 18px 38px rgba(15, 23, 42, 0.12);
}

.agent-mini-image-box {
    width: 100%;
    height: 145px;
    background:
        radial-gradient(circle at center, #ffffff 0%, #f8fafc 48%, #e5e7eb 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 10px;
    overflow: hidden;
}

.agent-mini-image {
    width: 100%;
    height: 100%;
    object-fit: contain;
    display: block;
    border-radius: 14px;
}

.agent-mini-no-image {
    width: 100%;
    height: 100%;
    border-radius: 14px;
    background: #e5e7eb;
    color: #64748b;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 900;
    font-size: 13px;
}

.agent-mini-info {
    text-align: center;
    padding: 11px 10px 13px;
}

.agent-mini-info h3 {
    margin: 0 0 7px;
    min-height: 37px;
    font-size: 14px;
    line-height: 1.28;
    font-weight: 950;
    color: #111827;
    text-align: center;

    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

.agent-mini-price {
    text-align: center;
    color: #16a34a;
    font-size: 15px;
    font-weight: 950;
    letter-spacing: -0.2px;
}

.agent-empty-box {
    grid-column: 1 / -1;
    text-align: center;
    background: rgba(255, 255, 255, 0.95);
    padding: 28px;
    border-radius: 24px;
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.07);
}

.agent-empty-box h3 {
    margin: 0 0 7px;
    font-weight: 950;
}

.agent-empty-box p {
    margin: 0;
    color: #64748b;
}

/* Tablet */
@media (max-width: 900px) {
    .agent-products-creative-grid {
        grid-template-columns: repeat(auto-fill, minmax(135px, 1fr));
        gap: 12px;
    }

    .agent-mini-image-box {
        height: 135px;
    }
}

/* Mobile */
@media (max-width: 620px) {
    .agent-creative-header-inner {
        min-height: 62px;
    }

    .agent-brand-mark {
        font-size: 21px;
    }

    .agent-brand-text {
        font-size: 12px;
    }

    .agent-exit-btn {
        padding: 8px 12px;
        font-size: 12px;
    }

    .agent-hero-card {
        margin: 13px 0 12px;
        padding: 18px;
        border-radius: 24px;
    }

    .agent-hero-card h1 {
        font-size: 25px;
    }

    .agent-hero-card p {
        font-size: 13px;
    }

    .hero-label {
        font-size: 11px;
        padding: 6px 10px;
    }

    .agent-products-creative-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 11px;
    }

    .agent-mini-card {
        border-radius: 18px;
    }

    .agent-mini-image-box {
        height: 122px;
        padding: 8px;
    }

    .agent-mini-image {
        border-radius: 12px;
    }

    .agent-mini-info {
        padding: 9px 8px 11px;
    }

    .agent-mini-info h3 {
        font-size: 13px;
        min-height: 34px;
        margin-bottom: 6px;
    }

    .agent-mini-price {
        font-size: 14px;
    }

    .agent-cat-btn {
        font-size: 12px;
        padding: 8px 12px;
    }
}

/* Very small phones */
@media (max-width: 380px) {
    .agent-products-creative-grid {
        gap: 9px;
    }

    .agent-mini-image-box {
        height: 112px;
    }

    .agent-mini-info h3 {
        font-size: 12px;
    }

    .agent-mini-price {
        font-size: 13px;
    }
}
'@

Get-ChildItem -Path $root -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force

Write-Host ""
Write-Host "✅ Agent sahifasi kreativ dizaynga o'tkazildi!" -ForegroundColor Green
Write-Host "✅ Cardlar kichikroq qilindi." -ForegroundColor Green
Write-Host "✅ Mahsulot nomi va narxi center qilindi." -ForegroundColor Green
Write-Host "✅ Mahsulot nomi qalin qilindi." -ForegroundColor Green
Write-Host "✅ Narx rangi yashil holatda qoldi." -ForegroundColor Green
Write-Host ""
Write-Host "Tekshirish: http://127.0.0.1:8000/agent/login"