
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
