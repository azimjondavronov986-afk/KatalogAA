
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
