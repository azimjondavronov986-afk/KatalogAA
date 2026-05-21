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
            [InlineKeyboardButton(text="\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u0442\u043e\u0432\u0430\u0440", callback_data="add_product")],
            [InlineKeyboardButton(text="\u0422\u043e\u0432\u0430\u0440\u044b", callback_data="products_list")],
            [InlineKeyboardButton(text="\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044e", callback_data="add_category")],
            [InlineKeyboardButton(text="\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438", callback_data="categories_list")],
        ]
    )


def back_menu():
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="\u041d\u0430\u0437\u0430\u0434 \u0432 \u043c\u0435\u043d\u044e", callback_data="main_menu")]
        ]
    )


@router.message(Command("start"))
async def start(message: Message):
    if not is_admin(message.from_user.id):
        await message.answer("\u0423 \u0432\u0430\u0441 \u043d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430.")
        return

    await message.answer("\u041f\u0430\u043d\u0435\u043b\u044c \u0430\u0434\u043c\u0438\u043d\u0438\u0441\u0442\u0440\u0430\u0442\u043e\u0440\u0430 \u043a\u0430\u0442\u0430\u043b\u043e\u0433\u0430", reply_markup=menu())


@router.callback_query(F.data == "main_menu")
async def main_menu(call: CallbackQuery, state: FSMContext):
    await state.clear()

    if not is_admin(call.from_user.id):
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
        return

    await call.message.answer("\u0413\u043b\u0430\u0432\u043d\u043e\u0435 \u043c\u0435\u043d\u044e", reply_markup=menu())
    await call.answer()


@router.callback_query(F.data == "add_category")
async def add_category_start(call: CallbackQuery, state: FSMContext):
    if not is_admin(call.from_user.id):
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
        return

    await call.message.answer("\u041e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438:")
    await state.set_state(AddCategory.name)
    await call.answer()


@router.message(AddCategory.name)
async def add_category_name(message: Message, state: FSMContext):
    await state.update_data(name=message.text.strip())
    await message.answer("\u041e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 \u043e\u043f\u0438\u0441\u0430\u043d\u0438\u0435 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438. \u0415\u0441\u043b\u0438 \u043e\u043f\u0438\u0441\u0430\u043d\u0438\u0435 \u043d\u0435 \u043d\u0443\u0436\u043d\u043e, \u043e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 -")
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
            f"\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f \u0434\u043e\u0431\u0430\u0432\u043b\u0435\u043d\u0430: {category.name}",
            reply_markup=menu()
        )
    finally:
        db.close()

    await state.clear()


