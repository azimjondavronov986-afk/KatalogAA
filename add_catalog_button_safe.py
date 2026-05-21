from pathlib import Path
import shutil

root = Path(r"D:\My Project\KatalogA")
bot_file = root / "app" / "bot" / "main.py"

if not bot_file.exists():
    raise SystemExit("app/bot/main.py topilmadi")

text = bot_file.read_text(encoding="utf-8")

backup = bot_file.with_suffix(".py.bak_catalog_button")
backup.write_text(text, encoding="utf-8")

start = text.find("def menu():")
end = text.find("\n\ndef back_menu():")

if start == -1 or end == -1 or end <= start:
    raise SystemExit("menu() yoki back_menu() topilmadi")

new_menu = '''def menu():
    catalog_url = "https://katalogaa-production.up.railway.app/agent?lang=ru"

    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="Каталог", url=catalog_url)],
            [InlineKeyboardButton(text="Добавить товар", callback_data="add_product")],
            [InlineKeyboardButton(text="Товары", callback_data="products_list")],
            [InlineKeyboardButton(text="Добавить категорию", callback_data="add_category")],
            [InlineKeyboardButton(text="Категории", callback_data="categories_list")],
        ]
    )
'''

text = text[:start] + new_menu + text[end:]

bot_file.write_text(text, encoding="utf-8")

for p in root.rglob("__pycache__"):
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)

print("OK: Bot menyusiga Каталог tugmasi qo'shildi")
print(bot_file)
