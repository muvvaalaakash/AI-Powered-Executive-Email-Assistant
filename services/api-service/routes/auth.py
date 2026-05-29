from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
import urllib.parse
import httpx
from config.settings import settings

router = APIRouter()

class TokenRefreshRequest(BaseModel):
    refresh_token: str

@router.get("/login")
def login():
    """
    Redirects the user to the Google OAuth2 consent screen.
    """
    if not settings.GOOGLE_CLIENT_ID or not settings.GOOGLE_CLIENT_SECRET:
        raise HTTPException(
            status_code=500,
            detail="Google OAuth credentials (GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET) are not configured on the server."
        )

    params = {
        "client_id": settings.GOOGLE_CLIENT_ID,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "response_type": "code",
        "scope": "openid email profile https://www.googleapis.com/auth/gmail.readonly",
        "access_type": "offline",
        "prompt": "consent",  # Ensures a refresh token is returned on each authentication
    }
    
    url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(params)
    return RedirectResponse(url)

@router.get("/callback")
async def callback(code: str = None, error: str = None):
    """
    Handles the redirect callback from Google OAuth.
    Exchanges the authorization code for tokens and redirects to the frontend dashboard callback.
    """
    if error:
        return RedirectResponse(f"{settings.FRONTEND_URL}/oauth-callback?error={urllib.parse.quote(error)}")

    if not code:
        raise HTTPException(status_code=400, detail="Missing authorization code")

    # Exchange authorization code for tokens
    token_url = "https://oauth2.googleapis.com/token"
    data = {
        "client_id": settings.GOOGLE_CLIENT_ID,
        "client_secret": settings.GOOGLE_CLIENT_SECRET,
        "code": code,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "grant_type": "authorization_code",
    }

    async with httpx.AsyncClient() as client:
        try:
            token_response = await client.post(token_url, data=data)
            token_data = token_response.json()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to connect to Google OAuth server: {str(e)}")

    if token_response.status_code != 200:
        error_description = token_data.get("error_description", "OAuth authorization code exchange failed.")
        return RedirectResponse(
            f"{settings.FRONTEND_URL}/oauth-callback?error={urllib.parse.quote(error_description)}"
        )

    access_token = token_data.get("access_token")
    refresh_token = token_data.get("refresh_token", "")  # May be empty if access_type was not offline or prompt not consent
    
    # Retrieve user profile (specifically email) using the access token
    email = ""
    async with httpx.AsyncClient() as client:
        try:
            userinfo_response = await client.get(
                "https://www.googleapis.com/oauth2/v3/userinfo",
                headers={"Authorization": f"Bearer {access_token}"}
            )
            if userinfo_response.status_code == 200:
                user_info = userinfo_response.json()
                email = user_info.get("email", "")
        except Exception:
            # Make user email fetching non-blocking to prevent full login failure
            pass

    # Redirect user to frontend with tokens
    redirect_url = (
        f"{settings.FRONTEND_URL}/oauth-callback?"
        f"access_token={access_token}&"
        f"refresh_token={refresh_token}&"
        f"email={email}"
    )
    return RedirectResponse(redirect_url)

@router.post("/refresh")
async def refresh_token(payload: TokenRefreshRequest):
    """
    Exchanges a refresh token for a new access token when it expires.
    """
    token_url = "https://oauth2.googleapis.com/token"
    data = {
        "client_id": settings.GOOGLE_CLIENT_ID,
        "client_secret": settings.GOOGLE_CLIENT_SECRET,
        "refresh_token": payload.refresh_token,
        "grant_type": "refresh_token",
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(token_url, data=data)
            response_data = response.json()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to connect to Google token server: {str(e)}")

    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail=response_data.get("error_description", "Failed to refresh OAuth token")
        )

    return {
        "access_token": response_data.get("access_token"),
        "expires_in": response_data.get("expires_in"),
    }
