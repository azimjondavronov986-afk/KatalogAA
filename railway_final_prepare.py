from pathlib import Path
import shutil

root = Path(r"D:\My Project\KatalogA")

# Seed papka: hozirgi local DB va rasmlarni Railway birinchi startda /data ichiga ko'chirish uchun
seed_dir = root / "data_seed"
seed_uploads = seed_dir / "uploads"
seed_uploads.mkdir(parents=True, exist_ok=True)

local_db = root / "app.db"
if local_db.exists():
    shutil.copy2(local_db, seed_dir / "app.db")

local_uploads = root / "app" / "static" / "uploads"
if local_uploads.exists():
    for item in local_uploads.iterdir():
        if item.is_file():
            shutil.copy2(item, seed_uploads / item.name)

# Railway start fayl
start_py = r'''
import asyncio
import os
import uvicorn

from app.main import app
from app.config import settings


async def run_web():
    port = int(os.environ.get("PORT", "8000"))
    config = uvicorn.Config(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )
    server = uvicorn.Server(config)
    await server.serve()


async def run_bot_if_enabled():
    if not settings.BOT_TOKEN or settings.BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
        print("BOT_TOKEN yo'q. Faqat web ishga tushadi.")
        return

    from app.bot.main import start_bot
    await start_bot()


async def main():
    await asyncio.gather(
        run_web(),
        run_bot_if_enabled()
    )


if __name__ == "__main__":
    asyncio.run(main())
'''
(root / "start.py").write_text(start_py, encoding="utf-8")

# Railway config
railway_toml = r'''[build]
builder = "NIXPACKS"

[deploy]
startCommand = "python start.py"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
'''
(root / "railway.toml").write_text(railway_toml, encoding="utf-8")

(root / ".python-version").write_text("3.11\n", encoding="utf-8")

# Config: localda data/, Railwayda /data volume
config_py = r'''
import os
import shutil
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


class Settings:
    APP_NAME = os.getenv("APP_NAME", "KatalogA")
    BASE_URL = os.getenv("BASE_URL", "http://127.0.0.1:8000")

    ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin123")

    AGENT_USERNAME = os.getenv("AGENT_USERNAME", "agent")
    AGENT_PASSWORD = os.getenv("AGENT_PASSWORD", "agent123")

    BOT_TOKEN = os.getenv("BOT_TOKEN", "")
    ADMIN_IDS = os.getenv("ADMIN_IDS", "")
    ORDER_GROUP_ID = os.getenv("ORDER_GROUP_ID", "")

    TIMEZONE = os.getenv("TIMEZONE", "Asia/Tashkent")

    VOLUME_PATH = os.getenv("RAILWAY_VOLUME_MOUNT_PATH") or os.getenv("DATA_DIR")
    DATA_DIR = Path(VOLUME_PATH) if VOLUME_PATH else BASE_DIR / "data"
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR") or DATA_DIR / "uploads")
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    DB_PATH = DATA_DIR / "app.db"
    DATABASE_URL = os.getenv("DATABASE_URL") or f"sqlite:///{DB_PATH}"

    @property
    def admin_ids_list(self):
        result = []
        for item in self.ADMIN_IDS.split(","):
            item = item.strip()
            if item.isdigit():
                result.append(int(item))
        return result


settings = Settings()


def prepare_storage():
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
    settings.UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    seed_db = BASE_DIR / "data_seed" / "app.db"
    legacy_db = BASE_DIR / "app.db"

    if not settings.DB_PATH.exists():
        if seed_db.exists():
            shutil.copy2(seed_db, settings.DB_PATH)
        elif legacy_db.exists():
            shutil.copy2(legacy_db, settings.DB_PATH)

    seed_uploads = BASE_DIR / "data_seed" / "uploads"
    if seed_uploads.exists():
        for item in seed_uploads.iterdir():
            if item.is_file():
                target = settings.UPLOAD_DIR / item.name
                if not target.exists():
                    shutil.copy2(item, target)
'''
(root / "app" / "config.py").write_text(config_py, encoding="utf-8")

# Database
database_py = r'''
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config import settings, prepare_storage

prepare_storage()

engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    from app import models
    Base.metadata.create_all(bind=engine)
'''
(root / "app" / "database.py").write_text(database_py, encoding="utf-8")

