$root = "D:\My Project\KatalogA"

New-Item -ItemType Directory -Force -Path $root | Out-Null

$folders = @(
    "app",
    "app\routes",
    "app\services",
    "app\bot",
    "app\templates",
    "app\templates\admin",
    "app\static",
    "app\static\css",
    "app\static\js",
    "app\static\uploads"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $folder) | Out-Null
}

Set-Content -Encoding UTF8 -Path "$root\requirements.txt" -Value @"
fastapi
uvicorn[standard]
jinja2
python-multipart
sqlalchemy
aiogram
python-dotenv
"@

Set-Content -Encoding UTF8 -Path "$root\.env" -Value @"
APP_NAME=KatalogA
BASE_URL=http://127.0.0.1:8000

ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123

BOT_TOKEN=YOUR_BOT_TOKEN_HERE
ADMIN_IDS=123456789
ORDER_GROUP_ID=-1001234567890

TIMEZONE=Asia/Tashkent
"@

Set-Content -Encoding UTF8 -Path "$root\run_web.py" -Value @"
from app.main import app
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="127.0.0.1",
        port=8000,
        reload=True
    )
"@

Set-Content -Encoding UTF8 -Path "$root\run_bot.py" -Value @"
import asyncio
from app.bot.main import start_bot

if __name__ == "__main__":
    asyncio.run(start_bot())
"@

Set-Content -Encoding UTF8 -Path "$root\app\__init__.py" -Value ""

Set-Content -Encoding UTF8 -Path "$root\app\config.py" -Value @"
import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


class Settings:
    APP_NAME = os.getenv("APP_NAME", "KatalogA")
    BASE_URL = os.getenv("BASE_URL", "http://127.0.0.1:8000")

    ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin123")

    BOT_TOKEN = os.getenv("BOT_TOKEN", "")
    ADMIN_IDS = os.getenv("ADMIN_IDS", "")
    ORDER_GROUP_ID = os.getenv("ORDER_GROUP_ID", "")

    TIMEZONE = os.getenv("TIMEZONE", "Asia/Tashkent")
    DATABASE_URL = f"sqlite:///{BASE_DIR / 'app.db'}"

    @property
    def admin_ids_list(self):
        result = []
        for item in self.ADMIN_IDS.split(","):
            item = item.strip()
            if item.isdigit():
                result.append(int(item))
        return result


settings = Settings()
"@

Set-Content -Encoding UTF8 -Path "$root\app\database.py" -Value @"
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config import settings

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
"@

Set-Content -Encoding UTF8 -Path "$root\app\models.py" -Value @"
from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    image = Column(String(500), nullable=True)
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    products = relationship("Product", back_populates="category")


class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=False)

    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Integer, default=0)
    image = Column(String(500), nullable=True)

    is_active = Column(Boolean, default=True)
    is_orderable = Column(Boolean, default=True)
    order_fields = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

    category = relationship("Category", back_populates="products")
    orders = relationship("Order", back_populates="product")


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)

    customer_name = Column(String(255), nullable=True)
    customer_phone = Column(String(100), nullable=True)
    quantity = Column(Integer, default=1)

    answers_json = Column(Text, nullable=True)
    status = Column(String(100), default="new")
    telegram_message_id = Column(String(100), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    product = relationship("Product", back_populates="orders")
"@

Set-Content -Encoding UTF8 -Path "$root\app\main.py" -Value @"
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from app.database import init_db
from app.config import BASE_DIR, settings

app = FastAPI(title=settings.APP_NAME)

app.mount(
    "/static",
    StaticFiles(directory=str(BASE_DIR / "app" / "static")),
    name="static"
)


@app.on_event("startup")
def startup_event():
    init_db()


@app.get("/")
def home():
    return {
        "status": "ok",
        "message": "KatalogA ishga tushdi"
    }
"@

Set-Content -Encoding UTF8 -Path "$root\app\bot\main.py" -Value @"
from aiogram import Bot, Dispatcher
from app.config import settings


async def start_bot():
    if not settings.BOT_TOKEN or settings.BOT_TOKEN == "YOUR_BOT_TOKEN_HERE":
        print("BOT_TOKEN .env faylida yozilmagan")
        return

    bot = Bot(token=settings.BOT_TOKEN)
    dp = Dispatcher()

    print("Telegram bot ishga tushdi")
    await dp.start_polling(bot)
"@

Write-Host ""
Write-Host "✅ KatalogA papkalari va asosiy fayllar yaratildi:" -ForegroundColor Green
Write-Host $root -ForegroundColor Cyan
Write-Host ""
Write-Host "Keyingi qadam:"
Write-Host "cd `"D:\My Project\KatalogA`""
Write-Host "python -m venv .venv"
Write-Host ".\.venv\Scripts\activate"
Write-Host "pip install -r requirements.txt"
Write-Host "python run_web.py"