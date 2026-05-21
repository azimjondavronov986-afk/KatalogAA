$root = "D:\My Project\KatalogA"

$py = @'
from pathlib import Path
import shutil

root = Path(r"D:\My Project\KatalogA")

config_py = r'''
import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


class Settings:
    APP_NAME = os.getenv("APP_NAME", "KatalogA")
    BASE_URL = os.getenv("BASE_URL", "http://127.0.0.1:8000")

    ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin123")

    AGENT_USERNAME = os.getenv("AGENT_USERNAME", "agent")
    AGENT_PASSWORD = os.getenv("AGENT_PASSWORD", "agent123")

    BOT_TOKEN = os.getenv("BOT_TOKEN", "")
    ADMIN_IDS = os.getenv("ADMIN_IDS", "")
    ORDER_GROUP_ID = os.getenv("ORDER_GROUP_ID", "")

    TIMEZONE = os.getenv("TIMEZONE", "Asia/Tashkent")
    DATABASE_URL = f"sqlite:///{BASE_DIR / 'app.db'}"

    UPLOAD_DIR = BASE_DIR / "app" / "static" / "uploads"
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    @property
    def admin_ids_list(self):
        result = []
        for item in self.ADMIN_IDS.split(","):
            item = item.strip()
            if item.isdigit():
                result.append(int(item))
        return result


settings = Settings()
'''

models_py = r'''
from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    image = Column(String(500), nullable=True)
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    products = relationship("Product", back_populates="category")


class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=False)

    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Integer, default=0)
    image = Column(String(500), nullable=True)

    is_active = Column(Boolean, default=True)
    is_orderable = Column(Boolean, default=False)
    order_fields = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

    category = relationship("Category", back_populates="products")
    orders = relationship("Order", back_populates="product")


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)

    customer_name = Column(String(255), nullable=True)
    customer_phone = Column(String(100), nullable=True)
    quantity = Column(Integer, default=1)

    answers_json = Column(Text, nullable=True)
    status = Column(String(100), default="new")
    telegram_message_id = Column(String(100), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    product = relationship("Product", back_populates="orders")


class AgentOrder(Base):
    __tablename__ = "agent_orders"

    id = Column(Integer, primary_key=True, index=True)
    store_name = Column(String(255), nullable=False)
    status = Column(String(100), default="new")
    total_amount = Column(Integer, default=0)
    telegram_message_id = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    items = relationship("AgentOrderItem", back_populates="order")


class AgentOrderItem(Base):
    __tablename__ = "agent_order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("agent_orders.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)

    product_name = Column(String(255), nullable=False)
    price = Column(Integer, default=0)
    quantity = Column(Integer, default=1)
    line_total = Column(Integer, default=0)

    order = relationship("AgentOrder", back_populates="items")
    product = relationship("Product")
'''

telegram_py = r'''
import json
from aiogram import Bot
from aiogram.types import FSInputFile
from app.config import settings


def _chat_id():
    value = str(settings.ORDER_GROUP_ID or "").strip()
    if not value:
        return None

    try:
        return int(value)
    except Exception:
        return value


def format_order_text(order, product, category):
    try:
        answers = json.loads(order.answers_json or "{}")
    except Exception:
        answers = {}

    lines = [
        "🆕 Yangi buyurtma",
        "",
        f"📦 Mahsulot: {product.name}",
        f"🗂 Kategoriya: {category.name if category else '-'}",
        f"💰 Narx: {product.price} so'm",
        f"🔢 Soni: {order.quantity}",
        "",
        f"👤 Mijoz: {order.customer_name or '-'}",
        f"📞 Telefon: {order.customer_phone or '-'}",
        "",
        "📋 So'rovnoma:"
    ]

    for key, value in answers.items():
        lines.append(f"• {key}: {value}")

    lines.extend([
        "",
        f"🧾 Buyurtma ID: #{order.id}",
        f"📌 Status: {order.status}"
    ])

    return "\n".join(lines)


async def send_order_to_group(order, product, category):
    if not settings.BOT_TOKEN or settings.BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
        return None

    chat_id = _chat_id()
    if not chat_id:
        return None

    bot = Bot(token=settings.BOT_TOKEN)
    text = format_order_text(order, product, category)

    try:
        image_path = settings.UPLOAD_DIR / product.image if product.image else None

        if image_path and image_path.exists():
            msg = await bot.send_photo(
                chat_id=chat_id,
                photo=FSInputFile(str(image_path)),
                caption=text
            )
        else:
            msg = await bot.send_message(chat_id=chat_id, text=text)

        return str(msg.message_id)
    finally:
        await bot.session.close()


def format_catalog_order_text(order):
    lines = [
        "🆕 Yangi zakaz",
        "",
        f"🏪 Magazin: {order.store_name}",
        f"🧾 Zakaz ID: #{order.id}",
        "",
        "📦 Mahsulotlar:"
    ]

    total = 0

    for index, item in enumerate(order.items, start=1):
        total += item.line_total
        lines.append(
            f"{index}) {item.product_name}\n"
            f"   {item.quantity} dona × {item.price} so'm = {item.line_total} so'm"
        )

    lines.extend([
        "",
        f"💰 Jami: {total} so'm",
        f"📌 Status: {order.status}"
    ])

    return "\n".join(lines)


async def send_catalog_order_to_group(order):
    if not settings.BOT_TOKEN or settings.BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
        return None

    chat_id = _chat_id()
    if not chat_id:
        return None

    bot = Bot(token=settings.BOT_TOKEN)
    text = format_catalog_order_text(order)

    try:
        msg = await bot.send_message(chat_id=chat_id, text=text)
        return str(msg.message_id)
    finally:
        await bot.session.close()
'''

