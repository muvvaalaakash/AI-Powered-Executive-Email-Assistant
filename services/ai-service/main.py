from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from services.openai_service import analyze_email_content, analyze_emails_bulk, EmailAnalysis, EmailAnalysisItem

app = FastAPI(
    title="AeroInbox AI Microservice",
    description="Internal microservice for analyzing emails and generating draft responses via Google Gemini.",
    version="1.0.0"
)

class EmailProcessRequest(BaseModel):
    email_content: str

class BulkEmailProcessRequest(BaseModel):
    emails: list[dict]

@app.post("/process", response_model=EmailAnalysis)
def process_email(payload: EmailProcessRequest):
    """
    Processes a single email content and returns executive summary, priority, and reply suggestion.
    """
    try:
        analysis = analyze_email_content(payload.email_content)
        return analysis
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/process/bulk")
def process_emails_bulk(payload: BulkEmailProcessRequest):
    """
    Processes a batch of emails in a single Gemini request and returns analyses dictionary.
    """
    try:
        analyses = analyze_emails_bulk(payload.emails)
        return analyses
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
def health():
    """
    Simple health check endpoint.
    """
    return {"status": "healthy", "service": "ai-service"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
