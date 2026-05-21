
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