agent_py = r'''
from fastapi import APIRouter, Request, Depends, Form
from fastapi.responses import RedirectResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from app.database import get_db
from app.config import BASE_DIR, settings
from app.models import Category, Product, AgentOrder, AgentOrderItem
from app.services.telegram import send_catalog_order_to_group

router = APIRouter(prefix="/agent")
templates = Jinja2Templates(directory=str(BASE_DIR / "app" / "templates"))


TEXTS = {
    "uz": {
        "login_title": "Agent panel",
        "login_subtitle": "Katalogni ko'rish uchun tizimga kiring.",
        "login": "Login",
        "password": "Parol",
        "enter": "Kirish",
        "wrong": "Login yoki parol noto'g'ri",

        "brand_subtitle": "Agent katalogi",
        "logout": "Chiqish",
        "mode": "Katalog rejimi",
        "title": "Mahsulotlar ro'yxati",
        "subtitle": "Mahsulotni tanlang, miqdorni belgilang va zakazni tasdiqlang.",
        "all": "Hammasi",
        "no_image": "Rasm yo'q",
        "not_found": "Mahsulot topilmadi",
        "not_found_text": "Bu kategoriyada hozircha mahsulot yo'q.",
        "currency": "so'm",

        "order_btn": "Zakazi",
        "order_title": "Zakazi",
        "store_name": "Magazin nomi",
        "store_placeholder": "Masalan: Ali Market",
        "selected_products": "Tanlangan mahsulotlar",
        "empty_cart": "Zakaz hali bo'sh",
        "total": "Jami",
        "confirm_order": "Zakazni tasdiqlash",
        "clear": "Tozalash",
        "close": "Yopish",
        "success": "Zakaz qabul qilindi",
        "fill_store": "Magazin nomini yozing",
        "add_products": "Avval mahsulot tanlang"
    },
    "ru": {
        "login_title": "\u041f\u0430\u043d\u0435\u043b\u044c \u0430\u0433\u0435\u043d\u0442\u0430",
        "login_subtitle": "\u0412\u043e\u0439\u0434\u0438\u0442\u0435 \u0432 \u0441\u0438\u0441\u0442\u0435\u043c\u0443, \u0447\u0442\u043e\u0431\u044b \u043f\u043e\u0441\u043c\u043e\u0442\u0440\u0435\u0442\u044c \u043a\u0430\u0442\u0430\u043b\u043e\u0433.",
        "login": "\u041b\u043e\u0433\u0438\u043d",
        "password": "\u041f\u0430\u0440\u043e\u043b\u044c",
        "enter": "\u0412\u043e\u0439\u0442\u0438",
        "wrong": "\u041d\u0435\u0432\u0435\u0440\u043d\u044b\u0439 \u043b\u043e\u0433\u0438\u043d \u0438\u043b\u0438 \u043f\u0430\u0440\u043e\u043b\u044c",

        "brand_subtitle": "\u041a\u0430\u0442\u0430\u043b\u043e\u0433 \u0430\u0433\u0435\u043d\u0442\u0430",
        "logout": "\u0412\u044b\u0445\u043e\u0434",
        "mode": "\u0420\u0435\u0436\u0438\u043c \u043a\u0430\u0442\u0430\u043b\u043e\u0433\u0430",
        "title": "\u0421\u043f\u0438\u0441\u043e\u043a \u0442\u043e\u0432\u0430\u0440\u043e\u0432",
        "subtitle": "\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0442\u043e\u0432\u0430\u0440, \u0443\u043a\u0430\u0436\u0438\u0442\u0435 \u043a\u043e\u043b\u0438\u0447\u0435\u0441\u0442\u0432\u043e \u0438 \u043f\u043e\u0434\u0442\u0432\u0435\u0440\u0434\u0438\u0442\u0435 \u0437\u0430\u043a\u0430\u0437.",
        "all": "\u0412\u0441\u0435",
        "no_image": "\u041d\u0435\u0442 \u0444\u043e\u0442\u043e",
        "not_found": "\u0422\u043e\u0432\u0430\u0440 \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d",
        "not_found_text": "\u0412 \u044d\u0442\u043e\u0439 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438 \u043f\u043e\u043a\u0430 \u043d\u0435\u0442 \u0442\u043e\u0432\u0430\u0440\u043e\u0432.",
        "currency": "\u0441\u0443\u043c",

        "order_btn": "\u0417\u0430\u043a\u0430\u0437",
        "order_title": "\u0417\u0430\u043a\u0430\u0437",
        "store_name": "\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u043c\u0430\u0433\u0430\u0437\u0438\u043d\u0430",
        "store_placeholder": "\u041d\u0430\u043f\u0440\u0438\u043c\u0435\u0440: Ali Market",
        "selected_products": "\u0412\u044b\u0431\u0440\u0430\u043d\u043d\u044b\u0435 \u0442\u043e\u0432\u0430\u0440\u044b",
        "empty_cart": "\u0417\u0430\u043a\u0430\u0437 \u043f\u043e\u043a\u0430 \u043f\u0443\u0441\u0442",
        "total": "\u0418\u0442\u043e\u0433\u043e",
        "confirm_order": "\u041f\u043e\u0434\u0442\u0432\u0435\u0440\u0434\u0438\u0442\u044c \u0437\u0430\u043a\u0430\u0437",
        "clear": "\u041e\u0447\u0438\u0441\u0442\u0438\u0442\u044c",
        "close": "\u0417\u0430\u043a\u0440\u044b\u0442\u044c",
        "success": "\u0417\u0430\u043a\u0430\u0437 \u043f\u0440\u0438\u043d\u044f\u0442",
        "fill_store": "\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u043c\u0430\u0433\u0430\u0437\u0438\u043d\u0430",
        "add_products": "\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0432\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0442\u043e\u0432\u0430\u0440"
    }
}


def get_lang(request: Request):
    lang = request.query_params.get("lang") or request.cookies.get("agent_lang") or "uz"
    if lang not in TEXTS:
        lang = "uz"
    return lang


def agent_ok(request: Request):
    return request.cookies.get("agent_auth") == "yes"


@router.get("/login")
def login_page(request: Request):
    lang = get_lang(request)

    response = templates.TemplateResponse(
        "agent/login.html",
        {
            "request": request,
            "error": None,
            "lang": lang,
            "t": TEXTS[lang]
        }
    )
    response.set_cookie("agent_lang", lang, httponly=False)
    return response


@router.post("/login")
def login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    lang: str = Form("uz")
):
    if lang not in TEXTS:
        lang = "uz"

    if username == settings.AGENT_USERNAME and password == settings.AGENT_PASSWORD:
        response = RedirectResponse(f"/agent?lang={lang}", status_code=302)
        response.set_cookie("agent_auth", "yes", httponly=True)
        response.set_cookie("agent_lang", lang, httponly=False)
        return response

    response = templates.TemplateResponse(
        "agent/login.html",
        {
            "request": request,
            "error": TEXTS[lang]["wrong"],
            "lang": lang,
            "t": TEXTS[lang]
        }
    )
    response.set_cookie("agent_lang", lang, httponly=False)
    return response


@router.get("/logout")
def logout(request: Request):
    lang = get_lang(request)
    response = RedirectResponse(f"/agent/login?lang={lang}", status_code=302)
    response.delete_cookie("agent_auth")
    response.set_cookie("agent_lang", lang, httponly=False)
    return response


@router.get("")
def catalog(request: Request, db: Session = Depends(get_db)):
    if not agent_ok(request):
        lang = get_lang(request)
        return RedirectResponse(f"/agent/login?lang={lang}", status_code=302)

    lang = get_lang(request)

    categories = (
        db.query(Category)
        .filter(Category.is_active == True)
        .order_by(Category.sort_order.asc(), Category.id.desc())
        .all()
    )

    selected_category = request.query_params.get("category")
    query = db.query(Product).filter(Product.is_active == True)

    if selected_category and selected_category.isdigit():
        query = query.filter(Product.category_id == int(selected_category))

    products = query.order_by(Product.id.desc()).all()

    response = templates.TemplateResponse(
        "agent/catalog.html",
        {
            "request": request,
            "categories": categories,
            "products": products,
            "selected_category": selected_category,
            "lang": lang,
            "t": TEXTS[lang]
        }
    )
    response.set_cookie("agent_lang", lang, httponly=False)
    return response


@router.post("/order")
async def create_agent_order(request: Request, db: Session = Depends(get_db)):
    if not agent_ok(request):
        return JSONResponse({"ok": False, "error": "auth"}, status_code=401)

    data = await request.json()

    store_name = str(data.get("store_name") or "").strip()
    items = data.get("items") or []

    if not store_name:
        return JSONResponse({"ok": False, "error": "store_name"}, status_code=400)

    if not isinstance(items, list) or len(items) == 0:
        return JSONResponse({"ok": False, "error": "empty_items"}, status_code=400)

    clean_items = []
    total_amount = 0

    for item in items:
        try:
            product_id = int(item.get("product_id"))
            quantity = int(item.get("quantity"))
        except Exception:
            continue

        if quantity <= 0:
            continue

        product = db.query(Product).filter(
            Product.id == product_id,
            Product.is_active == True
        ).first()

        if not product:
            continue

        line_total = int(product.price or 0) * quantity
        total_amount += line_total

        clean_items.append({
            "product": product,
            "quantity": quantity,
            "line_total": line_total
        })

    if not clean_items:
        return JSONResponse({"ok": False, "error": "empty_items"}, status_code=400)

    order = AgentOrder(
        store_name=store_name,
        status="new",
        total_amount=total_amount
    )

    db.add(order)
    db.commit()
    db.refresh(order)

    for row in clean_items:
        product = row["product"]
        order_item = AgentOrderItem(
            order_id=order.id,
            product_id=product.id,
            product_name=product.name,
            price=int(product.price or 0),
            quantity=row["quantity"],
            line_total=row["line_total"]
        )
        db.add(order_item)

    db.commit()
    db.refresh(order)

    message_id = await send_catalog_order_to_group(order)
    if message_id:
        order.telegram_message_id = message_id
        db.commit()

    return JSONResponse({
        "ok": True,
        "order_id": order.id,
        "telegram_sent": bool(message_id)
    })
'''

