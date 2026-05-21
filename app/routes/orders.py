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
