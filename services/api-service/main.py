from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import httpx
from config.settings import settings
from routes.auth import router as auth_router
from routes.emails import router as emails_router

app = FastAPI(
    title="AeroInbox API Gateway",
    description="Central gateway routing requests to auth, emails, and internal services.",
    version="1.0.0"
)

# Configure CORS (allow frontend through proxy and dev servers)
origins = [
    settings.FRONTEND_URL,
    "http://localhost:5173",
    "http://localhost",
    "http://127.0.0.1",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Open internally since Nginx manages public access
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/auth", tags=["Authentication"])
app.include_router(emails_router, prefix="/emails", tags=["Emails"])

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
async def health():
    """
    Simple health check endpoint.
    """
    return {"status": "healthy", "service": "api-service"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