catalog_html = r'''<!DOCTYPE html>
<html lang="{{ lang }}">
<head>
    <meta charset="UTF-8">
    <title>{{ t.brand_subtitle }} - KatalogA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="/static/css/style.css" rel="stylesheet">
    <link href="/static/css/agent_creative.css" rel="stylesheet">
    <link href="/static/css/agent_order.css" rel="stylesheet">
</head>
<body class="agent-creative-body">

<div class="agent-creative-header">
    <div class="agent-creative-header-inner">
        <div>
            <div class="agent-brand-mark">KatalogA</div>
            <div class="agent-brand-text">{{ t.brand_subtitle }}</div>
        </div>

        <div class="agent-header-actions">
            <div class="agent-lang-switch">
                <a href="/agent?lang=uz{% if selected_category %}&category={{ selected_category }}{% endif %}" class="{% if lang == 'uz' %}active{% endif %}">UZ</a>
                <a href="/agent?lang=ru{% if selected_category %}&category={{ selected_category }}{% endif %}" class="{% if lang == 'ru' %}active{% endif %}">RU</a>
            </div>

            <button class="agent-cart-top-btn" type="button" id="openCartBtn">
                {{ t.order_btn }}
                <span id="cartTopCount">0</span>
            </button>

            <a class="agent-exit-btn" href="/agent/logout?lang={{ lang }}">{{ t.logout }}</a>
        </div>
    </div>
</div>

<div class="agent-creative-wrap">

    <section class="agent-hero-card">
        <div class="hero-glow hero-glow-one"></div>
        <div class="hero-glow hero-glow-two"></div>

        <div class="hero-content">
            <span class="hero-label">{{ t.mode }}</span>
            <h1>{{ t.title }}</h1>
            <p>{{ t.subtitle }}</p>
        </div>
    </section>

    <div class="agent-category-bar">
        <a href="/agent?lang={{ lang }}" class="agent-cat-btn {% if not selected_category %}active{% endif %}">
            {{ t.all }}
        </a>

        {% for category in categories %}
        <a href="/agent?lang={{ lang }}&category={{ category.id }}" class="agent-cat-btn {% if selected_category == category.id|string %}active{% endif %}">
            {{ category.name }}
        </a>
        {% endfor %}
    </div>

    <div class="agent-products-creative-grid">
        {% for product in products %}
        <div class="agent-mini-card order-product-card"
             data-product-id="{{ product.id }}"
             data-product-name="{{ product.name }}"
             data-product-price="{{ product.price }}">
            <div class="agent-mini-image-box">
                {% if product.image %}
                <img class="agent-mini-image" src="/static/uploads/{{ product.image }}" alt="{{ product.name }}">
                {% else %}
                <div class="agent-mini-no-image">{{ t.no_image }}</div>
                {% endif %}
            </div>

            <div class="agent-mini-info">
                <h3>{{ product.name }}</h3>
                <div class="agent-mini-price">{{ product.price }} {{ t.currency }}</div>

                <div class="qty-control">
                    <button type="button" class="qty-btn minus-btn" data-product-id="{{ product.id }}">−</button>
                    <span class="qty-number" id="qty-{{ product.id }}">0</span>
                    <button type="button" class="qty-btn plus-btn" data-product-id="{{ product.id }}">+</button>
                </div>
            </div>
        </div>
        {% else %}
        <div class="agent-empty-box">
            <h3>{{ t.not_found }}</h3>
            <p>{{ t.not_found_text }}</p>
        </div>
        {% endfor %}
    </div>

</div>

<button class="floating-cart-btn" type="button" id="floatingCartBtn">
    {{ t.order_btn }}
    <span id="floatingCartCount">0</span>
</button>

<div class="cart-modal-overlay" id="cartModal">
    <div class="cart-modal">
        <div class="cart-modal-head">
            <h2>{{ t.order_title }}</h2>
            <button type="button" class="cart-close-btn" id="closeCartBtn">×</button>
        </div>

        <label class="cart-label">{{ t.store_name }}</label>
        <input class="cart-input" id="storeNameInput" placeholder="{{ t.store_placeholder }}">

        <h3 class="cart-section-title">{{ t.selected_products }}</h3>
        <div id="cartItemsBox"></div>

        <div class="cart-total-row">
            <span>{{ t.total }}</span>
            <strong id="cartTotalSum">0 {{ t.currency }}</strong>
        </div>

        <div class="cart-actions">
            <button type="button" class="cart-clear-btn" id="clearCartBtn">{{ t.clear }}</button>
            <button type="button" class="cart-confirm-btn" id="confirmOrderBtn">{{ t.confirm_order }}</button>
        </div>
    </div>
</div>

<script>
    window.AGENT_I18N = {{ t|tojson }};
    window.AGENT_LANG = "{{ lang }}";
</script>
<script src="/static/js/agent_cart.js"></script>

</body>
</html>
'''

