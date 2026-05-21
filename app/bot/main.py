# -*- coding: utf-8 -*-
import re

from aiogram import Bot, Dispatcher, Router, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.types import (
    Message,
    CallbackQuery,
    InlineKeyboardMarkup,
    InlineKeyboardButton,
    FSInputFile,
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
            [InlineKeyboardButton(text="Р”РѕР±Р°РІРёС‚СЊ С‚РѕРІР°СЂ", callback_data="add_product")],
            [InlineKeyboardButton(text="РўРѕРІР°СЂС‹", callback_data="products_list")],
            [InlineKeyboardButton(text="Р”РѕР±Р°РІРёС‚СЊ РєР°С‚РµРіРѕСЂРёСЋ", callback_data="add_category")],
            [InlineKeyboardButton(text="РљР°С‚РµРіРѕСЂРёРё", callback_data="categories_list")],
        ]
    )


def back_menu():
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="РќР°Р·Р°Рґ РІ РјРµРЅСЋ", callback_data="main_menu")]
        ]
    )


@router.message(Command("start"))
async def start(message: Message):
    if not is_admin(message.from_user.id):
        await message.answer("РЈ РІР°СЃ РЅРµС‚ РґРѕСЃС‚СѓРїР°.")
        return

    await message.answer("РџР°РЅРµР»СЊ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР° РєР°С‚Р°Р»РѕРіР°", reply_markup=menu())


@router.callback_query(F.data == "main_menu")
async def main_menu(call: CallbackQuery, state: FSMContext):
    await state.clear()

    if not is_admin(call.from_user.id):
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    await call.message.answer("Р“Р»Р°РІРЅРѕРµ РјРµРЅСЋ", reply_markup=menu())
    await call.answer()


@router.callback_query(F.data == "add_category")
async def add_category_start(call: CallbackQuery, state: FSMContext):
    if not is_admin(call.from_user.id):
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    await call.message.answer("РћС‚РїСЂР°РІСЊС‚Рµ РЅР°Р·РІР°РЅРёРµ РєР°С‚РµРіРѕСЂРёРё:")
    await state.set_state(AddCategory.name)
    await call.answer()


@router.message(AddCategory.name)
async def add_category_name(message: Message, state: FSMContext):
    await state.update_data(name=message.text.strip())
    await message.answer("РћС‚РїСЂР°РІСЊС‚Рµ РѕРїРёСЃР°РЅРёРµ РєР°С‚РµРіРѕСЂРёРё. Р•СЃР»Рё РѕРїРёСЃР°РЅРёРµ РЅРµ РЅСѓР¶РЅРѕ, РѕС‚РїСЂР°РІСЊС‚Рµ -")
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
            sort_order=0,
        )
        db.add(category)
        db.commit()

        await message.answer(
            f"РљР°С‚РµРіРѕСЂРёСЏ РґРѕР±Р°РІР»РµРЅР°: {category.name}",
            reply_markup=menu()
        )
    finally:
        db.close()

    await state.clear()


