import json
import logging
import os
import time

from fastapi import FastAPI, Header, Request, Response
from fastapi.responses import PlainTextResponse
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("app")

HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "path", "status_code"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "path"],
)

HTTP_REQUEST_ERRORS_TOTAL = Counter(
    "http_request_errors_total",
    "Total number of HTTP requests resulting in server errors",
    ["method", "path", "status_code"],
)

app = FastAPI(
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)


@app.middleware("http")
async def observe_request(request: Request, call_next):
    if request.url.path == "/metrics":
        return await call_next(request)

    start_time = time.perf_counter()
    status_code = 500

    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    finally:
        duration = time.perf_counter() - start_time

        route = request.scope.get("route")
        metric_path = getattr(route, "path", "unmatched")

        HTTP_REQUESTS_TOTAL.labels(
            method=request.method,
            path=metric_path,
            status_code=str(status_code),
        ).inc()

        HTTP_REQUEST_DURATION_SECONDS.labels(
            method=request.method,
            path=metric_path,
        ).observe(duration)

        if status_code >= 500:
            HTTP_REQUEST_ERRORS_TOTAL.labels(
                method=request.method,
                path=metric_path,
                status_code=str(status_code),
            ).inc()

        logger.info(
            json.dumps(
                {
                    "event": "http_request",
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": status_code,
                    "duration_seconds": round(duration, 6),
                }
            )
        )


@app.get("/metrics")
def metrics():
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
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