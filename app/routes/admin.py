
import shutil
from pathlib import Path
from fastapi import APIRouter, Request, Depends, Form, UploadFile, File
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from app.database import get_db
from app.config import BASE_DIR, settings
from app.models import Category, Product, Order

router = APIRouter(prefix="/admin")
templates = Jinja2Templates(directory=str(BASE_DIR / "app" / "templates"))


TEXTS = {
    "uz": {
        "admin_panel": "Admin panel",
        "dashboard": "Dashboard",
        "categories": "Kategoriyalar",
        "products": "Mahsulotlar",
        "agent_panel": "Agent panel",
        "view_site": "Saytni ko'rish",
        "logout": "Chiqish",
        "login": "Login",
        "password": "Parol",
        "enter": "Kirish",
        "wrong": "Login yoki parol noto'g'ri",

        "total_categories": "Kategoriyalar",
        "total_products": "Jami mahsulotlar",
        "active_products": "Aktiv mahsulotlar",
        "panel_status": "Panel holati",
        "panel_text_1": "Admin panelda mahsulot va kategoriyalar boshqariladi.",
        "panel_text_2": "Agent panelda faqat katalog ko'rinadi: mahsulot rasmi, nomi va narxi.",
        "add_product": "Mahsulot qo'shish",
        "view_agent_catalog": "Agent katalogni ko'rish",

        "new_category": "Yangi kategoriya",
        "name": "Nomi",
        "description": "Tavsif",
        "sort_order": "Tartib raqami",
        "add": "Qo'shish",
        "id": "ID",
        "status": "Status",
        "action": "Amal",
        "active": "Aktiv",
        "hidden": "Yashirilgan",
        "edit": "Tahrirlash",
        "hide": "Yashirish",
        "activate": "Aktiv qilish",
        "edit_category": "Kategoriyani tahrirlash",
        "save": "Saqlash",
        "back": "Orqaga",

        "new_product": "Yangi mahsulot",
        "category": "Kategoriya",
        "product_name": "Mahsulot nomi",
        "price": "Narx",
        "image": "Rasm",
        "current_image": "Hozirgi rasm:",
        "new_image": "Yangi rasm",
        "edit_product": "Mahsulotni tahrirlash",
        "first_add_category": "Avval kategoriya qo'shing.",
        "currency": "so'm",
        "no_image": "Rasm yo'q",
        "admin_login_subtitle": "Tizimga kirish uchun login va parolni kiriting."
    },
    "ru": {
        "admin_panel": "\u0410\u0434\u043c\u0438\u043d-\u043f\u0430\u043d\u0435\u043b\u044c",
        "dashboard": "\u0414\u0430\u0448\u0431\u043e\u0440\u0434",
        "categories": "\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438",
        "products": "\u0422\u043e\u0432\u0430\u0440\u044b",
        "agent_panel": "\u041f\u0430\u043d\u0435\u043b\u044c \u0430\u0433\u0435\u043d\u0442\u0430",
        "view_site": "\u041e\u0442\u043a\u0440\u044b\u0442\u044c \u0441\u0430\u0439\u0442",
        "logout": "\u0412\u044b\u0445\u043e\u0434",
        "login": "\u041b\u043e\u0433\u0438\u043d",
        "password": "\u041f\u0430\u0440\u043e\u043b\u044c",
        "enter": "\u0412\u043e\u0439\u0442\u0438",
        "wrong": "\u041d\u0435\u0432\u0435\u0440\u043d\u044b\u0439 \u043b\u043e\u0433\u0438\u043d \u0438\u043b\u0438 \u043f\u0430\u0440\u043e\u043b\u044c",

        "total_categories": "\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438",
        "total_products": "\u0412\u0441\u0435\u0433\u043e \u0442\u043e\u0432\u0430\u0440\u043e\u0432",
        "active_products": "\u0410\u043a\u0442\u0438\u0432\u043d\u044b\u0435 \u0442\u043e\u0432\u0430\u0440\u044b",
        "panel_status": "\u0421\u0442\u0430\u0442\u0443\u0441 \u043f\u0430\u043d\u0435\u043b\u0438",
        "panel_text_1": "\u0412 \u0430\u0434\u043c\u0438\u043d-\u043f\u0430\u043d\u0435\u043b\u0438 \u043c\u043e\u0436\u043d\u043e \u0443\u043f\u0440\u0430\u0432\u043b\u044f\u0442\u044c \u0442\u043e\u0432\u0430\u0440\u0430\u043c\u0438 \u0438 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f\u043c\u0438.",
        "panel_text_2": "\u0412 \u043f\u0430\u043d\u0435\u043b\u0438 \u0430\u0433\u0435\u043d\u0442\u0430 \u0432\u0438\u0434\u0435\u043d \u0442\u043e\u043b\u044c\u043a\u043e \u043a\u0430\u0442\u0430\u043b\u043e\u0433: \u0444\u043e\u0442\u043e, \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u0438 \u0446\u0435\u043d\u0430.",
        "add_product": "\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u0442\u043e\u0432\u0430\u0440",
        "view_agent_catalog": "\u041e\u0442\u043a\u0440\u044b\u0442\u044c \u043a\u0430\u0442\u0430\u043b\u043e\u0433 \u0430\u0433\u0435\u043d\u0442\u0430",

        "new_category": "\u041d\u043e\u0432\u0430\u044f \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f",
        "name": "\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435",
        "description": "\u041e\u043f\u0438\u0441\u0430\u043d\u0438\u0435",
        "sort_order": "\u041f\u043e\u0440\u044f\u0434\u043e\u043a",
        "add": "\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c",
        "id": "ID",
        "status": "\u0421\u0442\u0430\u0442\u0443\u0441",
        "action": "\u0414\u0435\u0439\u0441\u0442\u0432\u0438\u0435",
        "active": "\u0410\u043a\u0442\u0438\u0432\u043d\u044b\u0439",
        "hidden": "\u0421\u043a\u0440\u044b\u0442",
        "edit": "\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c",
        "hide": "\u0421\u043a\u0440\u044b\u0442\u044c",
        "activate": "\u0410\u043a\u0442\u0438\u0432\u0438\u0440\u043e\u0432\u0430\u0442\u044c",
        "edit_category": "\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044e",
        "save": "\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c",
        "back": "\u041d\u0430\u0437\u0430\u0434",

        "new_product": "\u041d\u043e\u0432\u044b\u0439 \u0442\u043e\u0432\u0430\u0440",
        "category": "\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f",
        "product_name": "\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u0442\u043e\u0432\u0430\u0440\u0430",
        "price": "\u0426\u0435\u043d\u0430",
        "image": "\u0424\u043e\u0442\u043e",
        "current_image": "\u0422\u0435\u043a\u0443\u0449\u0435\u0435 \u0444\u043e\u0442\u043e:",
        "new_image": "\u041d\u043e\u0432\u043e\u0435 \u0444\u043e\u0442\u043e",
        "edit_product": "\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u0442\u043e\u0432\u0430\u0440",
        "first_add_category": "\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0434\u043e\u0431\u0430\u0432\u044c\u0442\u0435 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044e.",
        "currency": "\u0441\u0443\u043c",
        "no_image": "\u041d\u0435\u0442 \u0444\u043e\u0442\u043e",
        "admin_login_subtitle": "\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u043b\u043e\u0433\u0438\u043d \u0438 \u043f\u0430\u0440\u043e\u043b\u044c \u0434\u043b\u044f \u0432\u0445\u043e\u0434\u0430."
    }
}


