from fastapi import FastAPI, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.gmail_service import fetch_unread_emails

app = FastAPI(
    title="AeroInbox Gmail Microservice",
    description="Internal microservice for fetching and parsing emails from the Gmail API.",
    version="1.0.0"
)

security = HTTPBearer()

@app.get("/unread")
async def get_unread(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """
    Exposes an endpoint to fetch unread emails.
    Expects a Bearer token (Google access token) in the Authorization header.
    """
    token = credentials.credentials
    emails = await fetch_unread_emails(access_token=token)
    return emails

@app.get("/health")
async def health():
    """
    Simple health check endpoint.
    """
    return {"status": "healthy", "service": "gmail-service"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
