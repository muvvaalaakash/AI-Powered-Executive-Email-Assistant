import React, { useState, useEffect } from 'react';

export default function AIInsights({ insights, isLoading }) {
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    setCopied(false);
  }, [insights]);

  const handleCopy = () => {
    if (insights?.reply) {
      navigator.clipboard.writeText(insights.reply);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center h-full p-8 space-y-4">
        {/* Elegant loading ring */}
        <div className="relative inline-flex h-10 w-10">
          <div className="absolute inset-0 rounded-full border-4 border-indigo-500/10"></div>
          <div className="absolute inset-0 rounded-full border-4 border-indigo-500 border-t-transparent animate-spin"></div>
        </div>
        <p className="text-xs text-slate-400 font-medium">AI is generating summaries & drafts...</p>
      </div>
    );
  }

  if (!insights) {
    return (
      <div className="flex flex-col items-center justify-center h-full p-8 text-center space-y-3">
        <div className="h-10 w-10 rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center text-slate-500 mb-1">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
            <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
          </svg>
        </div>
        <p className="text-xs font-semibold text-slate-300">Select an email to view AI Insights</p>
        <p className="text-[11px] text-slate-600 max-w-[200px] leading-relaxed">
          The assistant will automatically extract summary points, detect email priority, and suggest a professional draft reply.
        </p>
      </div>
    );
  }

  const { summary, priority, reply } = insights;

  return (
    <div className="h-full flex flex-col p-6 space-y-6 overflow-y-auto">
      {/* Title */}
      <div className="border-b border-slate-800/60 pb-3 flex items-center space-x-2">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 text-indigo-400">
          <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
        </svg>
        <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400">AI Analysis & Suggestions</h3>
      </div>

      {/* Priority */}
      <div className="space-y-1.5">
        <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Priority Classification</span>
        <div>
          <span
            className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold tracking-wide uppercase ${
              priority === 'High'
                ? 'bg-red-500/10 text-red-400 border border-red-500/20'
                : priority === 'Medium'
                ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                : 'bg-slate-800 text-slate-400 border border-slate-700/50'
            }`}
          >
            {priority}
          </span>
        </div>
      </div>

      {/* Summary */}
      <div className="space-y-1.5">
        <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Executive Summary</span>
        <div className="p-3.5 rounded-lg border border-slate-800 bg-slate-950/30 text-xs text-slate-300 leading-relaxed font-medium">
          {summary}
        </div>
      </div>

      {/* Reply suggestion */}
      <div className="space-y-3 flex-1 flex flex-col justify-between">
        <div className="space-y-1.5 flex-1 flex flex-col">
          <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Suggested Reply</span>
          <div className="p-3.5 rounded-lg border border-slate-800 bg-slate-950/50 text-xs text-slate-200 leading-relaxed whitespace-pre-line flex-1 min-h-[140px] font-sans">
            {reply}
          </div>
        </div>

        <button
          onClick={handleCopy}
          className={`w-full py-2.5 rounded-lg text-xs font-bold transition-all duration-200 flex items-center justify-center space-x-2 border cursor-pointer ${
            copied
              ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/15'
              : 'bg-indigo-600 border-indigo-500/50 text-white hover:bg-indigo-500'
          }`}
        >
          {copied ? (
            <>
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-3.5 h-3.5">
                <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
              </svg>
              <span>Copied!</span>
            </>
          ) : (
            <>
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-3.5 h-3.5">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 0 1-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H5.25m10.5 8.25V1.875C15.75 1.254 15.246.75 14.625.75h-9.75c-.621 0-1.125.504-1.125 1.125v15c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125Z" />
              </svg>
              <span>Copy Response</span>
            </>
          )}
        </button>
      </div>
    </div>
  );
}