agent_order_css = r'''
.agent-header-actions {
    display: flex;
    align-items: center;
    gap: 10px;
}

.agent-cart-top-btn {
    border: none;
    background: #16a34a;
    color: white;
    padding: 9px 13px;
    border-radius: 999px;
    font-size: 13px;
    font-weight: 950;
    box-shadow: 0 10px 24px rgba(22, 163, 74, .25);
    cursor: pointer;
}

.agent-cart-top-btn span,
.floating-cart-btn span {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 22px;
    height: 22px;
    margin-left: 6px;
    background: white;
    color: #16a34a;
    border-radius: 999px;
    font-size: 12px;
    font-weight: 950;
}

.order-product-card .agent-mini-info h3 {
    text-align: center;
    font-weight: 950;
}

.qty-control {
    margin: 10px auto 0;
    display: grid;
    grid-template-columns: 36px 1fr 36px;
    align-items: center;
    gap: 7px;
    width: 118px;
}

.qty-btn {
    width: 36px;
    height: 34px;
    border: none;
    border-radius: 12px;
    background: #111827;
    color: white;
    font-size: 20px;
    line-height: 1;
    font-weight: 950;
    cursor: pointer;
}

.qty-btn:active {
    transform: scale(.96);
}

.qty-number {
    height: 34px;
    border-radius: 12px;
    background: #f1f5f9;
    color: #111827;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 950;
    border: 1px solid #e2e8f0;
}

.floating-cart-btn {
    position: fixed;
    right: 22px;
    bottom: 22px;
    z-index: 90;
    border: none;
    background: #16a34a;
    color: white;
    padding: 13px 16px;
    border-radius: 999px;
    font-weight: 950;
    box-shadow: 0 18px 42px rgba(22, 163, 74, .32);
    cursor: pointer;
}

.cart-modal-overlay {
    position: fixed;
    inset: 0;
    z-index: 100;
    background: rgba(15, 23, 42, .52);
    backdrop-filter: blur(7px);
    display: none;
    align-items: center;
    justify-content: center;
    padding: 18px;
}

.cart-modal-overlay.show {
    display: flex;
}

.cart-modal {
    width: min(520px, 96vw);
    max-height: 88vh;
    overflow-y: auto;
    background: white;
    border-radius: 28px;
    box-shadow: 0 28px 80px rgba(15, 23, 42, .35);
    padding: 20px;
}

.cart-modal-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 14px;
    margin-bottom: 16px;
}

.cart-modal-head h2 {
    margin: 0;
    font-size: 26px;
    font-weight: 950;
}

.cart-close-btn {
    width: 38px;
    height: 38px;
    border: none;
    border-radius: 999px;
    background: #f1f5f9;
    color: #111827;
    font-size: 24px;
    font-weight: 900;
    cursor: pointer;
}

.cart-label {
    display: block;
    font-weight: 900;
    margin-bottom: 6px;
}

.cart-input {
    width: 100%;
    margin-bottom: 14px;
}

.cart-section-title {
    margin: 14px 0 10px;
}

.cart-empty {
    background: #f8fafc;
    border: 1px dashed #cbd5e1;
    color: #64748b;
    padding: 16px;
    border-radius: 18px;
    text-align: center;
    font-weight: 800;
}

.cart-item {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 10px;
    padding: 12px;
    border-radius: 18px;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    margin-bottom: 9px;
}

.cart-item-name {
    font-weight: 950;
    margin-bottom: 5px;
}

.cart-item-meta {
    color: #64748b;
    font-weight: 800;
    font-size: 13px;
}

.cart-item-total {
    color: #16a34a;
    font-weight: 950;
    white-space: nowrap;
}

.cart-total-row {
    margin: 16px 0;
    padding: 14px;
    border-radius: 18px;
    background: #111827;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-weight: 950;
}

.cart-total-row strong {
    color: #bbf7d0;
}

.cart-actions {
    display: grid;
    grid-template-columns: 1fr 1.4fr;
    gap: 10px;
}

.cart-clear-btn,
.cart-confirm-btn {
    border: none;
    border-radius: 16px;
    padding: 13px 14px;
    font-weight: 950;
    cursor: pointer;
}

.cart-clear-btn {
    background: #e5e7eb;
    color: #111827;
}

.cart-confirm-btn {
    background: #16a34a;
    color: white;
}

.cart-confirm-btn:disabled {
    opacity: .6;
    cursor: wait;
}

@media (max-width: 620px) {
    .agent-header-actions {
        gap: 6px;
    }

    .agent-cart-top-btn {
        padding: 8px 10px;
        font-size: 12px;
    }

    .agent-cart-top-btn span {
        min-width: 20px;
        height: 20px;
        font-size: 11px;
    }

    .qty-control {
        width: 106px;
        grid-template-columns: 32px 1fr 32px;
        gap: 6px;
    }

    .qty-btn,
    .qty-number {
        height: 31px;
        border-radius: 11px;
    }

    .floating-cart-btn {
        right: 14px;
        bottom: 14px;
        padding: 12px 14px;
    }

    .cart-modal {
        padding: 16px;
        border-radius: 24px;
    }

    .cart-actions {
        grid-template-columns: 1fr;
    }
}
'''

