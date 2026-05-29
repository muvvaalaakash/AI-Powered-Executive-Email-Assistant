import React from 'react';

export default function EmailCard({ email, isSelected, onClick, aiInsights }) {
  // Extract user-friendly sender name, stripping raw email addresses
  const getCleanSender = (fromStr) => {
    if (!fromStr) return 'Unknown';
    // Matches "Name <email@domain.com>" or just name
    const match = fromStr.match(/^"?(.*?)"?\s*<.*>$/);
    return match ? match[1] : fromStr;
  };

  // Human-readable relative or short date formatting
  const formatEmailDate = (dateStr) => {
    try {
      const date = new Date(dateStr);
      const now = new Date();
      if (date.toDateString() === now.toDateString()) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      }
      return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
    } catch {
      return dateStr;
    }
  };

  const priority = aiInsights?.priority;

  return (
    <div
      onClick={onClick}
      className={`p-4 border-b border-slate-800/40 cursor-pointer transition-all duration-150 ${
        isSelected
          ? 'bg-indigo-600/10 border-l-2 border-l-indigo-500'
          : 'hover:bg-slate-800/30 border-l-2 border-l-transparent'
      }`}
    >
      <div className="flex items-center justify-between mb-1.5">
        <span className={`text-sm font-semibold truncate max-w-[160px] ${
          isSelected ? 'text-indigo-400' : 'text-slate-200'
        }`}>
          {getCleanSender(email.sender)}
        </span>
        <span className="text-[11px] text-slate-500 font-medium">
          {formatEmailDate(email.date)}
        </span>
      </div>

      <div className="text-xs font-semibold text-slate-300 truncate mb-1">
        {email.subject}
      </div>

      <p className="text-xs text-slate-500 line-clamp-2 leading-relaxed">
        {email.snippet || '(No description)'}
      </p>

      {priority && (
        <div className="mt-2.5 flex justify-end">
          <span
            className={`px-2 py-0.5 rounded-full text-[10px] font-bold tracking-wide uppercase ${
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
      )}
    </div>
  );
}
