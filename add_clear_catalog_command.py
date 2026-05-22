from pathlib import Path
import re
import shutil
import sqlite3

root = Path(r"D:\My Project\KatalogA")
bot_file = root / "app" / "bot" / "main.py"

if not bot_file.exists():
    raise SystemExit("app/bot/main.py topilmadi")

text = bot_file.read_text(encoding="utf-8")
backup = bot_file.with_suffix(".py.bak_clear_catalog")
backup.write_text(text, encoding="utf-8")

# Kerakli importlar
if "from sqlalchemy import text" not in text:
    text = text.replace("import re\n", "import re\nfrom sqlalchemy import text\n")

if "from pathlib import Path" not in text:
    text = text.replace("import re\n", "import re\nfrom pathlib import Path\n")

# Eski clear handler bo'lsa olib tashlaymiz
text = re.sub(
    r"\n# KATALOGAA_CLEAR_COMMAND_START.*?# KATALOGAA_CLEAR_COMMAND_END\n",
    "\n",
    text,
    flags=re.DOTALL
)

clear_code = r'''
# KATALOGAA_CLEAR_COMMAND_START

def _db_table_exists(db, table_name: str) -> bool:
    row = db.execute(
        text("SELECT name FROM sqlite_master WHERE type='table' AND name=:name"),
        {"name": table_name}
    ).fetchone()
    return row is not None


def _clear_uploads_folder():
    try:
        upload_dir = Path(settings.UPLOAD_DIR)
        upload_dir.mkdir(parents=True, exist_ok=True)

        for item in upload_dir.iterdir():
            if item.name == ".gitkeep":
                continue

            if item.is_file():
                item.unlink(missing_ok=True)
            elif item.is_dir():
                shutil.rmtree(item, ignore_errors=True)
    except Exception:
        pass


def _clear_catalog_database():
    db = SessionLocal()
    try:
        tables = [
            "order_items",
            "order_item",
            "orders",
            "order",
            "products",
            "product",
            "categories",
            "category",
        ]

        for table in tables:
            if _db_table_exists(db, table):
                db.execute(text(f'DELETE FROM "{table}"'))

        if _db_table_exists(db, "sqlite_sequence"):
            for table in tables:
                db.execute(
                    text('DELETE FROM sqlite_sequence WHERE name=:name'),
                    {"name": table}
                )

        db.commit()
    finally:
        db.close()


@router.message(Command("clear_catalog"))
async def clear_catalog_info(message: Message):
    if not is_admin(message.from_user.id):
        await message.answer("У вас нет доступа.")
        return

    await message.answer(
        "Внимание! Будут удалены все категории, товары, заказы и изображения.\n\n"
        "Для подтверждения отправьте команду:\n"
        "/clear_catalog_ha"
    )


@router.message(Command("clear_catalog_ha"))
async def clear_catalog_confirm(message: Message):
    if not is_admin(message.from_user.id):
        await message.answer("У вас нет доступа.")
        return

    _clear_catalog_database()
    _clear_uploads_folder()

    await message.answer(
        "Каталог очищен.\n"
        "Теперь можно добавлять категории и товары с нуля."
    )

# KATALOGAA_CLEAR_COMMAND_END
'''

marker = "\n\nasync def start_bot():"
if marker not in text:
    raise SystemExit("async def start_bot() topilmadi")

text = text.replace(marker, "\n" + clear_code + marker)

bot_file.write_text(text, encoding="utf-8")

# Local seed DB larni ham tozalaymiz, kelajak deployda eski mahsulot qaytib kelmasin
db_files = [
    root / "app.db",
    root / "data_seed" / "app.db",
]

for db_path in db_files:
    if db_path.exists():
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        tables = [
            "order_items",
            "order_item",
            "orders",
            "order",
            "products",
            "product",
            "categories",
            "category",
        ]

        for table in tables:
            cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table,))
            if cur.fetchone():
                cur.execute(f'DELETE FROM "{table}"')

        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='sqlite_sequence'")
        if cur.fetchone():
            for table in tables:
                cur.execute("DELETE FROM sqlite_sequence WHERE name=?", (table,))

        conn.commit()
        conn.close()
        print("LOCAL DB CLEANED:", db_path)

# Local seed uploads ham tozalanadi
upload_dirs = [
    root / "data_seed" / "uploads",
    root / "app" / "static" / "uploads",
]

for upload_dir in upload_dirs:
    if upload_dir.exists():
        for item in upload_dir.iterdir():
            if item.name == ".gitkeep":
                continue

            if item.is_file():
                item.unlink(missing_ok=True)
            elif item.is_dir():
                shutil.rmtree(item, ignore_errors=True)

        print("LOCAL UPLOADS CLEANED:", upload_dir)

for p in root.rglob("__pycache__"):
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)

print("OK: clear catalog command added to Telegram bot")