agent_cart_js = r'''
(function () {
    const CART_KEY = "kataloga_agent_cart_v1";
    const t = window.AGENT_I18N || {};
    const currency = t.currency || "so'm";

    function money(value) {
        const n = Number(value || 0);
        return n.toLocaleString("ru-RU") + " " + currency;
    }

    function loadCart() {
        try {
            return JSON.parse(localStorage.getItem(CART_KEY) || "{}");
        } catch (e) {
            return {};
        }
    }

    function saveCart(cart) {
        localStorage.setItem(CART_KEY, JSON.stringify(cart));
    }

    function getProductData(productId) {
        const card = document.querySelector(`.order-product-card[data-product-id="${productId}"]`);
        if (!card) return null;

        return {
            product_id: Number(productId),
            name: card.dataset.productName || "",
            price: Number(card.dataset.productPrice || 0),
            quantity: 0
        };
    }

    function cartCount(cart) {
        return Object.values(cart).reduce((sum, item) => sum + Number(item.quantity || 0), 0);
    }

    function cartTotal(cart) {
        return Object.values(cart).reduce((sum, item) => {
            return sum + Number(item.price || 0) * Number(item.quantity || 0);
        }, 0);
    }

    function updateQtyViews(cart) {
        document.querySelectorAll(".qty-number").forEach(el => {
            const productId = el.id.replace("qty-", "");
            el.textContent = cart[productId] ? cart[productId].quantity : 0;
        });

        const count = cartCount(cart);

        const top = document.getElementById("cartTopCount");
        const floating = document.getElementById("floatingCartCount");

        if (top) top.textContent = count;
        if (floating) floating.textContent = count;
    }

    function renderCartModal() {
        const cart = loadCart();
        const box = document.getElementById("cartItemsBox");
        const totalBox = document.getElementById("cartTotalSum");

        if (!box || !totalBox) return;

        const items = Object.values(cart).filter(item => Number(item.quantity) > 0);

        if (items.length === 0) {
            box.innerHTML = `<div class="cart-empty">${t.empty_cart || "Zakaz hali bo'sh"}</div>`;
        } else {
            box.innerHTML = items.map(item => {
                const lineTotal = Number(item.price || 0) * Number(item.quantity || 0);
                return `
                    <div class="cart-item">
                        <div>
                            <div class="cart-item-name">${escapeHtml(item.name)}</div>
                            <div class="cart-item-meta">${item.quantity} × ${money(item.price)}</div>
                        </div>
                        <div class="cart-item-total">${money(lineTotal)}</div>
                    </div>
                `;
            }).join("");
        }

        totalBox.textContent = money(cartTotal(cart));
    }

    function escapeHtml(value) {
        return String(value || "")
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
            .replaceAll("'", "&#039;");
    }

    function openCart() {
        renderCartModal();
        document.getElementById("cartModal")?.classList.add("show");
    }

    function closeCart() {
        document.getElementById("cartModal")?.classList.remove("show");
    }

    function changeQty(productId, delta) {
        const cart = loadCart();
        const current = cart[productId] || getProductData(productId);

        if (!current) return;

        current.quantity = Math.max(0, Number(current.quantity || 0) + delta);

        if (current.quantity <= 0) {
            delete cart[productId];
        } else {
            cart[productId] = current;
        }

        saveCart(cart);
        updateQtyViews(cart);
        renderCartModal();
    }

    async function confirmOrder() {
        const storeInput = document.getElementById("storeNameInput");
        const storeName = (storeInput?.value || "").trim();
        const cart = loadCart();
        const items = Object.values(cart).filter(item => Number(item.quantity) > 0);

        if (!storeName) {
            alert(t.fill_store || "Magazin nomini yozing");
            storeInput?.focus();
            return;
        }

        if (items.length === 0) {
            alert(t.add_products || "Avval mahsulot tanlang");
            return;
        }

        const btn = document.getElementById("confirmOrderBtn");
        if (btn) btn.disabled = true;

        try {
            const response = await fetch("/agent/order", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    store_name: storeName,
                    items: items.map(item => ({
                        product_id: item.product_id,
                        quantity: item.quantity
                    }))
                })
            });

            const result = await response.json();

            if (!response.ok || !result.ok) {
                throw new Error(result.error || "error");
            }

            localStorage.removeItem(CART_KEY);
            updateQtyViews({});
            renderCartModal();
            closeCart();

            alert((t.success || "Zakaz qabul qilindi") + " #" + result.order_id);
            window.location.reload();
        } catch (e) {
            alert("Xatolik: zakaz yuborilmadi");
        } finally {
            if (btn) btn.disabled = false;
        }
    }

    document.addEventListener("click", function (event) {
        const plus = event.target.closest(".plus-btn");
        if (plus) {
            changeQty(plus.dataset.productId, 1);
            return;
        }

        const minus = event.target.closest(".minus-btn");
        if (minus) {
            changeQty(minus.dataset.productId, -1);
            return;
        }

        if (event.target.closest("#openCartBtn") || event.target.closest("#floatingCartBtn")) {
            openCart();
            return;
        }

        if (event.target.closest("#closeCartBtn")) {
            closeCart();
            return;
        }

        if (event.target.id === "cartModal") {
            closeCart();
            return;
        }

        if (event.target.closest("#clearCartBtn")) {
            localStorage.removeItem(CART_KEY);
            updateQtyViews({});
            renderCartModal();
            return;
        }

        if (event.target.closest("#confirmOrderBtn")) {
            confirmOrder();
            return;
        }
    });

    document.addEventListener("DOMContentLoaded", function () {
        updateQtyViews(loadCart());
    });
})();
'''