def get_lang(request: Request):
    lang = request.query_params.get("lang") or request.cookies.get("admin_lang") or "uz"
    if lang not in TEXTS:
        lang = "uz"
    return lang


def admin_ok(request: Request):
    return request.cookies.get("admin_auth") == "yes"


def save_upload(file):
    if not file or not file.filename:
        return None

    upload_dir = Path(settings.UPLOAD_DIR)
    upload_dir.mkdir(parents=True, exist_ok=True)

    clean_name = file.filename.replace(" ", "_")
    path = upload_dir / clean_name

    with path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return clean_name


def render(request, template_name, context=None):
    lang = get_lang(request)
    data = {
        "request": request,
        "lang": lang,
        "t": TEXTS[lang]
    }
    if context:
        data.update(context)

    response = templates.TemplateResponse(template_name, data)
    response.set_cookie("admin_lang", lang, httponly=False)
    return response


@router.get("/login")
def login_page(request: Request):
    return render(request, "admin/login.html", {"error": None})


@router.post("/login")
def login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    lang: str = Form("uz")
):
    if lang not in TEXTS:
        lang = "uz"

    if username == settings.ADMIN_USERNAME and password == settings.ADMIN_PASSWORD:
        response = RedirectResponse(f"/admin?lang={lang}", status_code=302)
        response.set_cookie("admin_auth", "yes", httponly=True)
        response.set_cookie("admin_lang", lang, httponly=False)
        return response

    response = templates.TemplateResponse(
        "admin/login.html",
        {
            "request": request,
            "error": TEXTS[lang]["wrong"],
            "lang": lang,
            "t": TEXTS[lang]
        }
    )
    response.set_cookie("admin_lang", lang, httponly=False)
    return response


