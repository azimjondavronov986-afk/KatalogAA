from pathlib import Path
import re
import shutil

root = Path(r"D:\My Project\KatalogA")
bot_file = root / "app" / "bot" / "main.py"

if not bot_file.exists():
    raise SystemExit("app/bot/main.py topilmadi")

text = bot_file.read_text(encoding="utf-8")

backup = bot_file.with_suffix(".py.bak_catalog_button")
backup.write_text(text, encoding="utf-8")

new_menu = r'''def menu():
    catalog_url = "https://katalogaa-production.up.railway.app/agent?lang=ru"

    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="\u041a\u0430\u0442\u0430\u043b\u043e\u0433", url=catalog_url)],
            [InlineKeyboardButton(text="\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u0442\u043e\u0432\u0430\u0440", callback_data="add_product")],
            [InlineKeyboardButton(text="\u0422\u043e\u0432\u0430\u0440\u044b", callback_data="products_list")],
            [InlineKeyboardButton(text="\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044e", callback_data="add_category")],
            [InlineKeyboardButton(text="\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438", callback_data="categories_list")],
        ]
    )
'''

pattern = r"def menu\(\):.*?(?=\n\ndef back_menu\(\):)"

if not re.search(pattern, text, flags=re.DOTALL):
    raise SystemExit("menu() funksiyasi topilmadi. app/bot/main.py ichini tekshirish kerak.")

text = re.sub(
    pattern,
    new_menu,
    text,
    flags=re.DOTALL
)

bot_file.write_text(text, encoding="utf-8")

for p in root.rglob("__pycache__"):
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)

print("OK: Bot menyusiga Каталог tugmasi qo'shildi")
print(bot_file)
