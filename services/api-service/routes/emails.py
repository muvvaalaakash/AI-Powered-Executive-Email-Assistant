import httpx
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from config.settings import settings

router = APIRouter()
security = HTTPBearer()

@router.get("/unread")
async def get_unread_emails(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """
    Fetches the unread emails by coordinating the Gmail Service and AI Service.
    Expects the Google OAuth access token as a Bearer token in the Authorization header.
    """
    token = credentials.credentials
    
    # 1. Fetch unread emails from the Gmail Microservice
    async with httpx.AsyncClient() as client:
        try:
            gmail_response = await client.get(
                f"{settings.GMAIL_SERVICE_URL}/unread",
                headers={"Authorization": f"Bearer {token}"},
                timeout=30.0
            )
        except Exception as e:
            raise HTTPException(
                status_code=502,
                detail=f"Failed to connect to Gmail service: {str(e)}"
            )

        if gmail_response.status_code != 200:
            # Propagate detailed error message
            detail_msg = "Error fetching emails from Gmail service"
            try:
                detail_msg = gmail_response.json().get("detail", detail_msg)
            except Exception:
                pass
            raise HTTPException(
                status_code=gmail_response.status_code,
                detail=detail_msg
            )
            
        emails = gmail_response.json()
        
        # 2. Run bulk AI classification via the AI Microservice
        if emails:
            try:
                ai_response = await client.post(
                    f"{settings.AI_SERVICE_URL}/process/bulk",
                    json={"emails": emails},
                    timeout=45.0
                )
                if ai_response.status_code == 200:
                    analyses = ai_response.json()
                    for email in emails:
                        email_id = email.get("id")
                        analysis_item = analyses.get(email_id)
                        if analysis_item:
                            email["ai_analysis"] = {
                                "summary": analysis_item.get("summary"),
                                "priority": analysis_item.get("priority"),
                                "reply": analysis_item.get("reply")
                            }
                        else:
                            email["ai_analysis"] = None
                else:
                    # Log error internally and fallback gracefully (return emails without AI insights)
                    print(f"AI Service returned status code {ai_response.status_code}: {ai_response.text}")
                    for email in emails:
                        email["ai_analysis"] = None
            except Exception as e:
                # Fallback: log the failure, but still return raw emails rather than failing the entire request
                print(f"Orchestrator resilient fallback: AI Service call failed: {str(e)}")
                for email in emails:
                    email["ai_analysis"] = None
                    
        return emails