@router.callback_query(F.data == "categories_list")
async def categories_list(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
        return

    db = SessionLocal()
    try:
        categories = db.query(Category).order_by(Category.id.desc()).limit(30).all()

        if not categories:
            await call.message.answer("\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0439 \u043f\u043e\u043a\u0430 \u043d\u0435\u0442.", reply_markup=back_menu())
            await call.answer()
            return

        buttons = []
        for c in categories:
            status = "\u0410\u043a\u0442\u0438\u0432\u043d\u0430\u044f" if c.is_active else "\u0421\u043a\u0440\u044b\u0442\u0430\u044f"
            buttons.append([
                InlineKeyboardButton(
                    text=f"{c.name} - {status}",
                    callback_data=f"cat_menu_{c.id}"
                )
            ])

        buttons.append([InlineKeyboardButton(text="\u041d\u0430\u0437\u0430\u0434 \u0432 \u043c\u0435\u043d\u044e", callback_data="main_menu")])

        await call.message.answer(
            "\u0421\u043f\u0438\u0441\u043e\u043a \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0439:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("cat_menu_"))
async def category_menu(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
        return

    category_id = int(call.data.replace("cat_menu_", ""))

    db = SessionLocal()
    try:
        c = db.query(Category).filter(Category.id == category_id).first()
        if not c:
            await call.message.answer("\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u0430.")
            await call.answer()
            return

        status_text = "\u0410\u043a\u0442\u0438\u0432\u043d\u0430\u044f" if c.is_active else "\u0421\u043a\u0440\u044b\u0442\u0430\u044f"

        buttons = [
            [
                InlineKeyboardButton(
                    text="\u0421\u043a\u0440\u044b\u0442\u044c" if c.is_active else "\u0410\u043a\u0442\u0438\u0432\u0438\u0440\u043e\u0432\u0430\u0442\u044c",
                    callback_data=f"cat_toggle_{c.id}"
                )
            ],
            [InlineKeyboardButton(text="\u041d\u0430\u0437\u0430\u0434 \u043a \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f\u043c", callback_data="categories_list")],
        ]

        await call.message.answer(
            f"\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f: {c.name}\n\u0421\u0442\u0430\u0442\u0443\u0441: {status_text}",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("cat_toggle_"))
async def category_toggle(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
        return

    category_id = int(call.data.replace("cat_toggle_", ""))

    db = SessionLocal()
    try:
        c = db.query(Category).filter(Category.id == category_id).first()
        if c:
            c.is_active = not c.is_active
            db.commit()
            await call.message.answer("\u0421\u0442\u0430\u0442\u0443\u0441 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438 \u0438\u0437\u043c\u0435\u043d\u0435\u043d.")
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data == "add_product")
async def add_product_start(call: CallbackQuery, state: FSMContext):
    if not is_admin(call.from_user.id):
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
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
            await call.message.answer("\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0434\u043e\u0431\u0430\u0432\u044c\u0442\u0435 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044e.", reply_markup=menu())
            await call.answer()
            return

        buttons = []
        for c in categories:
            buttons.append([
                InlineKeyboardButton(text=c.name, callback_data=f"ap_cat_{c.id}")
            ])

        await call.message.answer(
            "\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044e \u0442\u043e\u0432\u0430\u0440\u0430:",
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
    await call.message.answer("\u041e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u0442\u043e\u0432\u0430\u0440\u0430:")
    await state.set_state(AddProduct.name)
    await call.answer()


@router.message(AddProduct.name)
async def product_name(message: Message, state: FSMContext):
    await state.update_data(name=message.text.strip())
    await message.answer("\u041e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 \u0446\u0435\u043d\u0443. \u041d\u0430\u043f\u0440\u0438\u043c\u0435\u0440: 25000")
    await state.set_state(AddProduct.price)


@router.message(AddProduct.price)
async def product_price(message: Message, state: FSMContext):
    digits = re.sub(r"\D", "", message.text or "")
    price = int(digits) if digits else 0
    await state.update_data(price=price)
    await message.answer("\u041e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 \u043e\u043f\u0438\u0441\u0430\u043d\u0438\u0435 \u0442\u043e\u0432\u0430\u0440\u0430. \u0415\u0441\u043b\u0438 \u043e\u043f\u0438\u0441\u0430\u043d\u0438\u0435 \u043d\u0435 \u043d\u0443\u0436\u043d\u043e, \u043e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 -")
    await state.set_state(AddProduct.description)


@router.message(AddProduct.description)
async def product_description(message: Message, state: FSMContext):
    description = "" if message.text.strip() == "-" else message.text.strip()
    await state.update_data(description=description)
    await message.answer("\u041e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 \u0444\u043e\u0442\u043e \u0442\u043e\u0432\u0430\u0440\u0430. \u0415\u0441\u043b\u0438 \u0444\u043e\u0442\u043e \u043d\u0435 \u043d\u0443\u0436\u043d\u043e, \u043e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 -")
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
            f"\u0422\u043e\u0432\u0430\u0440 \u0434\u043e\u0431\u0430\u0432\u043b\u0435\u043d!\n\n"
            f"\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435: {product.name}\n"
            f"\u0426\u0435\u043d\u0430: {product.price} \u0441\u043e\u043c\u043e\u043d",
            reply_markup=menu()
        )
    finally:
        db.close()

    await state.clear()


@router.callback_query(F.data == "products_list")
async def products_list(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
        return

    db = SessionLocal()
    try:
        products = db.query(Product).order_by(Product.id.desc()).limit(30).all()

        if not products:
            await call.message.answer("\u0422\u043e\u0432\u0430\u0440\u043e\u0432 \u043f\u043e\u043a\u0430 \u043d\u0435\u0442.", reply_markup=back_menu())
            await call.answer()
            return

        buttons = []
        for p in products:
            status = "\u0410\u043a\u0442\u0438\u0432\u043d\u044b\u0439" if p.is_active else "\u0421\u043a\u0440\u044b\u0442\u044b\u0439"
            buttons.append([
                InlineKeyboardButton(
                    text=f"{p.name} - {status}",
                    callback_data=f"prod_menu_{p.id}"
                )
            ])

        buttons.append([InlineKeyboardButton(text="\u041d\u0430\u0437\u0430\u0434 \u0432 \u043c\u0435\u043d\u044e", callback_data="main_menu")])

        await call.message.answer(
            "\u0421\u043f\u0438\u0441\u043e\u043a \u0442\u043e\u0432\u0430\u0440\u043e\u0432:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    finally:
        db.close()

    await call.answer()


@router.callback_query(F.data.startswith("prod_menu_"))
async def product_menu(call: CallbackQuery):
    if not is_admin(call.from_user.id):
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
        return

    product_id = int(call.data.replace("prod_menu_", ""))

    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if not p:
            await call.message.answer("\u0422\u043e\u0432\u0430\u0440 \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d.")
            await call.answer()
            return

        status_text = "\u0410\u043a\u0442\u0438\u0432\u043d\u044b\u0439" if p.is_active else "\u0421\u043a\u0440\u044b\u0442\u044b\u0439"
        category_name = p.category.name if p.category else "-"

        buttons = [
            [
                InlineKeyboardButton(
                    text="\u0421\u043a\u0440\u044b\u0442\u044c" if p.is_active else "\u0410\u043a\u0442\u0438\u0432\u0438\u0440\u043e\u0432\u0430\u0442\u044c",
                    callback_data=f"prod_toggle_{p.id}"
                )
            ],
            [InlineKeyboardButton(text="\u041d\u0430\u0437\u0430\u0434 \u043a \u0442\u043e\u0432\u0430\u0440\u0430\u043c", callback_data="products_list")],
        ]

        text = (
            f"\u0422\u043e\u0432\u0430\u0440: {p.name}\n"
            f"\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f: {category_name}\n"
            f"\u0426\u0435\u043d\u0430: {p.price} \u0441\u043e\u043c\u043e\u043d\n"
            f"\u0421\u0442\u0430\u0442\u0443\u0441: {status_text}"
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
        await call.answer("\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430", show_alert=True)
        return

    product_id = int(call.data.replace("prod_toggle_", ""))

    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if p:
            p.is_active = not p.is_active
            db.commit()
            await call.message.answer("\u0421\u0442\u0430\u0442\u0443\u0441 \u0442\u043e\u0432\u0430\u0440\u0430 \u0438\u0437\u043c\u0435\u043d\u0435\u043d.")
    finally:
        db.close()

    await call.answer()


async def start_bot():
    if not settings.BOT_TOKEN or settings.BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
        print("BOT_TOKEN is not set. Bot is not started.")
        return

    bot = Bot(token=settings.BOT_TOKEN)
    dp = Dispatcher(storage=MemoryStorage())
    dp.include_router(router)

    print("Telegram bot started")
    await dp.start_polling(bot)