# Main: /uploads route qo'shish
main_py = r'''
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# Jinja TemplateResponse compatibility fix
_original_template_response = Jinja2Templates.TemplateResponse


def _template_response_compat(self, *args, **kwargs):
    if len(args) >= 2 and isinstance(args[0], str) and isinstance(args[1], dict):
        name = args[0]
        context = dict(args[1])
        request = context.pop("request", None)

        if request is None:
            raise RuntimeError("Template context ichida request topilmadi")

        return _original_template_response(
            self,
            request,
            name,
            context,
            *args[2:],
            **kwargs
        )

    return _original_template_response(self, *args, **kwargs)


Jinja2Templates.TemplateResponse = _template_response_compat

from app.database import init_db
from app.config import BASE_DIR, settings, prepare_storage
from app.routes import web, admin, agent

prepare_storage()

app = FastAPI(title=settings.APP_NAME)

app.mount(
    "/static",
    StaticFiles(directory=str(BASE_DIR / "app" / "static")),
    name="static"
)

app.mount(
    "/uploads",
    StaticFiles(directory=str(settings.UPLOAD_DIR)),
    name="uploads"
)


@app.on_event("startup")
def startup_event():
    init_db()


app.include_router(web.router)
app.include_router(admin.router)
app.include_router(agent.router)
'''
(root / "app" / "main.py").write_text(main_py, encoding="utf-8")

# HTML ichida rasmlar /uploads orqali chiqsin
templates_dir = root / "app" / "templates"
if templates_dir.exists():
    for html in templates_dir.rglob("*.html"):
        text = html.read_text(encoding="utf-8")
        text = text.replace("/static/uploads/{{ product.image }}", "/uploads/{{ product.image }}")
        text = text.replace("/static/uploads/{{ category.image }}", "/uploads/{{ category.image }}")
        html.write_text(text, encoding="utf-8")

# Admin upload path
admin_py = root / "app" / "routes" / "admin.py"
if admin_py.exists():
    text = admin_py.read_text(encoding="utf-8")
    if "from pathlib import Path" not in text:
        text = text.replace("import shutil\n", "import shutil\nfrom pathlib import Path\n")
    text = text.replace(
        'upload_dir = BASE_DIR / "app" / "static" / "uploads"',
        'upload_dir = Path(settings.UPLOAD_DIR)'
    )
    admin_py.write_text(text, encoding="utf-8")

# Bot upload path
bot_py = root / "app" / "bot" / "main.py"
if bot_py.exists():
    text = bot_py.read_text(encoding="utf-8")
    if "from pathlib import Path" not in text:
        text = text.replace("import re\n", "import re\nfrom pathlib import Path\n")
    text = text.replace(
        'upload_dir = BASE_DIR / "app" / "static" / "uploads"',
        'upload_dir = Path(settings.UPLOAD_DIR)'
    )
    text = text.replace(
        'destination = settings.UPLOAD_DIR / image_name',
        'destination = Path(settings.UPLOAD_DIR) / image_name'
    )
    bot_py.write_text(text, encoding="utf-8")

# Telegram service image path
tg_py = root / "app" / "services" / "telegram.py"
if tg_py.exists():
    text = tg_py.read_text(encoding="utf-8")
    if "from pathlib import Path" not in text:
        text = text.replace("import json\n", "import json\nfrom pathlib import Path\n")
    text = text.replace(
        'image_path = BASE_DIR / "app" / "static" / "uploads" / product.image',
        'image_path = Path(settings.UPLOAD_DIR) / product.image'
    )
    text = text.replace(
        'image_path = settings.UPLOAD_DIR / product.image if product.image else None',
        'image_path = Path(settings.UPLOAD_DIR) / product.image if product.image else None'
    )
    tg_py.write_text(text, encoding="utf-8")

# requirements tekshirish
req = root / "requirements.txt"
req_text = req.read_text(encoding="utf-8") if req.exists() else ""
needed = ["fastapi", "uvicorn[standard]", "jinja2", "python-multipart", "sqlalchemy", "aiogram", "python-dotenv"]
for item in needed:
    if item not in req_text:
        req_text += "\n" + item
req.write_text(req_text.strip() + "\n", encoding="utf-8")

# .gitignore
gitignore = root / ".gitignore"
current = gitignore.read_text(encoding="utf-8") if gitignore.exists() else ""
items = [
    ".venv/",
    "__pycache__/",
    "*.pyc",
    ".env",
    "data/",
    "fix_*.py",
    "fix_*.ps1",
    "*_fix.py",
    "*_fix.ps1",
]
lines = []
for line in current.splitlines():
    line = line.strip()
    if not line:
        continue
    if line in ["app.db", "app/static/uploads/*", "!app/static/uploads/.gitkeep"]:
        continue
    if line not in lines:
        lines.append(line)

for item in items:
    if item not in lines:
        lines.append(item)

gitignore.write_text("\n".join(lines) + "\n", encoding="utf-8")

# pycache tozalash
for p in root.rglob("__pycache__"):
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)

print("вњ… Railway final tayyorlandi")
print("вњ… start.py yaratildi: web + bot bitta service ichida ishlaydi")
print("вњ… DB va uploads /data volume bilan ishlaydi")
print("вњ… /uploads route qo'shildi")
