
import json
from pathlib import Path
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
        "рџ†• Yangi buyurtma",
        "",
        f"рџ“¦ Mahsulot: {product.name}",
        f"рџ—‚ Kategoriya: {category.name if category else '-'}",
        f"рџ’° Narx: {product.price} so'm",
        f"рџ”ў Soni: {order.quantity}",
        "",
        f"рџ‘¤ Mijoz: {order.customer_name or '-'}",
        f"рџ“ћ Telefon: {order.customer_phone or '-'}",
        "",
        "рџ“‹ So'rovnoma:"
    ]

    for key, value in answers.items():
        lines.append(f"вЂў {key}: {value}")

    lines.extend([
        "",
        f"рџ§ѕ Buyurtma ID: #{order.id}",
        f"рџ“Њ Status: {order.status}"
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
        image_path = Path(settings.UPLOAD_DIR) / product.image if product.image else None

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
        "рџ†• Yangi zakaz",
        "",
        f"рџЏЄ Magazin: {order.store_name}",
        f"рџ§ѕ Zakaz ID: #{order.id}",
        "",
        "рџ“¦ Mahsulotlar:"
    ]

    total = 0

    for index, item in enumerate(order.items, start=1):
        total += item.line_total
        lines.append(
            f"{index}) {item.product_name}\n"
            f"   {item.quantity} dona Г— {item.price} so'm = {item.line_total} so'm"
        )

    lines.extend([
        "",
        f"рџ’° Jami: {total} so'm",
        f"рџ“Њ Status: {order.status}"
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