@router.get("/logout")
def logout(request: Request):
    lang = get_lang(request)
    response = RedirectResponse(f"/admin/login?lang={lang}", status_code=302)
    response.delete_cookie("admin_auth")
    response.set_cookie("admin_lang", lang, httponly=False)
    return response


@router.get("")
def dashboard(request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        lang = get_lang(request)
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    return render(
        request,
        "admin/dashboard.html",
        {
            "categories_count": db.query(Category).count(),
            "products_count": db.query(Product).count(),
            "active_products_count": db.query(Product).filter(Product.is_active == True).count(),
            "orders_count": db.query(Order).count()
        }
    )


@router.get("/categories")
def categories_page(request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        lang = get_lang(request)
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    categories = db.query(Category).order_by(Category.sort_order.asc(), Category.id.desc()).all()
    return render(request, "admin/categories.html", {"categories": categories})


@router.post("/categories/add")
def add_category(
    request: Request,
    name: str = Form(...),
    description: str = Form(""),
    sort_order: int = Form(0),
    db: Session = Depends(get_db)
):
    lang = get_lang(request)

    if not admin_ok(request):
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    category = Category(
        name=name,
        description=description,
        sort_order=sort_order,
        is_active=True
    )
    db.add(category)
    db.commit()

    return RedirectResponse(f"/admin/categories?lang={lang}", status_code=302)


@router.get("/categories/{category_id}/edit")
def edit_category_page(category_id: int, request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        lang = get_lang(request)
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    category = db.query(Category).filter(Category.id == category_id).first()
    return render(request, "admin/category_edit.html", {"category": category})


@router.post("/categories/{category_id}/edit")
def edit_category(
    category_id: int,
    request: Request,
    name: str = Form(...),
    description: str = Form(""),
    sort_order: int = Form(0),
    db: Session = Depends(get_db)
):
    lang = get_lang(request)

    if not admin_ok(request):
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    category = db.query(Category).filter(Category.id == category_id).first()

    if category:
        category.name = name
        category.description = description
        category.sort_order = sort_order
        db.commit()

    return RedirectResponse(f"/admin/categories?lang={lang}", status_code=302)


@router.post("/categories/{category_id}/toggle")
def toggle_category(category_id: int, request: Request, db: Session = Depends(get_db)):
    lang = get_lang(request)

    if not admin_ok(request):
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    category = db.query(Category).filter(Category.id == category_id).first()

    if category:
        category.is_active = not category.is_active
        db.commit()

    return RedirectResponse(f"/admin/categories?lang={lang}", status_code=302)


@router.get("/products")
def products_page(request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        lang = get_lang(request)
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    categories = db.query(Category).order_by(Category.name.asc()).all()
    products = db.query(Product).order_by(Product.id.desc()).all()

    return render(
        request,
        "admin/products.html",
        {
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
    image: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    lang = get_lang(request)

    if not admin_ok(request):
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    image_name = save_upload(image)

    product = Product(
        category_id=category_id,
        name=name,
        description=description,
        price=price,
        image=image_name,
        is_active=True,
        is_orderable=False,
        order_fields=""
    )

    db.add(product)
    db.commit()

    return RedirectResponse(f"/admin/products?lang={lang}", status_code=302)


@router.get("/products/{product_id}/edit")
def edit_product_page(product_id: int, request: Request, db: Session = Depends(get_db)):
    if not admin_ok(request):
        lang = get_lang(request)
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    product = db.query(Product).filter(Product.id == product_id).first()
    categories = db.query(Category).order_by(Category.name.asc()).all()

    return render(
        request,
        "admin/product_edit.html",
        {
            "product": product,
            "categories": categories
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
    image: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    lang = get_lang(request)

    if not admin_ok(request):
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    product = db.query(Product).filter(Product.id == product_id).first()

    if product:
        product.category_id = category_id
        product.name = name
        product.description = description
        product.price = price
        product.is_orderable = False
        product.order_fields = ""

        image_name = save_upload(image)
        if image_name:
            product.image = image_name

        db.commit()

    return RedirectResponse(f"/admin/products?lang={lang}", status_code=302)


@router.post("/products/{product_id}/toggle")
def toggle_product(product_id: int, request: Request, db: Session = Depends(get_db)):
    lang = get_lang(request)

    if not admin_ok(request):
        return RedirectResponse(f"/admin/login?lang={lang}", status_code=302)

    product = db.query(Product).filter(Product.id == product_id).first()

    if product:
        product.is_active = not product.is_active
        db.commit()

    return RedirectResponse(f"/admin/products?lang={lang}", status_code=302)
