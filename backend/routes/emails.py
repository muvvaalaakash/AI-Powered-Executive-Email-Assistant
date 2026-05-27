from fastapi import APIRouter, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.gmail_service import fetch_unread_emails
from services.openai_service import analyze_emails_bulk

router = APIRouter()
security = HTTPBearer()

@router.get("/unread")
async def get_unread_emails(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """
    Fetches the unread emails from the authenticated user's Gmail account.
    Expects the Google OAuth access token as a Bearer token in the Authorization header.
    Runs bulk AI classification on retrieved messages to attach priority, summary, and reply.
    """
    token = credentials.credentials
    emails = await fetch_unread_emails(access_token=token)
    
    # Run bulk AI classification to attach priority levels, summaries, and reply drafts
    if emails:
        try:
            analyses = analyze_emails_bulk(emails)
            for email in emails:
                email_id = email.get("id")
                analysis_item = analyses.get(email_id)
                if analysis_item:
                    email["ai_analysis"] = {
                        "summary": analysis_item.summary,
                        "priority": analysis_item.priority,
                        "reply": analysis_item.reply
                    }
                else:
                    email["ai_analysis"] = None
        except Exception as e:
            # Resiliency fallback: print error and return emails without AI features rather than failing the request
            print(f"Resilient fallback triggered: Bulk AI analysis failed: {str(e)}")
            for email in emails:
                email["ai_analysis"] = None
                
    return emails
