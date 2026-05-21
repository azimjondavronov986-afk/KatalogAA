# -*- coding: utf-8 -*-
import asyncio
from typing import Any, Optional

from aiogram import Bot

from app.config import settings


def _get(obj: Any, names, default=None):
    for name in names:
        if obj is None:
            continue
        if isinstance(obj, dict) and name in obj:
            return obj.get(name)
        if hasattr(obj, name):
            value = getattr(obj, name)
            if value is not None:
                return value
    return default


def _money(value) -> str:
    try:
        n = int(float(value or 0))
    except Exception:
        n = 0

    return f"{n:,}".replace(",", " ") + " \u0441\u043e\u043c\u043e\u043d"


def _load_order(order_or_id=None, db=None):
    if db is not None and isinstance(order_or_id, int):
        try:
            from app.models import Order
            return db.query(Order).filter(Order.id == order_or_id).first()
        except Exception:
            return order_or_id

    return order_or_id


def _load_items(order, db=None):
    items = _get(order, ["items", "order_items", "details", "products"], None)

    if items:
        return list(items)

    order_id = _get(order, ["id", "order_id"], None)

    if db is not None and order_id is not None:
        try:
            from app.models import OrderItem
            return db.query(OrderItem).filter(OrderItem.order_id == order_id).all()
        except Exception:
            return []

    return []


def _product_name(item) -> str:
    product = _get(item, ["product"], None)

    name = _get(item, ["product_name", "name", "title"], None)
    if name:
        return str(name)

    name = _get(product, ["name", "title"], None)
    if name:
        return str(name)

    return "\u0422\u043e\u0432\u0430\u0440"


def _quantity(item) -> int:
    value = _get(item, ["quantity", "qty", "count", "amount"], 0)
    try:
        return int(float(value or 0))
    except Exception:
        return 0


def _price(item) -> int:
    product = _get(item, ["product"], None)

    value = _get(item, ["price", "unit_price", "product_price"], None)
    if value is None:
        value = _get(product, ["price"], 0)

    try:
        return int(float(value or 0))
    except Exception:
        return 0


def build_order_text(order_or_id=None, db=None, **kwargs) -> str:
    order = kwargs.get("order") or kwargs.get("order_id") or order_or_id
    db = kwargs.get("db") or db

    order = _load_order(order, db)

    order_id = _get(order, ["id", "order_id"], "-")
    store_name = _get(
        order,
        ["store_name", "shop_name", "market_name", "magazine_name", "magazin", "client_name"],
        "-"
    )
    status = _get(order, ["status"], "new")

    items = _load_items(order, db)

    lines = []
    lines.append("\u041d\u043e\u0432\u044b\u0439 \u0437\u0430\u043a\u0430\u0437")
    lines.append("")
    lines.append(f"\u041c\u0430\u0433\u0430\u0437\u0438\u043d: {store_name}")
    lines.append(f"\u0417\u0430\u043a\u0430\u0437 ID: #{order_id}")
    lines.append("")
    lines.append("\u0422\u043e\u0432\u0430\u0440\u044b:")

    total = 0

    for idx, item in enumerate(items, 1):
        name = _product_name(item)
        qty = _quantity(item)
        price = _price(item)
        line_total = qty * price
        total += line_total

        lines.append(f"{idx}) {name}")
        lines.append(f"   {qty} \u0448\u0442 \u2014 {_money(price)} = {_money(line_total)}")

    if not items:
        lines.append("-")

    db_total = _get(order, ["total", "total_sum", "amount", "sum"], None)
    if db_total is not None:
        try:
            total = int(float(db_total or 0))
        except Exception:
            pass

    lines.append("")
    lines.append(f"\u0418\u0442\u043e\u0433\u043e: {_money(total)}")
    lines.append(f"\u0421\u0442\u0430\u0442\u0443\u0441: {status}")

    return "\n".join(lines)


async def send_order_to_group(order_or_id=None, db=None, **kwargs):
    if not settings.BOT_TOKEN:
        return False

    chat_id = getattr(settings, "ORDER_GROUP_ID", "") or getattr(settings, "GROUP_CHAT_ID", "")
    if not chat_id:
        return False

    text = build_order_text(order_or_id=order_or_id, db=db, **kwargs)

    bot = Bot(token=settings.BOT_TOKEN)
    try:
        await bot.send_message(chat_id=chat_id, text=text)
        return True
    finally:
        await bot.session.close()


def send_order_to_group_sync(order_or_id=None, db=None, **kwargs):
    return asyncio.run(send_order_to_group(order_or_id=order_or_id, db=db, **kwargs))



async def notify_new_order(*args, **kwargs):
    return await send_order_to_group(*args, **kwargs)

async def notify_order(*args, **kwargs):
    return await send_order_to_group(*args, **kwargs)

async def send_catalog_order_to_group(*args, **kwargs):
    return await send_order_to_group(*args, **kwargs)

async def send_new_order(*args, **kwargs):
    return await send_order_to_group(*args, **kwargs)

async def send_order_message(*args, **kwargs):
    return await send_order_to_group(*args, **kwargs)

async def send_order_notification(*args, **kwargs):
    return await send_order_to_group(*args, **kwargs)

async def send_order_to_telegram(*args, **kwargs):
    return await send_order_to_group(*args, **kwargs)
