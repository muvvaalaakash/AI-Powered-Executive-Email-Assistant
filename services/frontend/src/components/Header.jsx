import React from 'react';

export default function Header({ onRefresh, isLoading }) {
  return (
    <header className="h-16 border-b border-slate-800/60 bg-[#090d16]/40 backdrop-blur-xl px-8 flex items-center justify-between z-20">
      <div className="flex items-center space-x-4">
        <h2 className="text-xl font-bold tracking-tight text-white">Executive Inbox</h2>
        <span className="flex items-center space-x-1.5 bg-emerald-500/10 border border-emerald-500/25 px-2 py-0.5 rounded-full text-[11px] font-semibold text-emerald-400 shadow-sm">
          <span className="relative flex h-1.5 w-1.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-emerald-500"></span>
          </span>
          <span>AI Co-Pilot Ready</span>
        </span>
      </div>

      <button
        onClick={onRefresh}
        disabled={isLoading}
        className="flex items-center space-x-2 px-3.5 py-1.5 rounded-lg border border-slate-800 bg-slate-900/50 text-xs font-semibold text-slate-300 hover:bg-slate-800 hover:text-white disabled:opacity-40 transition-all cursor-pointer shadow-inner"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          strokeWidth={2}
          stroke="currentColor"
          className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99" />
        </svg>
        <span>{isLoading ? 'Syncing...' : 'Sync Inbox'}</span>
      </button>
    </header>
  );
}
