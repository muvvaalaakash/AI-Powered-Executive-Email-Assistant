import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import API from '../services/api';
import Sidebar from '../components/Sidebar';
import Header from '../components/Header';
import EmailCard from '../components/EmailCard';
import AIInsights from '../components/AIInsights';

export default function Dashboard() {
  const navigate = useNavigate();
  const [emails, setEmails] = useState([]);
  const [selectedEmail, setSelectedEmail] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // Cache for storing AI insights by email ID: { [emailId]: { summary, priority, reply } }
  const [aiInsightsCache, setAiInsightsCache] = useState({});
  const [aiLoading, setAiLoading] = useState(false);

  const fetchEmails = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await API.get('/emails/unread');
      const fetchedEmails = response.data || [];

      // Pre-populate the AI insights cache from the fetched emails' bulk analyses
      const prePopulatedCache = {};
      fetchedEmails.forEach(email => {
        if (email.ai_analysis) {
          prePopulatedCache[email.id] = email.ai_analysis;
        }
      });
      setAiInsightsCache(prePopulatedCache);

      setEmails(fetchedEmails);
      
      // Select the first email automatically if emails exist and none is selected
      if (fetchedEmails.length > 0) {
        setSelectedEmail(fetchedEmails[0]);
      } else {
        setSelectedEmail(null);
      }
    } catch (err) {
      console.error('Error fetching emails:', err);
      const errMsg = err.response?.data?.detail || err.message || 'Please try again or re-authenticate.';
      setError(`Failed to fetch unread emails: ${errMsg}`);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    const token = localStorage.getItem('google_access_token');
    if (!token) {
      navigate('/');
    } else {
      fetchEmails();
    }
  }, [navigate]);

  // Trigger AI processing for the selected email on selection
  useEffect(() => {
    if (!selectedEmail) return;

    const emailId = selectedEmail.id;
    // If we already have AI insights cached for this email, do not fetch again
    if (aiInsightsCache[emailId]) return;

    const processEmailWithAI = async () => {
      setAiLoading(true);
      try {
        // Send email body (or snippet if body is empty) to AI endpoint
        const contentToProcess = selectedEmail.body || selectedEmail.snippet || selectedEmail.subject;
        const response = await API.post('/ai/process', {
          email_content: contentToProcess
        });

        // Store the result in cache
        setAiInsightsCache(prev => ({
          ...prev,
          [emailId]: response.data
        }));
      } catch (err) {
        console.error('Error processing email with AI:', err);
        const errMsg = err.response?.data?.detail || err.message || 'Unknown error.';
        // Store an error state in cache to prevent endless retries
        setAiInsightsCache(prev => ({
          ...prev,
          [emailId]: {
            summary: "AI could not process this email.",
            priority: "Low",
            reply: `Failed to generate suggested response: ${errMsg}`
          }
        }));
      } finally {
        setAiLoading(false);
      }
    };

    processEmailWithAI();
  }, [selectedEmail, aiInsightsCache]);

  return (
    <div className="flex h-screen bg-[#080b11] overflow-hidden text-slate-100 font-sans">
      {/* Sidebar navigation */}
      <Sidebar />

      {/* Main content frame */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Header toolbar */}
        <Header onRefresh={fetchEmails} isLoading={isLoading} />

        {/* Dynamic content split panel */}
        <div className="flex-1 flex min-h-0">
          
          {/* LEFT PANEL: Email List */}
          <div className="w-[360px] border-r border-slate-800/60 bg-[#090d16]/30 flex flex-col min-h-0">
            {isLoading ? (
              <div className="flex-1 flex flex-col items-center justify-center space-y-3">
                <div className="h-7 w-7 rounded-full border-2 border-indigo-500/20 border-t-indigo-500 animate-spin"></div>
                <span className="text-xs text-slate-500 font-medium">Fetching emails...</span>
              </div>
            ) : error ? (
              <div className="p-6 text-center space-y-3">
                <p className="text-xs text-red-400 font-medium">{error}</p>
                <button
                  onClick={fetchEmails}
                  className="px-3.5 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-xs font-bold text-white transition-colors cursor-pointer"
                >
                  Retry Connection
                </button>
              </div>
            ) : emails.length === 0 ? (
              <div className="flex-1 flex flex-col items-center justify-center p-6 text-center space-y-2">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-8 h-8 text-slate-600">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 0 1-1.043 3.296 3.745 3.745 0 0 1-3.296 1.043A3.745 3.745 0 0 1 12 21c-1.268 0-2.39-.63-3.068-1.593a3.746 3.746 0 0 1-3.296-1.043 3.745 3.745 0 0 1-1.043-3.296A3.745 3.745 0 0 1 3 12c0-1.268.63-2.39 1.593-3.068a3.745 3.745 0 0 1 1.043-3.296 3.746 3.746 0 0 1 3.296-1.043A3.746 3.746 0 0 1 12 3c1.268 0 2.39.63 3.068 1.593a3.746 3.746 0 0 1 3.296 1.043 3.746 3.746 0 0 1 1.043 3.296A3.745 3.745 0 0 1 21 12Z" />
                </svg>
                <p className="text-xs font-semibold text-slate-400">All caught up!</p>
                <p className="text-[10px] text-slate-600">No unread emails found in your inbox.</p>
              </div>
            ) : (
              <div className="flex-1 overflow-y-auto divide-y divide-slate-800/20">
                {emails.map(email => (
                  <EmailCard
                    key={email.id}
                    email={email}
                    isSelected={selectedEmail?.id === email.id}
                    onClick={() => setSelectedEmail(email)}
                    aiInsights={aiInsightsCache[email.id]}
                  />
                ))}
              </div>
            )}
          </div>

          {/* RIGHT PANEL: Email Details & AI Insights */}
          <div className="flex-1 flex min-w-0">
            {selectedEmail ? (
              <>
                {/* Center Column: Email Details */}
                <div className="flex-1 flex flex-col min-w-0 border-r border-slate-800/60 bg-[#0b0f19]/25">
                  {/* Sender Details Header */}
                  <div className="p-6 border-b border-slate-800/60 space-y-3">
                    <div className="flex justify-between items-start">
                      <h1 className="text-base font-bold text-white leading-snug">
                        {selectedEmail.subject}
                      </h1>
                      <span className="text-[11px] text-slate-500 font-medium">
                        {new Date(selectedEmail.date).toLocaleString()}
                      </span>
                    </div>
                    <div className="flex items-center space-x-2">
                      <span className="text-xs text-slate-400 font-semibold">From:</span>
                      <span className="text-xs text-slate-300 truncate">{selectedEmail.sender}</span>
                    </div>
                  </div>

                  {/* Scrollable Email Body */}
                  <div className="flex-1 p-6 overflow-y-auto">
                    {selectedEmail.body ? (
                      <pre className="whitespace-pre-wrap font-sans text-xs text-slate-300 leading-relaxed">
                        {selectedEmail.body}
                      </pre>
                    ) : (
                      <p className="text-xs text-slate-500 italic">No email body content available.</p>
                    )}
                  </div>
                </div>

                {/* Right Column: AI Insights Pane */}
                <div className="w-[360px] bg-[#090d16]/40 backdrop-blur-md">
                  <AIInsights
                    insights={aiInsightsCache[selectedEmail.id]}
                    isLoading={aiLoading}
                  />
                </div>
              </>
            ) : (
              <div className="flex-1 flex flex-col items-center justify-center text-center p-8 space-y-2">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1} stroke="currentColor" className="w-10 h-10 text-slate-700 animate-bounce">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 9v.906a2.25 2.25 0 0 1-1.183 1.981l-6.478 3.488M2.25 9v.906a2.25 2.25 0 0 0 1.183 1.981l6.478 3.488m8.839 2.51-4.66-2.51m0 0-1.023-.55a2.25 2.25 0 0 0-2.134 0l-1.022.55m0 0-4.661 2.51m16.5 1.615V6.75A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25v10.5a2.25 2.25 0 0 0 2.25 2.25h15a2.25 2.25 0 0 0 2.25-2.25Z" />
                </svg>
                <p className="text-sm font-semibold text-slate-400">Select an email to read details</p>
                <p className="text-xs text-slate-600">Choose any item from the inbox column to start analysis.</p>
              </div>
            )}
          </div>

        </div>
      </div>
    </div>
  );
}
