import google.generativeai as genai
from pydantic import BaseModel, Field
from fastapi import HTTPException
from config.settings import settings
import json

class EmailAnalysis(BaseModel):
    summary: str = Field(description="A concise executive summary of the email, highlighting the sender's main request and deadlines. Maximum 2-3 sentences.")
    priority: str = Field(description="Priority classification of the email. Allowed values: 'High', 'Medium', 'Low'.")
    reply: str = Field(description="A professional, polite, and concise reply suggestion written from the executive's perspective. Maximum 2 paragraphs.")

class EmailAnalysisItem(BaseModel):
    id: str = Field(description="The unique message ID of the email being analyzed.")
    summary: str = Field(description="A concise executive summary of the email, highlighting the sender's main request and deadlines. Maximum 2-3 sentences.")
    priority: str = Field(description="Priority classification of the email. Allowed values: 'High', 'Medium', 'Low'.")
    reply: str = Field(description="A professional, polite, and concise reply suggestion written from the executive's perspective. Maximum 2 paragraphs.")

class BulkEmailAnalysis(BaseModel):
    analyses: list[EmailAnalysisItem] = Field(description="List of email analyses matching the input email IDs.")


def analyze_email_content(email_content: str) -> EmailAnalysis:
    """
    Sends the email content to Google's gemini-2.5-flash model using Structured Outputs.
    Returns a validated EmailAnalysis Pydantic model containing summary, priority, and reply.
    """
    api_key = settings.GEMINI_API_KEY
    if not api_key or api_key.startswith("your_"):
        # Fallback in case they pasted the Gemini API key in the OPENAI_API_KEY slot
        if settings.OPENAI_API_KEY and settings.OPENAI_API_KEY.startswith("AIza"):
            api_key = settings.OPENAI_API_KEY

    if not api_key or api_key.startswith("your_"):
        raise HTTPException(
            status_code=500,
            detail="Gemini API Key (GEMINI_API_KEY) is not configured on the server. Please visit Google AI Studio to get a free key."
        )

    # Configure the Gemini API client
    genai.configure(api_key=api_key)

    system_instruction = (
        "You are an elite, executive-level Chief of Staff AI assistant. "
        "Your goal is to parse incoming emails for CEOs, founders, and busy managers. "
        "Provide: "
        "1. Summary: Action-oriented, highlighting the main request and deadlines. Keep it brief (under 3 sentences).\n"
        "2. Priority:\n"
        "   - 'High': Actions needing immediate executive decisions, high-value client issues, or tight deadlines.\n"
        "   - 'Medium': Routine updates, non-urgent client followups, or scheduling requests.\n"
        "   - 'Low': Informational newsletters, internal FYI messages, or generic promotional emails.\n"
        "3. Reply: A concise, polished draft of a response. It must sound executive-grade (brief, polite, clear, and action-oriented). "
        "Ensure placeholders like [Your Name] are left only where absolutely necessary, but prioritize phrasing it clearly."
    )

    try:
        # Create GenerativeModel instance with the system instructions
        model = genai.GenerativeModel(
            model_name="gemini-flash-latest",
            system_instruction=system_instruction
        )

        # Call generate_content requesting JSON output matching the EmailAnalysis Pydantic schema
        response = model.generate_content(
            f"Analyze the following email content:\n\n{email_content}",
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                response_schema=EmailAnalysis
            )
        )

        if not response.text:
            raise HTTPException(status_code=500, detail="Gemini failed to return content response.")

        # Parse the JSON response text back into the Pydantic model
        parsed_result = EmailAnalysis.model_validate_json(response.text)
        return parsed_result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini API invocation failed: {str(e)}")


def analyze_emails_bulk(emails: list[dict]) -> dict[str, EmailAnalysisItem]:
    """
    Sends a bulk list of emails to Gemini in a single request for fast, cost-efficient analysis.
    Returns a dict mapping message_id -> EmailAnalysisItem.
    """
    if not emails:
        return {}

    api_key = settings.GEMINI_API_KEY
    if not api_key or api_key.startswith("your_"):
        if settings.OPENAI_API_KEY and settings.OPENAI_API_KEY.startswith("AIza"):
            api_key = settings.OPENAI_API_KEY

    if not api_key or api_key.startswith("your_"):
        raise Exception("Gemini API Key (GEMINI_API_KEY) is not configured on the server.")

    # Configure the Gemini API client
    genai.configure(api_key=api_key)

    # Format the prompt
    email_prompts = []
    for email in emails:
        # Truncate body snippet to conserve context tokens and speed up response times
        body_snippet = (email.get("body") or email.get("snippet") or "")[:1200]
        email_prompts.append(
            f"EMAIL ID: {email.get('id')}\n"
            f"FROM: {email.get('sender')}\n"
            f"SUBJECT: {email.get('subject')}\n"
            f"DATE: {email.get('date')}\n"
            f"BODY:\n{body_snippet}\n"
            f"---"
        )
    
    formatted_emails = "\n\n".join(email_prompts)

    system_instruction = (
        "You are an elite, executive-level Chief of Staff AI assistant. "
        "Your task is to analyze a batch of unread emails and return an analysis for EACH email in the list. "
        "For each email ID, provide:\n"
        "1. Summary: Action-oriented, highlighting the main request and deadlines. Keep it brief (under 3 sentences).\n"
        "2. Priority:\n"
        "   - 'High': Actions needing immediate executive decisions, high-value client issues, or tight deadlines.\n"
        "   - 'Medium': Routine updates, non-urgent client followups, or scheduling requests.\n"
        "   - 'Low': Informational newsletters, internal FYI messages, or generic promotional emails.\n"
        "3. Reply: A concise, polished draft response written from the executive's perspective (max 2 paragraphs). "
        "Keep placeholders to a minimum, and write it in a professional, clear, action-oriented tone."
    )

    try:
        model = genai.GenerativeModel(
            model_name="gemini-flash-latest",
            system_instruction=system_instruction
        )

        response = model.generate_content(
            f"Analyze the following batch of emails:\n\n{formatted_emails}",
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                response_schema=BulkEmailAnalysis
            )
        )

        if not response.text:
            raise Exception("Gemini returned an empty bulk response.")

        # Validate with Pydantic
        bulk_data = BulkEmailAnalysis.model_validate_json(response.text)
        
        # Convert to dictionary mapping id -> item
        result_dict = {item.id: item for item in bulk_data.analyses}
        return result_dict

    except Exception as e:
        raise Exception(f"Bulk Gemini analysis failed: {str(e)}")