@router.callback_query(F.data == "categories_list")
async def categories_list(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    db = SessionLocal()
    try:
        categories = db.query(Category).order_by(Category.id.desc()).limit(30).all()

        if not categories:
            await call.message.answer("РљР°С‚РµРіРѕСЂРёР№ РїРѕРєР° РЅРµС‚.", reply_markup=back_menu())
            await call.answer()
            return

        buttons = []
        for c in categories:
            status = "РђРєС‚РёРІРЅР°СЏ" if c.is_active else "РЎРєСЂС‹С‚Р°СЏ"
            buttons.append([
                InlineKeyboardButton(
                    text=f"{c.name} вЂ” {status}",
                    callback_data=f"cat_menu_{c.id}"
                )
            ])

        buttons.append([InlineKeyboardButton(text="РќР°Р·Р°Рґ РІ РјРµРЅСЋ", callback_data="main_menu")])

        await call.message.answer(
            "РЎРїРёСЃРѕРє РєР°С‚РµРіРѕСЂРёР№:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("cat_menu_"))
async def category_menu(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    category_id = int(call.data.replace("cat_menu_", ""))

    db = SessionLocal()
    try:
        c = db.query(Category).filter(Category.id == category_id).first()
        if not c:
            await call.message.answer("РљР°С‚РµРіРѕСЂРёСЏ РЅРµ РЅР°Р№РґРµРЅР°.")
            await call.answer()
            return

        status_text = "РђРєС‚РёРІРЅР°СЏ" if c.is_active else "РЎРєСЂС‹С‚Р°СЏ"

        buttons = [
            [
                InlineKeyboardButton(
                    text="РЎРєСЂС‹С‚СЊ" if c.is_active else "РђРєС‚РёРІРёСЂРѕРІР°С‚СЊ",
                    callback_data=f"cat_toggle_{c.id}"
                )
            ],
            [InlineKeyboardButton(text="РќР°Р·Р°Рґ Рє РєР°С‚РµРіРѕСЂРёСЏРј", callback_data="categories_list")],
        ]

        await call.message.answer(
            f"РљР°С‚РµРіРѕСЂРёСЏ: {c.name}\nРЎС‚Р°С‚СѓСЃ: {status_text}",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("cat_toggle_"))
async def category_toggle(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    category_id = int(call.data.replace("cat_toggle_", ""))

    db = SessionLocal()
    try:
        c = db.query(Category).filter(Category.id == category_id).first()
        if c:
            c.is_active = not c.is_active
            db.commit()
            await call.message.answer("РЎС‚Р°С‚СѓСЃ РєР°С‚РµРіРѕСЂРёРё РёР·РјРµРЅС‘РЅ.")
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data == "add_product")
async def add_product_start(call: CallbackQuery, state: FSMContext):
    if not is_admin(call.from_user.id):
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    db = SessionLocal()
    try:
        categories = (
            db.query(Category)
            .filter(Category.is_active == True)
            .order_by(Category.name.asc())
            .all()
        )

        if not categories:
            await call.message.answer("РЎРЅР°С‡Р°Р»Р° РґРѕР±Р°РІСЊС‚Рµ РєР°С‚РµРіРѕСЂРёСЋ.", reply_markup=menu())
            await call.answer()
            return

        buttons = []
        for c in categories:
            buttons.append([
                InlineKeyboardButton(text=c.name, callback_data=f"ap_cat_{c.id}")
            ])

        await call.message.answer(
            "Р’С‹Р±РµСЂРёС‚Рµ РєР°С‚РµРіРѕСЂРёСЋ С‚РѕРІР°СЂР°:",
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
    await call.message.answer("РћС‚РїСЂР°РІСЊС‚Рµ РЅР°Р·РІР°РЅРёРµ С‚РѕРІР°СЂР°:")
    await state.set_state(AddProduct.name)
    await call.answer()


@router.message(AddProduct.name)
async def product_name(message: Message, state: FSMContext):
    await state.update_data(name=message.text.strip())
    await message.answer("РћС‚РїСЂР°РІСЊС‚Рµ С†РµРЅСѓ. РќР°РїСЂРёРјРµСЂ: 25000")
    await state.set_state(AddProduct.price)


@router.message(AddProduct.price)
async def product_price(message: Message, state: FSMContext):
    digits = re.sub(r"\D", "", message.text or "")
    price = int(digits) if digits else 0
    await state.update_data(price=price)
    await message.answer("РћС‚РїСЂР°РІСЊС‚Рµ РѕРїРёСЃР°РЅРёРµ С‚РѕРІР°СЂР°. Р•СЃР»Рё РѕРїРёСЃР°РЅРёРµ РЅРµ РЅСѓР¶РЅРѕ, РѕС‚РїСЂР°РІСЊС‚Рµ -")
    await state.set_state(AddProduct.description)


@router.message(AddProduct.description)
async def product_description(message: Message, state: FSMContext):
    description = "" if message.text.strip() == "-" else message.text.strip()
    await state.update_data(description=description)
    await message.answer("РћС‚РїСЂР°РІСЊС‚Рµ С„РѕС‚Рѕ С‚РѕРІР°СЂР°. Р•СЃР»Рё С„РѕС‚Рѕ РЅРµ РЅСѓР¶РЅРѕ, РѕС‚РїСЂР°РІСЊС‚Рµ -")
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
            order_fields="",
        )
        db.add(product)
        db.commit()

        await message.answer(
            f"РўРѕРІР°СЂ РґРѕР±Р°РІР»РµРЅ!\n\n"
            f"РќР°Р·РІР°РЅРёРµ: {product.name}\n"
            f"Р¦РµРЅР°: {product.price} СЃСѓРј",
            reply_markup=menu()
        )
    finally:
        db.close()

    await state.clear()


@router.callback_query(F.data == "products_list")
async def products_list(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    db = SessionLocal()
    try:
        products = db.query(Product).order_by(Product.id.desc()).limit(30).all()

        if not products:
            await call.message.answer("РўРѕРІР°СЂРѕРІ РїРѕРєР° РЅРµС‚.", reply_markup=back_menu())
            await call.answer()
            return

        buttons = []
        for p in products:
            status = "РђРєС‚РёРІРЅС‹Р№" if p.is_active else "РЎРєСЂС‹С‚С‹Р№"
            buttons.append([
                InlineKeyboardButton(
                    text=f"{p.name} вЂ” {status}",
                    callback_data=f"prod_menu_{p.id}"
                )
            ])

        buttons.append([InlineKeyboardButton(text="РќР°Р·Р°Рґ РІ РјРµРЅСЋ", callback_data="main_menu")])

        await call.message.answer(
            "РЎРїРёСЃРѕРє С‚РѕРІР°СЂРѕРІ:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("prod_menu_"))
async def product_menu(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    product_id = int(call.data.replace("prod_menu_", ""))

    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if not p:
            await call.message.answer("РўРѕРІР°СЂ РЅРµ РЅР°Р№РґРµРЅ.")
            await call.answer()
            return

        status_text = "РђРєС‚РёРІРЅС‹Р№" if p.is_active else "РЎРєСЂС‹С‚С‹Р№"
        category_name = p.category.name if p.category else "-"

        buttons = [
            [
                InlineKeyboardButton(
                    text="РЎРєСЂС‹С‚СЊ" if p.is_active else "РђРєС‚РёРІРёСЂРѕРІР°С‚СЊ",
                    callback_data=f"prod_toggle_{p.id}"
                )
            ],
            [InlineKeyboardButton(text="РќР°Р·Р°Рґ Рє С‚РѕРІР°СЂР°Рј", callback_data="products_list")],
        ]

        text = (
            f"РўРѕРІР°СЂ: {p.name}\n"
            f"РљР°С‚РµРіРѕСЂРёСЏ: {category_name}\n"
            f"Р¦РµРЅР°: {p.price} СЃСѓРј\n"
            f"РЎС‚Р°С‚СѓСЃ: {status_text}"
        )

        image_path = settings.UPLOAD_DIR / p.image if p.image else None

        if image_path and image_path.exists():
            await call.message.answer_photo(
                photo=FSInputFile(str(image_path)),
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
        await call.answer("РќРµС‚ РґРѕСЃС‚СѓРїР°", show_alert=True)
        return

    product_id = int(call.data.replace("prod_toggle_", ""))

    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if p:
            p.is_active = not p.is_active
            db.commit()
            await call.message.answer("РЎС‚Р°С‚СѓСЃ С‚РѕРІР°СЂР° РёР·РјРµРЅС‘РЅ.")
    finally:
        db.close()

    await call.answer()


async def start_bot():
    if not settings.BOT_TOKEN or settings.BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
        print("BOT_TOKEN РЅРµ СѓРєР°Р·Р°РЅ. Р‘РѕС‚ РЅРµ Р·Р°РїСѓС‰РµРЅ.")
        return

    bot = Bot(token=settings.BOT_TOKEN)
    dp = Dispatcher(storage=MemoryStorage())
    dp.include_router(router)

    print("Telegram Р±РѕС‚ Р·Р°РїСѓС‰РµРЅ")
    await dp.start_polling(bot)
