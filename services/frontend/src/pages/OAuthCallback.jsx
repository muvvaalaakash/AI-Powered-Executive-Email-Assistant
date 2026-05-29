import React, { useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';

export default function OAuthCallback() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  useEffect(() => {
    const accessToken = searchParams.get('access_token');
    const refreshToken = searchParams.get('refresh_token');
    const email = searchParams.get('email');
    const error = searchParams.get('error');

    if (error) {
      navigate(`/?error=${encodeURIComponent(error)}`);
      return;
    }

    if (accessToken) {
      localStorage.setItem('google_access_token', accessToken);
      if (refreshToken) {
        localStorage.setItem('google_refresh_token', refreshToken);
      }
      if (email) {
        localStorage.setItem('user_email', email);
      }
      navigate('/dashboard');
    } else {
      navigate('/?error=No%20credentials%20received%20from%20Google');
    }
  }, [searchParams, navigate]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-[#0f172a] via-[#090d16] to-[#0f172a] text-white">
      <div className="text-center space-y-4">
        {/* Simple elegant modern loading ring */}
        <div className="relative inline-flex h-10 w-10">
          <div className="absolute inset-0 rounded-full border-4 border-indigo-500/20"></div>
          <div className="absolute inset-0 rounded-full border-4 border-indigo-500 border-t-transparent animate-spin"></div>
        </div>
        <p className="text-sm text-slate-400 font-medium">Securing your session and configuring assistant...</p>
      </div>
    </div>
  );
}
