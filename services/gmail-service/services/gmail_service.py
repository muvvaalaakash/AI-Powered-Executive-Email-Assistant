import base64
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from fastapi import HTTPException

def get_gmail_service(access_token: str):
    """
    Builds and returns the Gmail service client using the provided access token.
    """
    try:
        creds = Credentials(token=access_token)
        return build('gmail', 'v1', credentials=creds)
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail=f"Failed to initialize Gmail client with provided access token: {str(e)}"
        )

def extract_body(payload):
    """
    Recursively decodes the body of a Gmail message, supporting plain text and HTML fallback.
    """
    if not payload:
        return ""
    
    # 1. Simple structure with body data
    body_data = payload.get("body", {}).get("data")
    if body_data:
        try:
            return base64.urlsafe_b64decode(body_data).decode("utf-8", errors="ignore")
        except Exception:
            pass
            
    # 2. Multipart structure
    parts = payload.get("parts", [])
    plain_text = ""
    html_text = ""
    
    for part in parts:
        mime_type = part.get("mimeType", "")
        part_body = part.get("body", {})
        part_data = part_body.get("data")
        
        # Handle nested multipart parts
        if "parts" in part:
            nested = extract_body(part)
            if nested:
                return nested
                
        if part_data:
            try:
                decoded = base64.urlsafe_b64decode(part_data).decode("utf-8", errors="ignore")
                if mime_type == "text/plain":
                    plain_text += decoded
                elif mime_type == "text/html":
                    html_text += decoded
            except Exception:
                pass
                
    return plain_text if plain_text else html_text

async def fetch_unread_emails(access_token: str, max_results: int = 10):
    """
    Fetches unread emails from the authenticated user's Gmail inbox.
    """
    service = get_gmail_service(access_token)
    try:
        # Call Gmail API list messages
        result = service.users().messages().list(
            userId='me',
            q='is:unread',
            maxResults=max_results
        ).execute()
        
        messages = result.get('messages', [])
        email_list = []
        
        for msg in messages:
            msg_id = msg['id']
            # Fetch the complete message object
            detail = service.users().messages().get(
                userId='me',
                id=msg_id,
                format='full'
            ).execute()
            
            payload = detail.get('payload', {})
            headers = payload.get('headers', [])
            
            subject = next((h.get('value') for h in headers if h.get('name', '').lower() == 'subject'), 'No Subject')
            sender = next((h.get('value') for h in headers if h.get('name', '').lower() == 'from'), 'Unknown Sender')
            date = next((h.get('value') for h in headers if h.get('name', '').lower() == 'date'), 'Unknown Date')
            
            body = extract_body(payload)
            snippet = detail.get('snippet', '')
            
            email_list.append({
                "id": msg_id,
                "sender": sender,
                "subject": subject,
                "date": date,
                "snippet": snippet,
                "body": body
            })
            
        return email_list
    except HttpError as error:
        try:
            import json
            error_details = json.loads(error.content.decode('utf-8'))
            message = error_details.get('error', {}).get('message', error.reason)
        except Exception:
            message = error.reason

        if error.resp.status == 401:
            raise HTTPException(
                status_code=401,
                detail="Gmail access token is invalid or expired."
            )
        elif error.resp.status == 403:
            raise HTTPException(
                status_code=403,
                detail=f"Gmail API access forbidden: {message}. Please ensure the Gmail API is enabled in your GCP project and that you granted the necessary permissions during login."
            )
        raise HTTPException(
            status_code=error.resp.status,
            detail=f"Gmail API error: {message}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch emails: {str(e)}"
        )
