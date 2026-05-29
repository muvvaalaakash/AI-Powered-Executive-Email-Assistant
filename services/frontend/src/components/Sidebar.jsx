import React from 'react';
import { useNavigate } from 'react-router-dom';

export default function Sidebar() {
  const navigate = useNavigate();
  const email = localStorage.getItem('user_email') || 'executive@gmail.com';

  const handleLogout = () => {
    localStorage.removeItem('google_access_token');
    localStorage.removeItem('google_refresh_token');
    localStorage.removeItem('user_email');
    navigate('/');
  };

  return (
    <aside className="w-64 border-r border-slate-800/60 bg-[#090d16]/80 backdrop-blur-xl flex flex-col justify-between p-6">
      <div className="space-y-8">
        {/* Brand/Logo */}
        <div className="flex items-center space-x-3">
          <div className="h-9 w-9 rounded-lg bg-indigo-600/15 border border-indigo-500/30 flex items-center justify-center text-indigo-400 shadow-inner">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.59 14.37a6 6 0 0 1-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 0 0 6.16-12.12A14.98 14.98 0 0 0 9.631 8.41m5.96 5.96a14.956 14.956 0 0 1-12.067-.539m12.067.539-1.38-1.38m2.76 0-1.38 1.38M12.085 10.255V8.59m0 8.016v-1.666M8.59 12.085H6.924m8.016 0h-1.666" />
            </svg>
          </div>
          <span className="text-lg font-bold tracking-tight text-white">AeroInbox</span>
        </div>

        {/* Sidebar Nav */}
        <nav className="space-y-1.5">
          <div className="flex items-center space-x-3 px-3 py-2.5 rounded-lg bg-indigo-600/10 border border-indigo-500/20 text-indigo-400 font-medium text-sm transition-all">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" />
            </svg>
            <span>Unread Inbox</span>
          </div>
        </nav>
      </div>

      {/* Account Info and Logout */}
      <div className="border-t border-slate-800/60 pt-6 space-y-4">
        <div className="flex flex-col px-3">
          <span className="text-xs text-slate-500 font-medium uppercase tracking-wider">Connected Account</span>
          <span className="text-sm text-slate-300 truncate font-semibold mt-1" title={email}>{email}</span>
        </div>
        <button
          onClick={handleLogout}
          className="w-full flex items-center space-x-2.5 px-3 py-2 text-sm text-slate-400 hover:text-red-400 rounded-lg hover:bg-red-500/5 hover:border hover:border-red-500/10 transition-all cursor-pointer font-medium"
        >
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15M12 9l-3 3m0 0 3 3m-3-3h12.75" />
          </svg>
          <span>Disconnect</span>
        </button>
      </div>
    </aside>
  );
}
