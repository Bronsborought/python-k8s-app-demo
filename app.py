import os

from fastapi import FastAPI, Header
from fastapi.responses import PlainTextResponse


app = FastAPI(
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)


@app.get("/", response_class=PlainTextResponse)
def root():
    pod_name = os.getenv("HOSTNAME", "unknown")
    app_message = os.getenv("APP_MESSAGE", "Hello")

    return f"{app_message} | Pod: {pod_name}\n"


@app.get("/health", response_class=PlainTextResponse)
def health():
    return "Healthy\n"


@app.get("/ready", response_class=PlainTextResponse)
def ready():
    app_secret = os.getenv("APP_SECRET")

    if not app_secret:
        return PlainTextResponse("Not ready\n", status_code=503)

    return PlainTextResponse("Ready\n", status_code=200)


@app.get("/secret", response_class=PlainTextResponse)
def secret(x_api_key: str | None = Header(default=None, alias="X-API-Key")):
    app_secret = os.getenv("APP_SECRET")

    if not app_secret:
        return PlainTextResponse("Service unavailable\n", status_code=503)

    if x_api_key != app_secret:
        return PlainTextResponse("Unauthorized\n", status_code=401)

    return PlainTextResponse("Secret access granted\n", status_code=200)