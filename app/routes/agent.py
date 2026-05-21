
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
        "currency": "СЃРѕРјРѕРЅУЈ",

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
        "currency": "\u0441\u043e\u043c\u043e\u043d\u04e3",

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
