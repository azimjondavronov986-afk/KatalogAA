$root = "D:\My Project\KatalogA"

$folders = @(
    "app\routes",
    "app\services",
    "app\bot",
    "app\templates",
    "app\templates\admin",
    "app\static",
    "app\static\css",
    "app\static\uploads"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $folder) | Out-Null
}

Set-Content -Encoding UTF8 -Path "$root\app\routes\__init__.py" -Value ""
Set-Content -Encoding UTF8 -Path "$root\app\services\__init__.py" -Value ""
Set-Content -Encoding UTF8 -Path "$root\app\bot\__init__.py" -Value ""

Set-Content -Encoding UTF8 -Path "$root\app\schemas.py" -Value @'
import json

DEFAULT_ORDER_FIELDS = [
    "Ism",
    "Telefon",
    "Dona soni",
    "Izoh"
]


def parse_order_fields(value):
    if not value:
        return DEFAULT_ORDER_FIELDS

    try:
        data = json.loads(value)
        if isinstance(data, list) and data:
            return data
    except Exception:
        pass

    return DEFAULT_ORDER_FIELDS


def make_order_fields_text(fields_text):
    if not fields_text:
        return json.dumps(DEFAULT_ORDER_FIELDS, ensure_ascii=False)

    fields = []
    for line in fields_text.replace(",", "\n").splitlines():
        line = line.strip()
        if line:
            fields.append(line)

    if not fields:
        fields = DEFAULT_ORDER_FIELDS

    return json.dumps(fields, ensure_ascii=False)
'@

Set-Content -Encoding UTF8 -Path "$root\app\main.py" -Value @'
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from app.database import init_db
from app.config import BASE_DIR, settings
from app.routes import web, admin, orders

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
app.include_router(orders.router)
'@

Set-Content -Encoding UTF8 -Path "$root\app\routes\web.py" -Value @'
from fastapi import APIRouter, Request, Depends, HTTPException
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from app.database import get_db
from app.config import BASE_DIR
from app.models import Category, Product
from app.schemas import parse_order_fields

router = APIRouter()
templates = Jinja2Templates(directory=str(BASE_DIR / "app" / "templates"))


@router.get("/")
def home(request: Request, db: Session = Depends(get_db)):
    categories = (
        db.query(Category)
        .filter(Category.is_active == True)
        .order_by(Category.sort_order.asc(), Category.id.desc())
        .all()
    )

    products = (
        db.query(Product)
        .filter(Product.is_active == True)
        .order_by(Product.id.desc())
        .limit(20)
        .all()
    )

    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "categories": categories,
            "products": products
        }
    )


@router.get("/category/{category_id}")
def category_page(category_id: int, request: Request, db: Session = Depends(get_db)):
    category = db.query(Category).filter(Category.id == category_id).first()
    if not category:
        raise HTTPException(status_code=404, detail="Kategoriya topilmadi")

    products = (
        db.query(Product)
        .filter(Product.category_id == category_id, Product.is_active == True)
        .order_by(Product.id.desc())
        .all()
    )

    return templates.TemplateResponse(
        "category.html",
        {
            "request": request,
            "category": category,
            "products": products
        }
    )


