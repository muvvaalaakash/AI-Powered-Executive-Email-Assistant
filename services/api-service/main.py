import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Response, status
from fastapi.middleware.cors import CORSMiddleware
import httpx

from config.settings import settings
from routes.auth import router as auth_router
from routes.emails import router as emails_router
from routes.meetings import router as meetings_router
from redis_client import redis_manager

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configure Azure Monitor OpenTelemetry if connection string is provided
if settings.APPLICATIONINSIGHTS_CONNECTION_STRING:
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor
        configure_azure_monitor(connection_string=settings.APPLICATIONINSIGHTS_CONNECTION_STRING)
        logger.info("Azure Monitor OpenTelemetry configured successfully for api-service.")
    except Exception as e:
        logger.error(f"Failed to configure Azure Monitor OpenTelemetry: {str(e)}")

from database import db as pg_db, initialize_db as pg_initialize_db

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize Redis and PostgreSQL pools
    logger.info("Starting api-service Gateway...")
    await redis_manager.initialize()
    try:
        await pg_initialize_db()
    except Exception as ex:
        logger.error(f"Failed to initialize PostgreSQL database on startup: {str(ex)}")
    yield
    # Shutdown: Close pools
    logger.info("Shutting down api-service Gateway...")
    await redis_manager.close()
    await pg_db.close()

app = FastAPI(
    title="AeroInbox API Gateway",
    description="Central gateway routing requests to auth, emails, and internal services.",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS (allow frontend through proxy and dev servers explicitly)
origins = [
    settings.FRONTEND_URL,
    "http://localhost:3000",
    "http://localhost:5173",
    "http://localhost",
    "http://127.0.0.1",
    "https://aeroinbox.com",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=r"https://.*\.azurestaticapps\.net",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/auth", tags=["Authentication"])
app.include_router(emails_router, prefix="/emails", tags=["Emails"])
app.include_router(meetings_router, prefix="/meetings", tags=["Meetings"])

@app.post("/ai/process")
async def process_email(payload: dict):
    """
    Gateway endpoint for processing a single email.
    Forwards the request payload to the internal AI microservice.
    """
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{settings.AI_SERVICE_URL}/process",
                json=payload,
                timeout=45.0
            )
            if response.status_code != 200:
                detail_msg = "Error from AI Service"
                try:
                    detail_msg = response.json().get("detail", detail_msg)
                except Exception:
                    pass
                raise HTTPException(
                    status_code=response.status_code,
                    detail=detail_msg
                )
            return response.json()
        except httpx.HTTPError as e:
            raise HTTPException(status_code=502, detail=f"Failed to communicate with AI Service: {str(e)}")

@app.get("/health")
async def health(response: Response):
    """
    Gateway health check verifying internal routing and Redis connectivity.
    """
    try:
        client = await redis_manager.get_client()
        await client.ping()
        redis_status = "healthy"
    except Exception as e:
        logger.error(f"Health check failed due to Redis connection error: {str(e)}", exc_info=True)
        redis_status = f"unhealthy: {str(e)}"

    if redis_status != "healthy":
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {
            "status": "unhealthy",
            "service": "api-service",
            "redis": redis_status
        }
        
    return {
        "status": "healthy",
        "service": "api-service",
        "redis": redis_status
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