bot_py = r'''
import re
from pathlib import Path

from aiogram import Bot, Dispatcher, Router, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.types import (
    Message,
    CallbackQuery,
    InlineKeyboardMarkup,
    InlineKeyboardButton
)

from app.config import settings
from app.database import SessionLocal
from app.models import Category, Product

router = Router()


class AddCategory(StatesGroup):
    name = State()
    description = State()


class AddProduct(StatesGroup):
    category = State()
    name = State()
    price = State()
    description = State()
    image = State()


def is_admin(user_id: int):
    return user_id in settings.admin_ids_list


def menu():
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="➕ Mahsulot qo'shish", callback_data="add_product")],
            [InlineKeyboardButton(text="📦 Mahsulotlar", callback_data="products_list")],
            [InlineKeyboardButton(text="➕ Kategoriya qo'shish", callback_data="add_category")],
            [InlineKeyboardButton(text="🗂 Kategoriyalar", callback_data="categories_list")]
        ]
    )


def back_menu():
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="⬅️ Bosh menyu", callback_data="main_menu")]
        ]
    )


@router.message(Command("start"))
async def start(message: Message):
    if not is_admin(message.from_user.id):
        await message.answer("Sizga ruxsat yo'q.")
        return

    await message.answer("KatalogA admin bot", reply_markup=menu())


@router.callback_query(F.data == "main_menu")
async def main_menu(call: CallbackQuery, state: FSMContext):
    await state.clear()

    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    await call.message.answer("Bosh menyu", reply_markup=menu())
    await call.answer()


@router.callback_query(F.data == "add_category")
async def add_category_start(call: CallbackQuery, state: FSMContext):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    await call.message.answer("Kategoriya nomini yuboring:")
    await state.set_state(AddCategory.name)
    await call.answer()


@router.message(AddCategory.name)
async def add_category_name(message: Message, state: FSMContext):
    await state.update_data(name=message.text.strip())
    await message.answer("Kategoriya tavsifini yuboring. Kerak bo'lmasa - yuboring:")
    await state.set_state(AddCategory.description)


@router.message(AddCategory.description)
async def add_category_finish(message: Message, state: FSMContext):
    data = await state.get_data()
    description = "" if message.text.strip() == "-" else message.text.strip()

    db = SessionLocal()
    try:
        category = Category(
            name=data["name"],
            description=description,
            is_active=True,
            sort_order=0
        )
        db.add(category)
        db.commit()

        await message.answer(f"✅ Kategoriya qo'shildi: {category.name}", reply_markup=menu())
    finally:
        db.close()

    await state.clear()


@router.callback_query(F.data == "categories_list")
async def categories_list(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    db = SessionLocal()
    try:
        categories = db.query(Category).order_by(Category.id.desc()).limit(30).all()

        if not categories:
            await call.message.answer("Kategoriya yo'q.", reply_markup=back_menu())
            await call.answer()
            return

        buttons = []
        for c in categories:
            status = "✅" if c.is_active else "🚫"
            buttons.append([
                InlineKeyboardButton(text=f"{status} {c.name}", callback_data=f"cat_menu_{c.id}")
            ])

        buttons.append([InlineKeyboardButton(text="⬅️ Bosh menyu", callback_data="main_menu")])

        await call.message.answer(
            "Kategoriyalar:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("cat_menu_"))
async def category_menu(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    category_id = int(call.data.replace("cat_menu_", ""))

    db = SessionLocal()
    try:
        c = db.query(Category).filter(Category.id == category_id).first()
        if not c:
            await call.message.answer("Kategoriya topilmadi.")
            await call.answer()
            return

        status_text = "Aktiv" if c.is_active else "Yashirilgan"

        buttons = [
            [InlineKeyboardButton(
                text="🚫 Yashirish" if c.is_active else "✅ Aktiv qilish",
                callback_data=f"cat_toggle_{c.id}"
            )],
            [InlineKeyboardButton(text="⬅️ Kategoriyalar", callback_data="categories_list")]
        ]

        await call.message.answer(
            f"🗂 {c.name}\nStatus: {status_text}",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("cat_toggle_"))
async def category_toggle(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    category_id = int(call.data.replace("cat_toggle_", ""))

    db = SessionLocal()
    try:
        c = db.query(Category).filter(Category.id == category_id).first()
        if c:
            c.is_active = not c.is_active
            db.commit()
            await call.message.answer("✅ Kategoriya statusi o'zgartirildi.")
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data == "add_product")
async def add_product_start(call: CallbackQuery, state: FSMContext):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    db = SessionLocal()
    try:
        categories = db.query(Category).filter(Category.is_active == True).order_by(Category.name.asc()).all()

        if not categories:
            await call.message.answer("Avval kategoriya qo'shing.", reply_markup=menu())
            await call.answer()
            return

        buttons = []
        for c in categories:
            buttons.append([InlineKeyboardButton(text=c.name, callback_data=f"ap_cat_{c.id}")])

        await call.message.answer(
            "Mahsulot kategoriyasini tanlang:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
        await state.set_state(AddProduct.category)
    finally:
        db.close()

    await call.answer()


@router.callback_query(AddProduct.category, F.data.startswith("ap_cat_"))
async def product_category(call: CallbackQuery, state: FSMContext):
    category_id = int(call.data.replace("ap_cat_", ""))
    await state.update_data(category_id=category_id)
    await call.message.answer("Mahsulot nomini yuboring:")
    await state.set_state(AddProduct.name)
    await call.answer()


@router.message(AddProduct.name)
async def product_name(message: Message, state: FSMContext):
    await state.update_data(name=message.text.strip())
    await message.answer("Narxini yuboring. Masalan: 25000")
    await state.set_state(AddProduct.price)


@router.message(AddProduct.price)
async def product_price(message: Message, state: FSMContext):
    digits = re.sub(r"\D", "", message.text or "")
    price = int(digits) if digits else 0
    await state.update_data(price=price)
    await message.answer("Tavsif yuboring. Tavsif kerak bo'lmasa - yuboring:")
    await state.set_state(AddProduct.description)


@router.message(AddProduct.description)
async def product_description(message: Message, state: FSMContext):
    description = "" if message.text.strip() == "-" else message.text.strip()
    await state.update_data(description=description)
    await message.answer("Mahsulot rasmini yuboring. Rasm kerak bo'lmasa - yuboring:")
    await state.set_state(AddProduct.image)


@router.message(AddProduct.image)
async def product_image(message: Message, state: FSMContext, bot: Bot):
    image_name = None

    if message.photo:
        photo = message.photo[-1]
        image_name = f"tg_{photo.file_unique_id}.jpg"
        destination = settings.UPLOAD_DIR / image_name
        await bot.download(photo.file_id, destination=destination)

    data = await state.get_data()

    db = SessionLocal()
    try:
        product = Product(
            category_id=data["category_id"],
            name=data["name"],
            price=data["price"],
            description=data.get("description", ""),
            image=image_name,
            is_active=True,
            is_orderable=False,
            order_fields=""
        )
        db.add(product)
        db.commit()

        await message.answer(
            f"✅ Mahsulot qo'shildi!\n\n"
            f"📦 {product.name}\n"
            f"💰 {product.price} so'm",
            reply_markup=menu()
        )
    finally:
        db.close()

    await state.clear()


@router.callback_query(F.data == "products_list")
async def products_list(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    db = SessionLocal()
    try:
        products = db.query(Product).order_by(Product.id.desc()).limit(30).all()

        if not products:
            await call.message.answer("Mahsulot yo'q.", reply_markup=back_menu())
            await call.answer()
            return

        buttons = []
        for p in products:
            status = "✅" if p.is_active else "🚫"
            buttons.append([
                InlineKeyboardButton(text=f"{status} {p.name}", callback_data=f"prod_menu_{p.id}")
            ])

        buttons.append([InlineKeyboardButton(text="⬅️ Bosh menyu", callback_data="main_menu")])

        await call.message.answer(
            "Mahsulotlar:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("prod_menu_"))
async def product_menu(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    product_id = int(call.data.replace("prod_menu_", ""))

    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if not p:
            await call.message.answer("Mahsulot topilmadi.")
            await call.answer()
            return

        status_text = "Aktiv" if p.is_active else "Yashirilgan"
        category_name = p.category.name if p.category else "-"

        buttons = [
            [InlineKeyboardButton(
                text="🚫 Yashirish" if p.is_active else "✅ Aktiv qilish",
                callback_data=f"prod_toggle_{p.id}"
            )],
            [InlineKeyboardButton(text="⬅️ Mahsulotlar", callback_data="products_list")]
        ]

        text = (
            f"📦 {p.name}\n"
            f"🗂 Kategoriya: {category_name}\n"
            f"💰 Narx: {p.price} so'm\n"
            f"📌 Status: {status_text}"
        )

        if p.image and (settings.UPLOAD_DIR / p.image).exists():
            await call.message.answer_photo(
                photo=(settings.UPLOAD_DIR / p.image).open("rb"),
                caption=text,
                reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
            )
        else:
            await call.message.answer(
                text,
                reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
            )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("prod_toggle_"))
async def product_toggle(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo'q", show_alert=True)
        return

    product_id = int(call.data.replace("prod_toggle_", ""))

    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if p:
            p.is_active = not p.is_active
            db.commit()
            await call.message.answer("✅ Mahsulot statusi o'zgartirildi.")
    finally:
        db.close()

    await call.answer()


async def start_bot():
    if not settings.BOT_TOKEN or settings.BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
        print("BOT_TOKEN .env faylida yozilmagan")
        return

    bot = Bot(token=settings.BOT_TOKEN)
    dp = Dispatcher(storage=MemoryStorage())
    dp.include_router(router)

    print("Telegram bot ishga tushdi")
    await dp.start_polling(bot)
'''