@router.get("/product/{product_id}")
def product_page(product_id: int, request: Request, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Mahsulot topilmadi")

    return templates.TemplateResponse(
        "product.html",
        {
            "request": request,
            "product": product
        }
    )


@router.get("/order/{product_id}")
def order_page(product_id: int, request: Request, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Mahsulot topilmadi")

    if not product.is_orderable:
        raise HTTPException(status_code=403, detail="Bu mahsulotdan buyurtma olinmaydi")

    fields = parse_order_fields(product.order_fields)

    return templates.TemplateResponse(
        "order.html",
        {
            "request": request,
            "product": product,
            "fields": fields
        }
    )


@router.get("/thanks")
def thanks_page(request: Request):
    return templates.TemplateResponse("thanks.html", {"request": request})
'@

Set-Content -Encoding UTF8 -Path "$root\app\routes\orders.py" -Value @'
import json
from fastapi import APIRouter, Request, Depends
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Product, Order
from app.services.telegram import send_order_to_group

router = APIRouter()


@router.post("/order/{product_id}")
async def create_order(
    product_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        return RedirectResponse("/", status_code=302)

    form = await request.form()
    answers = dict(form)

    customer_name = answers.get("Ism") or answers.get("Name") or answers.get("name")
    customer_phone = answers.get("Telefon") or answers.get("Phone") or answers.get("phone")

    quantity_raw = answers.get("Dona soni") or answers.get("Soni") or answers.get("quantity") or "1"

    try:
        quantity = int(quantity_raw)
    except Exception:
        quantity = 1

    order = Order(
        product_id=product.id,
        customer_name=customer_name,
        customer_phone=customer_phone,
        quantity=quantity,
        answers_json=json.dumps(answers, ensure_ascii=False),
        status="new"
    )

    db.add(order)
    db.commit()
    db.refresh(order)

    message_id = await send_order_to_group(order, product, product.category)
    if message_id:
        order.telegram_message_id = message_id
        db.commit()

    return RedirectResponse("/thanks", status_code=302)
'@

Set-Content -Encoding UTF8 -Path "$root\app\services\telegram.py" -Value @'
import json
from aiogram import Bot
from aiogram.types import FSInputFile
from app.config import settings, BASE_DIR


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
        f"💰 Narx: {product.price} so‘m",
        f"🔢 Soni: {order.quantity}",
        "",
        f"👤 Mijoz: {order.customer_name or '-'}",
        f"📞 Telefon: {order.customer_phone or '-'}",
        "",
        "📋 So‘rovnoma:"
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

    if not settings.ORDER_GROUP_ID:
        return None

    bot = Bot(token=settings.BOT_TOKEN)
    text = format_order_text(order, product, category)

    try:
        if product.image:
            image_path = BASE_DIR / "app" / "static" / "uploads" / product.image
            if image_path.exists():
                msg = await bot.send_photo(
                    chat_id=settings.ORDER_GROUP_ID,
                    photo=FSInputFile(str(image_path)),
                    caption=text
                )
            else:
                msg = await bot.send_message(chat_id=settings.ORDER_GROUP_ID, text=text)
        else:
            msg = await bot.send_message(chat_id=settings.ORDER_GROUP_ID, text=text)

        return str(msg.message_id)
    finally:
        await bot.session.close()
'@

Set-Content -Encoding UTF8 -Path "$root\app\routes\admin.py" -Value @'
import shutil
from fastapi import APIRouter, Request, Depends, Form, UploadFile, File
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from app.database import get_db
from app.config import BASE_DIR, settings
from app.models import Category, Product, Order
from app.schemas import make_order_fields_text, parse_order_fields

router = APIRouter(prefix="/admin")
templates = Jinja2Templates(directory=str(BASE_DIR / "app" / "templates"))


def admin_ok(request: Request):
    return request.cookies.get("admin_auth") == "yes"


def save_upload(file):
    if not file or not file.filename:
        return None

    upload_dir = BASE_DIR / "app" / "static" / "uploads"
    upload_dir.mkdir(parents=True, exist_ok=True)

    clean_name = file.filename.replace(" ", "_")
    path = upload_dir / clean_name

    with path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return clean_name


@router.get("/login")
def login_page(request: Request):
    return templates.TemplateResponse(
        "admin/login.html",
        {"request": request, "error": None}
    )


@router.post("/login")
def login(request: Request, username: str = Form(...), password: str = Form(...)):
    if username == settings.ADMIN_USERNAME and password == settings.ADMIN_PASSWORD:
        response = RedirectResponse("/admin", status_code=302)
        response.set_cookie("admin_auth", "yes", httponly=True)
        return response

    return templates.TemplateResponse(
        "admin/login.html",
        {"request": request, "error": "Login yoki parol noto‘g‘ri"}
    )


@router.get("/logout")
def logout():
    response = RedirectResponse("/admin/login", status_code=302)
    response.delete_cookie("admin_auth")
    return response


@router.get("")
def dashboard(request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    return templates.TemplateResponse(
        "admin/dashboard.html",
        {
            "request": request,
            "categories_count": db.query(Category).count(),
            "products_count": db.query(Product).count(),
            "orders_count": db.query(Order).count(),
            "latest_orders": db.query(Order).order_by(Order.id.desc()).limit(10).all()
        }
    )


@router.get("/categories")
def categories_page(request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    categories = db.query(Category).order_by(Category.sort_order.asc(), Category.id.desc()).all()
    return templates.TemplateResponse(
        "admin/categories.html",
        {"request": request, "categories": categories}
    )


@router.post("/categories/add")
def add_category(
    request: Request,
    name: str = Form(...),
    description: str = Form(""),
    sort_order: int = Form(0),
    db: Session = Depends(get_db)
):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    category = Category(
        name=name,
        description=description,
        sort_order=sort_order,
        is_active=True
    )
    db.add(category)
    db.commit()
    return RedirectResponse("/admin/categories", status_code=302)


@router.get("/categories/{category_id}/edit")
def edit_category_page(category_id: int, request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    category = db.query(Category).filter(Category.id == category_id).first()
    return templates.TemplateResponse(
        "admin/category_edit.html",
        {"request": request, "category": category}
    )


@router.post("/categories/{category_id}/edit")
def edit_category(
    category_id: int,
    request: Request,
    name: str = Form(...),
    description: str = Form(""),
    sort_order: int = Form(0),
    db: Session = Depends(get_db)
):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    category = db.query(Category).filter(Category.id == category_id).first()
    if category:
        category.name = name
        category.description = description
        category.sort_order = sort_order
        db.commit()

    return RedirectResponse("/admin/categories", status_code=302)


@router.post("/categories/{category_id}/toggle")
def toggle_category(category_id: int, request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    category = db.query(Category).filter(Category.id == category_id).first()
    if category:
        category.is_active = not category.is_active
        db.commit()

    return RedirectResponse("/admin/categories", status_code=302)


@router.get("/products")
def products_page(request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    categories = db.query(Category).order_by(Category.name.asc()).all()
    products = db.query(Product).order_by(Product.id.desc()).all()

    return templates.TemplateResponse(
        "admin/products.html",
        {
            "request": request,
            "categories": categories,
            "products": products
        }
    )


@router.post("/products/add")
def add_product(
    request: Request,
    category_id: int = Form(...),
    name: str = Form(...),
    description: str = Form(""),
    price: int = Form(0),
    is_orderable: str = Form("yes"),
    order_fields: str = Form("Ism\nTelefon\nDona soni\nIzoh"),
    image: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    image_name = save_upload(image)

    product = Product(
        category_id=category_id,
        name=name,
        description=description,
        price=price,
        image=image_name,
        is_active=True,
        is_orderable=is_orderable == "yes",
        order_fields=make_order_fields_text(order_fields)
    )

    db.add(product)
    db.commit()

    return RedirectResponse("/admin/products", status_code=302)


@router.get("/products/{product_id}/edit")
def edit_product_page(product_id: int, request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    product = db.query(Product).filter(Product.id == product_id).first()
    categories = db.query(Category).order_by(Category.name.asc()).all()
    fields = "\n".join(parse_order_fields(product.order_fields)) if product else ""

    return templates.TemplateResponse(
        "admin/product_edit.html",
        {
            "request": request,
            "product": product,
            "categories": categories,
            "fields": fields
        }
    )


@router.post("/products/{product_id}/edit")
def edit_product(
    product_id: int,
    request: Request,
    category_id: int = Form(...),
    name: str = Form(...),
    description: str = Form(""),
    price: int = Form(0),
    is_orderable: str = Form("yes"),
    order_fields: str = Form("Ism\nTelefon\nDona soni\nIzoh"),
    image: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    product = db.query(Product).filter(Product.id == product_id).first()
    if product:
        product.category_id = category_id
        product.name = name
        product.description = description
        product.price = price
        product.is_orderable = is_orderable == "yes"
        product.order_fields = make_order_fields_text(order_fields)

        image_name = save_upload(image)
        if image_name:
            product.image = image_name

        db.commit()

    return RedirectResponse("/admin/products", status_code=302)


@router.post("/products/{product_id}/toggle")
def toggle_product(product_id: int, request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    product = db.query(Product).filter(Product.id == product_id).first()
    if product:
        product.is_active = not product.is_active
        db.commit()

    return RedirectResponse("/admin/products", status_code=302)


@router.get("/orders")
def orders_page(request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    orders = db.query(Order).order_by(Order.id.desc()).all()
    return templates.TemplateResponse(
        "admin/orders.html",
        {"request": request, "orders": orders}
    )


@router.post("/orders/{order_id}/status")
def change_order_status(
    order_id: int,
    request: Request,
    status: str = Form(...),
    db: Session = Depends(get_db)
):
    if not admin_ok(request):
        return RedirectResponse("/admin/login", status_code=302)

    order = db.query(Order).filter(Order.id == order_id).first()
    if order:
        order.status = status
        db.commit()

    return RedirectResponse("/admin/orders", status_code=302)
'@

Set-Content -Encoding UTF8 -Path "$root\app\static\css\style.css" -Value @'
* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f6f8;
    color: #1f2937;
}

a {
    color: inherit;
    text-decoration: none;
}

.header {
    background: #111827;
    color: white;
    padding: 18px 24px;
}

.container {
    width: min(1180px, 94%);
    margin: 0 auto;
}

.nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.nav a {
    margin-left: 16px;
    opacity: .9;
}

.hero {
    background: linear-gradient(135deg, #111827, #374151);
    color: white;
    padding: 54px 0;
    margin-bottom: 28px;
}

.hero h1 {
    font-size: 42px;
    margin: 0 0 12px;
}

.grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(230px, 1fr));
    gap: 18px;
}

.card {
    background: white;
    border-radius: 18px;
    overflow: hidden;
    box-shadow: 0 8px 22px rgba(15, 23, 42, .08);
}

.card-body {
    padding: 16px;
}

.product-img {
    width: 100%;
    height: 190px;
    object-fit: cover;
    background: #e5e7eb;
}

.btn {
    display: inline-block;
    border: none;
    border-radius: 12px;
    padding: 11px 16px;
    background: #111827;
    color: white;
    cursor: pointer;
    font-weight: 700;
    margin: 3px;
}

.btn-light {
    background: #e5e7eb;
    color: #111827;
}

.btn-green {
    background: #16a34a;
}

.btn-red {
    background: #dc2626;
}

.btn-orange {
    background: #f97316;
}

.form-box {
    background: white;
    padding: 22px;
    border-radius: 18px;
    box-shadow: 0 8px 22px rgba(15, 23, 42, .08);
    margin-bottom: 22px;
}

input, textarea, select {
    width: 100%;
    padding: 12px;
    border: 1px solid #d1d5db;
    border-radius: 12px;
    margin: 7px 0 14px;
}

textarea {
    min-height: 90px;
}

.table {
    width: 100%;
    background: white;
    border-collapse: collapse;
    border-radius: 16px;
    overflow: hidden;
}

.table th,
.table td {
    padding: 12px;
    border-bottom: 1px solid #e5e7eb;
    text-align: left;
    vertical-align: top;
}

.admin-layout {
    display: grid;
    grid-template-columns: 230px 1fr;
    min-height: 100vh;
}

.sidebar {
    background: #111827;
    color: white;
    padding: 20px;
}

.sidebar a {
    display: block;
    padding: 12px;
    border-radius: 10px;
    margin-bottom: 8px;
}

.sidebar a:hover {
    background: #374151;
}

.content {
    padding: 24px;
}

.stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 16px;
    margin-bottom: 22px;
}

.stat {
    background: white;
    padding: 20px;
    border-radius: 18px;
    box-shadow: 0 8px 22px rgba(15, 23, 42, .08);
}

.stat h2 {
    margin: 0;
    font-size: 34px;
}

.badge {
    padding: 5px 10px;
    border-radius: 999px;
    background: #e5e7eb;
    display: inline-block;
    font-size: 13px;
}

@media (max-width: 760px) {
    .admin-layout {
        grid-template-columns: 1fr;
    }

    .hero h1 {
        font-size: 30px;
    }
}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\base.html" -Value @'
<!DOCTYPE html>
<html lang="uz">
<head>
    <meta charset="UTF-8">
    <title>KatalogA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="/static/css/style.css" rel="stylesheet">
</head>
<body>
    <div class="header">
        <div class="container nav">
            <strong>KatalogA</strong>
            <div>
                <a href="/">Bosh sahifa</a>
                <a href="/admin/login">Admin</a>
            </div>
        </div>
    </div>

    {% block content %}{% endblock %}
</body>
</html>
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\index.html" -Value @'
{% extends "base.html" %}

{% block content %}
<div class="hero">
    <div class="container">
        <h1>Mahsulotlar katalogi</h1>
        <p>Kategoriyalar bo‘yicha mahsulotlarni ko‘ring va buyurtma bering.</p>
    </div>
</div>

<div class="container">
    <h2>Kategoriyalar</h2>
    <div class="grid">
        {% for category in categories %}
        <a class="card" href="/category/{{ category.id }}">
            <div class="card-body">
                <h3>{{ category.name }}</h3>
                <p>{{ category.description or "Mahsulotlarni ko‘rish" }}</p>
            </div>
        </a>
        {% else %}
        <p>Hali kategoriya qo‘shilmagan.</p>
        {% endfor %}
    </div>

    <h2 style="margin-top: 34px;">Mahsulotlar</h2>
    <div class="grid">
        {% for product in products %}
        <div class="card">
            {% if product.image %}
            <img class="product-img" src="/static/uploads/{{ product.image }}">
            {% else %}
            <div class="product-img"></div>
            {% endif %}
            <div class="card-body">
                <h3>{{ product.name }}</h3>
                <p>{{ product.price }} so‘m</p>
                <a class="btn" href="/product/{{ product.id }}">Ko‘rish</a>
            </div>
        </div>
        {% else %}
        <p>Hali mahsulot qo‘shilmagan.</p>
        {% endfor %}
    </div>
</div>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\category.html" -Value @'
{% extends "base.html" %}

{% block content %}
<div class="container" style="padding-top: 28px;">
    <h1>{{ category.name }}</h1>
    <p>{{ category.description or "" }}</p>

    <div class="grid">
        {% for product in products %}
        <div class="card">
            {% if product.image %}
            <img class="product-img" src="/static/uploads/{{ product.image }}">
            {% else %}
            <div class="product-img"></div>
            {% endif %}
            <div class="card-body">
                <h3>{{ product.name }}</h3>
                <p>{{ product.price }} so‘m</p>
                <a class="btn" href="/product/{{ product.id }}">Ko‘rish</a>
            </div>
        </div>
        {% else %}
        <p>Bu kategoriyada mahsulot yo‘q.</p>
        {% endfor %}
    </div>
</div>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\product.html" -Value @'
{% extends "base.html" %}

{% block content %}
<div class="container" style="padding-top: 28px;">
    <div class="card">
        {% if product.image %}
        <img class="product-img" style="height: 360px;" src="/static/uploads/{{ product.image }}">
        {% endif %}
        <div class="card-body">
            <h1>{{ product.name }}</h1>
            <h2>{{ product.price }} so‘m</h2>
            <p>{{ product.description or "" }}</p>

            {% if product.is_orderable %}
            <a class="btn btn-green" href="/order/{{ product.id }}">Buyurtma berish</a>
            {% endif %}

            <a class="btn btn-light" href="/">Orqaga</a>
        </div>
    </div>
</div>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\order.html" -Value @'
{% extends "base.html" %}

{% block content %}
<div class="container" style="padding-top: 28px;">
    <h1>Buyurtma berish</h1>
    <h3>{{ product.name }}</h3>

    <form class="form-box" method="post" action="/order/{{ product.id }}">
        {% for field in fields %}
            <label>{{ field }}</label>

            {% if "Izoh" in field or "Manzil" in field %}
                <textarea name="{{ field }}"></textarea>
            {% else %}
                <input name="{{ field }}" required>
            {% endif %}
        {% endfor %}

        <button class="btn btn-green" type="submit">Buyurtmani yuborish</button>
        <a class="btn btn-light" href="/product/{{ product.id }}">Orqaga</a>
    </form>
</div>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\thanks.html" -Value @'
{% extends "base.html" %}

{% block content %}
<div class="container" style="padding-top: 50px;">
    <div class="form-box">
        <h1>Rahmat!</h1>
        <p>Buyurtmangiz qabul qilindi. Tez orada siz bilan bog‘lanamiz.</p>
        <a class="btn" href="/">Bosh sahifaga qaytish</a>
    </div>
</div>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\admin\base.html" -Value @'
<!DOCTYPE html>
<html lang="uz">
<head>
    <meta charset="UTF-8">
    <title>Admin - KatalogA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="/static/css/style.css" rel="stylesheet">
</head>
<body>
<div class="admin-layout">
    <div class="sidebar">
        <h2>KatalogA</h2>
        <a href="/admin">Dashboard</a>
        <a href="/admin/categories">Kategoriyalar</a>
        <a href="/admin/products">Mahsulotlar</a>
        <a href="/admin/orders">Buyurtmalar</a>
        <a href="/" target="_blank">Saytni ko‘rish</a>
        <a href="/admin/logout">Chiqish</a>
    </div>
    <div class="content">
        {% block content %}{% endblock %}
    </div>
</div>
</body>
</html>
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\admin\login.html" -Value @'
<!DOCTYPE html>
<html lang="uz">
<head>
    <meta charset="UTF-8">
    <title>Admin Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="/static/css/style.css" rel="stylesheet">
</head>
<body>
<div class="container" style="padding-top: 80px; max-width: 430px;">
    <form class="form-box" method="post" action="/admin/login">
        <h1>Admin panel</h1>

        {% if error %}
        <p style="color: red;">{{ error }}</p>
        {% endif %}

        <label>Login</label>
        <input name="username" required>

        <label>Parol</label>
        <input name="password" type="password" required>

        <button class="btn" type="submit">Kirish</button>
    </form>
</div>
</body>
</html>
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\admin\dashboard.html" -Value @'
{% extends "admin/base.html" %}

{% block content %}
<h1>Dashboard</h1>

<div class="stats">
    <div class="stat">
        <p>Kategoriyalar</p>
        <h2>{{ categories_count }}</h2>
    </div>
    <div class="stat">
        <p>Mahsulotlar</p>
        <h2>{{ products_count }}</h2>
    </div>
    <div class="stat">
        <p>Buyurtmalar</p>
        <h2>{{ orders_count }}</h2>
    </div>
</div>

<h2>Oxirgi buyurtmalar</h2>
<table class="table">
    <tr>
        <th>ID</th>
        <th>Mahsulot</th>
        <th>Mijoz</th>
        <th>Telefon</th>
        <th>Status</th>
    </tr>
    {% for order in latest_orders %}
    <tr>
        <td>#{{ order.id }}</td>
        <td>{{ order.product.name if order.product else "-" }}</td>
        <td>{{ order.customer_name or "-" }}</td>
        <td>{{ order.customer_phone or "-" }}</td>
        <td><span class="badge">{{ order.status }}</span></td>
    </tr>
    {% endfor %}
</table>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\admin\categories.html" -Value @'
{% extends "admin/base.html" %}

{% block content %}
<h1>Kategoriyalar</h1>

<form class="form-box" method="post" action="/admin/categories/add">
    <h3>Yangi kategoriya</h3>

    <label>Nomi</label>
    <input name="name" required>

    <label>Tavsif</label>
    <textarea name="description"></textarea>

    <label>Tartib raqami</label>
    <input name="sort_order" type="number" value="0">

    <button class="btn btn-green" type="submit">Qo‘shish</button>
</form>

<table class="table">
    <tr>
        <th>ID</th>
        <th>Nomi</th>
        <th>Tartib</th>
        <th>Status</th>
        <th>Amal</th>
    </tr>
    {% for category in categories %}
    <tr>
        <td>{{ category.id }}</td>
        <td>{{ category.name }}</td>
        <td>{{ category.sort_order }}</td>
        <td>{{ "Aktiv" if category.is_active else "Yashirilgan" }}</td>
        <td>
            <a class="btn btn-light" href="/admin/categories/{{ category.id }}/edit">Tahrirlash</a>
            <form method="post" action="/admin/categories/{{ category.id }}/toggle" style="display:inline;">
                <button class="btn btn-orange" type="submit">
                    {{ "Yashirish" if category.is_active else "Aktiv qilish" }}
                </button>
            </form>
        </td>
    </tr>
    {% endfor %}
</table>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\admin\category_edit.html" -Value @'
{% extends "admin/base.html" %}

{% block content %}
<h1>Kategoriyani tahrirlash</h1>

<form class="form-box" method="post" action="/admin/categories/{{ category.id }}/edit">
    <label>Nomi</label>
    <input name="name" value="{{ category.name }}" required>

    <label>Tavsif</label>
    <textarea name="description">{{ category.description or "" }}</textarea>

    <label>Tartib raqami</label>
    <input name="sort_order" type="number" value="{{ category.sort_order }}">

    <button class="btn btn-green" type="submit">Saqlash</button>
    <a class="btn btn-light" href="/admin/categories">Orqaga</a>
</form>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\admin\products.html" -Value @'
{% extends "admin/base.html" %}

{% block content %}
<h1>Mahsulotlar</h1>

<form class="form-box" method="post" action="/admin/products/add" enctype="multipart/form-data">
    <h3>Yangi mahsulot</h3>

    <label>Kategoriya</label>
    <select name="category_id" required>
        {% for category in categories %}
        <option value="{{ category.id }}">{{ category.name }}</option>
        {% endfor %}
    </select>

    <label>Nomi</label>
    <input name="name" required>

    <label>Tavsif</label>
    <textarea name="description"></textarea>

    <label>Narx</label>
    <input name="price" type="number" value="0">

    <label>Rasm</label>
    <input name="image" type="file" accept="image/*">

    <label>Buyurtma olinadimi?</label>
    <select name="is_orderable">
        <option value="yes">Ha</option>
        <option value="no">Yo‘q</option>
    </select>

    <label>Buyurtma savollari — har biri alohida qatorda</label>
    <textarea name="order_fields">Ism
Telefon
Dona soni
Izoh</textarea>

    <button class="btn btn-green" type="submit">Mahsulot qo‘shish</button>
</form>

<table class="table">
    <tr>
        <th>ID</th>
        <th>Rasm</th>
        <th>Nomi</th>
        <th>Kategoriya</th>
        <th>Narx</th>
        <th>Status</th>
        <th>Amal</th>
    </tr>
    {% for product in products %}
    <tr>
        <td>{{ product.id }}</td>
        <td>
            {% if product.image %}
            <img src="/static/uploads/{{ product.image }}" style="width:70px;height:55px;object-fit:cover;border-radius:8px;">
            {% endif %}
        </td>
        <td>{{ product.name }}</td>
        <td>{{ product.category.name if product.category else "-" }}</td>
        <td>{{ product.price }} so‘m</td>
        <td>{{ "Aktiv" if product.is_active else "Yashirilgan" }}</td>
        <td>
            <a class="btn btn-light" href="/admin/products/{{ product.id }}/edit">Tahrirlash</a>
            <form method="post" action="/admin/products/{{ product.id }}/toggle" style="display:inline;">
                <button class="btn btn-orange" type="submit">
                    {{ "Yashirish" if product.is_active else "Aktiv qilish" }}
                </button>
            </form>
        </td>
    </tr>
    {% endfor %}
</table>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\admin\product_edit.html" -Value @'
{% extends "admin/base.html" %}

{% block content %}
<h1>Mahsulotni tahrirlash</h1>

<form class="form-box" method="post" action="/admin/products/{{ product.id }}/edit" enctype="multipart/form-data">
    <label>Kategoriya</label>
    <select name="category_id" required>
        {% for category in categories %}
        <option value="{{ category.id }}" {% if product.category_id == category.id %}selected{% endif %}>
            {{ category.name }}
        </option>
        {% endfor %}
    </select>

    <label>Nomi</label>
    <input name="name" value="{{ product.name }}" required>

    <label>Tavsif</label>
    <textarea name="description">{{ product.description or "" }}</textarea>

    <label>Narx</label>
    <input name="price" type="number" value="{{ product.price }}">

    {% if product.image %}
    <p>Hozirgi rasm:</p>
    <img src="/static/uploads/{{ product.image }}" style="width:160px;border-radius:12px;">
    {% endif %}

    <label>Yangi rasm</label>
    <input name="image" type="file" accept="image/*">

    <label>Buyurtma olinadimi?</label>
    <select name="is_orderable">
        <option value="yes" {% if product.is_orderable %}selected{% endif %}>Ha</option>
        <option value="no" {% if not product.is_orderable %}selected{% endif %}>Yo‘q</option>
    </select>

    <label>Buyurtma savollari</label>
    <textarea name="order_fields">{{ fields }}</textarea>

    <button class="btn btn-green" type="submit">Saqlash</button>
    <a class="btn btn-light" href="/admin/products">Orqaga</a>
</form>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\templates\admin\orders.html" -Value @'
{% extends "admin/base.html" %}

{% block content %}
<h1>Buyurtmalar</h1>

<table class="table">
    <tr>
        <th>ID</th>
        <th>Mahsulot</th>
        <th>Mijoz</th>
        <th>Telefon</th>
        <th>Soni</th>
        <th>Status</th>
        <th>Amal</th>
    </tr>
    {% for order in orders %}
    <tr>
        <td>#{{ order.id }}</td>
        <td>{{ order.product.name if order.product else "-" }}</td>
        <td>{{ order.customer_name or "-" }}</td>
        <td>{{ order.customer_phone or "-" }}</td>
        <td>{{ order.quantity }}</td>
        <td><span class="badge">{{ order.status }}</span></td>
        <td>
            <form method="post" action="/admin/orders/{{ order.id }}/status">
                <select name="status">
                    <option value="new" {% if order.status == "new" %}selected{% endif %}>Yangi</option>
                    <option value="accepted" {% if order.status == "accepted" %}selected{% endif %}>Qabul qilindi</option>
                    <option value="done" {% if order.status == "done" %}selected{% endif %}>Bajarildi</option>
                    <option value="cancelled" {% if order.status == "cancelled" %}selected{% endif %}>Bekor qilindi</option>
                </select>
                <button class="btn btn-green" type="submit">Saqlash</button>
            </form>
        </td>
    </tr>
    {% endfor %}
</table>
{% endblock %}
'@

Set-Content -Encoding UTF8 -Path "$root\app\bot\main.py" -Value @'
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

from app.config import settings, BASE_DIR
from app.database import SessionLocal
from app.models import Category, Product
from app.schemas import make_order_fields_text

router = Router()


class AddProduct(StatesGroup):
    category = State()
    name = State()
    price = State()
    description = State()
    image = State()
    orderable = State()
    fields = State()


def is_admin(user_id: int):
    return user_id in settings.admin_ids_list


def main_menu():
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="➕ Mahsulot qo‘shish", callback_data="add_product")],
            [InlineKeyboardButton(text="📦 Mahsulotlar soni", callback_data="products_count")]
        ]
    )


@router.message(Command("start"))
async def start(message: Message):
    if not is_admin(message.from_user.id):
        await message.answer("Sizga ruxsat yo‘q.")
        return

    await message.answer("KatalogA admin bot", reply_markup=main_menu())


@router.callback_query(F.data == "products_count")
async def products_count(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo‘q", show_alert=True)
        return

    db = SessionLocal()
    try:
        count = db.query(Product).count()
        await call.message.answer(f"📦 Mahsulotlar soni: {count}")
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data == "add_product")
async def add_product_start(call: CallbackQuery, state: FSMContext):
    if not is_admin(call.from_user.id):
        await call.answer("Ruxsat yo‘q", show_alert=True)
        return

    db = SessionLocal()
    try:
        categories = db.query(Category).filter(Category.is_active == True).order_by(Category.name.asc()).all()

        if not categories:
            await call.message.answer("Avval web admin paneldan kategoriya qo‘shing: /admin/categories")
            await call.answer()
            return

        buttons = []
        for category in categories:
            buttons.append([InlineKeyboardButton(text=category.name, callback_data=f"cat_{category.id}")])

        await call.message.answer(
            "Kategoriya tanlang:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
        await state.set_state(AddProduct.category)
    finally:
        db.close()

    await call.answer()


@router.callback_query(AddProduct.category, F.data.startswith("cat_"))
async def product_category(call: CallbackQuery, state: FSMContext):
    category_id = int(call.data.replace("cat_", ""))
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
    await message.answer("Tavsif yuboring. Agar tavsif kerak bo‘lmasa, - yuboring:")
    await state.set_state(AddProduct.description)


@router.message(AddProduct.description)
async def product_description(message: Message, state: FSMContext):
    description = "" if message.text.strip() == "-" else message.text.strip()
    await state.update_data(description=description)
    await message.answer("Mahsulot rasmini yuboring. Rasm kerak bo‘lmasa, - yuboring:")
    await state.set_state(AddProduct.image)


@router.message(AddProduct.image)
async def product_image(message: Message, state: FSMContext, bot: Bot):
    image_name = None

    if message.photo:
        photo = message.photo[-1]
        image_name = f"tg_{photo.file_unique_id}.jpg"
        upload_dir = BASE_DIR / "app" / "static" / "uploads"
        upload_dir.mkdir(parents=True, exist_ok=True)
        destination = upload_dir / image_name
        await bot.download(photo.file_id, destination=destination)

    await state.update_data(image=image_name)

    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="Ha", callback_data="order_yes")],
            [InlineKeyboardButton(text="Yo‘q", callback_data="order_no")]
        ]
    )

    await message.answer("Bu mahsulotdan buyurtma olinadimi?", reply_markup=keyboard)
    await state.set_state(AddProduct.orderable)


@router.callback_query(AddProduct.orderable, F.data.startswith("order_"))
async def product_orderable(call: CallbackQuery, state: FSMContext):
    is_orderable = call.data == "order_yes"
    await state.update_data(is_orderable=is_orderable)

    await call.message.answer(
        "Buyurtma savollarini yuboring. Har birini yangi qatordan yozing.\n\n"
        "Masalan:\nIsm\nTelefon\nDona soni\nManzil\nIzoh"
    )
    await state.set_state(AddProduct.fields)
    await call.answer()


@router.message(AddProduct.fields)
async def product_fields(message: Message, state: FSMContext):
    data = await state.get_data()

    db = SessionLocal()
    try:
        product = Product(
            category_id=data["category_id"],
            name=data["name"],
            price=data["price"],
            description=data.get("description", ""),
            image=data.get("image"),
            is_active=True,
            is_orderable=data.get("is_orderable", True),
            order_fields=make_order_fields_text(message.text)
        )
        db.add(product)
        db.commit()
        db.refresh(product)

        await message.answer(
            f"✅ Mahsulot qo‘shildi!\n\n"
            f"📦 {product.name}\n"
            f"💰 {product.price} so‘m\n"
            f"🌐 Web sahifada ko‘rinadi."
        )
    finally:
        db.close()

    await state.clear()


async def start_bot():
    if not settings.BOT_TOKEN or settings.BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
        print("BOT_TOKEN .env faylida yozilmagan")
        return

    bot = Bot(token=settings.BOT_TOKEN)
    dp = Dispatcher(storage=MemoryStorage())
    dp.include_router(router)

    print("Telegram bot ishga tushdi")
    await dp.start_polling(bot)
'@

Write-Host ""
Write-Host "✅ Full katalog/admin fayllari yozildi!" -ForegroundColor Green
Write-Host "Endi ishga tushiring:" -ForegroundColor Yellow
Write-Host "cd `"D:\My Project\KatalogA`""
Write-Host ".\.venv\Scripts\activate"
Write-Host "python run_web.py"