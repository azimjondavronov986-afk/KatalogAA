from fastapi import APIRouter, Request, Depends, HTTPException
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from app.database import get_db
from app.config import BASE_DIR
from app.models import Category, Product

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
        .limit(30)
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
    product = db.query(Product).filter(Product.id == product_id, Product.is_active == True).first()
    if not product:
        raise HTTPException(status_code=404, detail="Mahsulot topilmadi")

    return templates.TemplateResponse(
        "product.html",
        {
            "request": request,
            "product": product
        }
    )