main_py = r'''
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# Jinja TemplateResponse compatibility fix
_original_template_response = Jinja2Templates.TemplateResponse


def _template_response_compat(self, *args, **kwargs):
    if len(args) >= 2 and isinstance(args[0], str) and isinstance(args[1], dict):
        name = args[0]
        context = dict(args[1])
        request = context.pop("request", None)

        if request is None:
            raise RuntimeError("Template context ichida request topilmadi")

        return _original_template_response(
            self,
            request,
            name,
            context,
            *args[2:],
            **kwargs
        )

    return _original_template_response(self, *args, **kwargs)


Jinja2Templates.TemplateResponse = _template_response_compat

from app.database import init_db
from app.config import BASE_DIR, settings
from app.routes import web, admin, agent

app = FastAPI(title=settings.APP_NAME)

app.mount(
    "/static",
    StaticFiles(directory=str(BASE_DIR / "app" / "static")),
    name="static"
)


@app.on_event("startup")
def startup_event():
    init_db()


app.include_router(web.router)
app.include_router(admin.router)
app.include_router(agent.router)
'''

(root / "app" / "config.py").write_text(config_py, encoding="utf-8")
(root / "app" / "models.py").write_text(models_py, encoding="utf-8")
(root / "app" / "services" / "telegram.py").write_text(telegram_py, encoding="utf-8")
(root / "app" / "routes" / "agent.py").write_text(agent_py, encoding="utf-8")
(root / "app" / "templates" / "agent" / "catalog.html").write_text(catalog_html, encoding="utf-8")
(root / "app" / "static" / "css" / "agent_order.css").write_text(agent_order_css, encoding="utf-8")
(root / "app" / "static" / "js" / "agent_cart.js").write_text(agent_cart_js, encoding="utf-8")
(root / "app" / "bot" / "main.py").write_text(bot_py, encoding="utf-8")
(root / "app" / "main.py").write_text(main_py, encoding="utf-8")

for p in root.rglob("__pycache__"):
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)

print("✅ Zakazi/cart va Telegram bot katalog boshqaruvi qo'shildi")
'@

$fixPath = "$root\catalog_order_update.py"
Set-Content -Encoding UTF8 -Path $fixPath -Value $py

cd $root
python $fixPath

Write-Host ""
Write-Host "✅ O'zgarishlar yozildi!" -ForegroundColor Green
Write-Host "✅ Agent sahifasiga Zakazi qo'shildi." -ForegroundColor Green
Write-Host "✅ Buyurtma DB ga yoziladi va Telegram guruhga yuboriladi." -ForegroundColor Green
Write-Host "✅ Telegram bot orqali kategoriya/mahsulot qo'shish va yashirish qo'shildi." -ForegroundColor Green
Write-Host ""
Write-Host "Endi web va botni qayta ishga tushiring." -ForegroundColor Yellow