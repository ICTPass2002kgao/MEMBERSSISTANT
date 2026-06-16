"use client";

import React, { useState, useEffect } from 'react';
import { 
  Send, AlertCircle, CheckCircle2, Loader2, Users, Radio, History, 
  GraduationCap, ShieldHalf, ShieldCheck, Wrench, Briefcase, 
  Search, User, X, Check
} from 'lucide-react';
import { apiFetch } from '../../components/api';

export default function CommunicationsCommandCenter() {
    // Mode State: 'broadcast' or 'direct'
    const [sendMode, setSendMode] = useState<'broadcast' | 'direct'>('broadcast');
    
    const [title, setTitle] = useState('');
    const [message, setMessage] = useState('');
    const [targetAudience, setTargetAudience] = useState('all'); 
    
    // Direct Selection States
    const [directory, setDirectory] = useState<any[]>([]);
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedIds, setSelectedIds] = useState<string[]>([]);
    
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [successMessage, setSuccessMessage] = useState<string | null>(null);
    
    const [history, setHistory] = useState<any[]>([]);
    const [historyLoading, setHistoryLoading] = useState(true);

    useEffect(() => {
        fetchHistory();
        fetchDirectory();
    }, []);

    const fetchDirectory = async () => {
        try {
            const [stdData, attData] = await Promise.all([
                apiFetch('/students/'),
                apiFetch('/attendants/')
            ]);

            const students = (stdData.results || stdData || []).map((s: any) => ({ ...s, type: 'student' }));
            const attendants = (attData.results || attData || []).map((a: any) => ({ ...a, type: 'staff' }));

            setDirectory([...students, ...attendants]);
        } catch (err) {
            console.error("Failed to build directory", err);
        }
    };

    const fetchHistory = async () => {
        try {
            const data = await apiFetch('/notifications/');
            const results = Array.isArray(data) ? data : (data.results || []);
            // Sort by newest first
            results.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
            setHistory(results);
        } catch (err) { 
            console.error(err); 
        } finally { 
            setHistoryLoading(false); 
        }
    };

    const handleToggleId = (id: string) => {
        setSelectedIds(prev => 
            prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
        );
    };

    const handleSend = async (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        setError(null);
        setLoading(true);

        try {
            const payload = {
                title,
                message,
                send_mode: sendMode,
                target_audience: sendMode === 'broadcast' ? targetAudience : 'personal', // 'personal' fixes the DB IntegrityError
                recipient_ids: sendMode === 'direct' ? selectedIds : null
            };

            if (sendMode === 'direct' && selectedIds.length === 0) {
                throw new Error("Please select at least one recipient from the directory.");
            }

            await apiFetch('/send-communication/', {
                method: 'POST',
                body: JSON.stringify(payload),
            });

            setSuccessMessage(`Transmission Successful: Sent to ${sendMode === 'broadcast' ? targetAudience : selectedIds.length + ' individuals'}.`);
            setTitle(''); setMessage(''); setSelectedIds([]);
            fetchHistory();
            setTimeout(() => setSuccessMessage(null), 5000);
        } catch (err: any) {
            setError(err.message || 'Dispatch failed.');
        } finally {
            setLoading(false);
        }
    };

    const filteredDirectory = directory.filter(user => 
        `${user.name} ${user.surname}`.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (user.student_number && user.student_number.includes(searchQuery))
    );

    const renderAudienceBadge = (audience: string) => {
        // 'personal' is the internal tag for direct select messages
        if (audience === 'personal') return <span className="inline-flex items-center gap-1 px-2 py-1 rounded-md bg-rose-50 text-rose-600 text-[10px] font-bold uppercase tracking-wider border border-rose-100">Direct Message</span>;
        
        switch (audience) {
            case 'students': return <span className="inline-flex items-center gap-1 px-2 py-1 rounded-md bg-blue-50 text-blue-600 text-[10px] font-bold uppercase border border-blue-100"><GraduationCap size={12}/> Students</span>;
            case 'attendants': return <span className="inline-flex items-center gap-1 px-2 py-1 rounded-md bg-purple-50 text-purple-600 text-[10px] font-bold uppercase border border-purple-100"><ShieldHalf size={12}/> Staff</span>;
            default: return <span className="inline-flex items-center gap-1 px-2 py-1 rounded-md bg-emerald-50 text-emerald-600 text-[10px] font-bold uppercase border border-emerald-100"><Users size={12}/> Broadcast</span>;
        }
    };

    return (
        <div className="min-h-screen bg-slate-50 p-4 sm:p-8 font-sans animate-in fade-in duration-500">
            <div className="w-full max-w-7xl mx-auto space-y-8">
                
                {/* Dashboard Header */}
                <div className="bg-white p-8 rounded-[32px] border border-slate-100 shadow-sm flex items-center justify-between">
                    <div>
                        <h4 className="text-[11px] font-black tracking-[0.2em] text-blue-600 uppercase mb-1.5">Dispatch Infrastructure</h4>
                        <h2 className="text-3xl font-black text-slate-900 tracking-tight">Command Center</h2>
                    </div>
                    <div className="p-4 bg-blue-50 rounded-2xl border border-blue-100 hidden sm:block">
                        <Radio size={32} className="text-blue-600" />
                    </div>
                </div>

                <div className="grid grid-cols-1 xl:grid-cols-4 gap-8">
                    
                    {/* LEFT COLUMN: Recipient Directory */}
                    <div className={`xl:col-span-1 space-y-4 transition-all duration-300 ${sendMode === 'broadcast' ? 'opacity-40 pointer-events-none grayscale' : 'opacity-100'}`}>
                        <div className="bg-white p-6 rounded-[32px] border border-slate-100 shadow-sm h-[700px] flex flex-col">
                            <h3 className="font-bold text-slate-900 mb-4 flex items-center gap-2">
                                <Users size={18} className="text-blue-600" /> System Directory
                            </h3>
                            
                            <div className="relative mb-4">
                                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                                <input 
                                    type="text" 
                                    placeholder="Search name or ID..." 
                                    className="w-full pl-9 pr-4 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-400 transition-all font-medium"
                                    value={searchQuery}
                                    onChange={(e) => setSearchQuery(e.target.value)}
                                />
                            </div>

                            <div className="flex-1 overflow-y-auto space-y-2 pr-1 custom-scrollbar">
                                {filteredDirectory.map((user) => (
                                    <div 
                                        key={user.firebase_uid || user.id}
                                        onClick={() => handleToggleId(user.firebase_uid || user.id)}
                                        className={`p-3 rounded-2xl border transition-all cursor-pointer flex items-center justify-between group ${
                                            selectedIds.includes(user.firebase_uid || user.id) 
                                            ? 'bg-blue-600 border-blue-600 text-white shadow-md' 
                                            : 'bg-slate-50 border-slate-100 text-slate-700 hover:border-blue-300'
                                        }`}
                                    >
                                        <div className="flex items-center gap-3">
                                            <div className={`p-2 rounded-lg ${selectedIds.includes(user.firebase_uid || user.id) ? 'bg-white/20' : 'bg-white border border-slate-100'}`}>
                                                {user.type === 'student' ? <GraduationCap size={14}/> : <ShieldCheck size={14}/>}
                                            </div>
                                            <div>
                                                <p className="text-[11px] font-bold leading-none">{user.name} {user.surname}</p>
                                                <p className={`text-[9px] mt-1 font-medium ${selectedIds.includes(user.firebase_uid || user.id) ? 'text-blue-100' : 'text-slate-400'}`}>
                                                    {user.type === 'student' ? `ID: ${user.student_number}` : 'Staff Member'}
                                                </p>
                                            </div>
                                        </div>
                                        {selectedIds.includes(user.firebase_uid || user.id) && <Check size={14} />}
                                    </div>
                                ))}
                            </div>

                            <div className="pt-4 border-t border-slate-100 mt-4">
                                <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest text-center">
                                    {selectedIds.length} Targeted Recipients
                                </p>
                            </div>
                        </div>
                    </div>

                    {/* CENTER COLUMN: Transmission Terminal */}
                    <div className="xl:col-span-2 bg-white p-8 sm:p-10 rounded-[32px] border border-slate-100 shadow-sm h-fit">
                        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8 border-b border-slate-100 pb-6">
                            <div className="flex items-center gap-2">
                                <Send className="w-5 h-5 text-blue-600" />
                                <h3 className="text-lg font-bold text-slate-900 tracking-tight">New Transmission</h3>
                            </div>

                            <div className="flex p-1 bg-slate-100 rounded-xl w-fit">
                                <button 
                                    onClick={() => setSendMode('broadcast')}
                                    className={`px-4 py-2 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all ${sendMode === 'broadcast' ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
                                >
                                    Broadcast
                                </button>
                                <button 
                                    onClick={() => setSendMode('direct')}
                                    className={`px-4 py-2 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all ${sendMode === 'direct' ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
                                >
                                    Direct Select
                                </button>
                            </div>
                        </div>

                        {error && <div className="w-full bg-rose-50 border border-rose-200 text-rose-600 px-5 py-4 rounded-xl mb-8 text-xs font-bold flex items-center gap-3 animate-in shake-in"><AlertCircle size={20} />{error}</div>}
                        {successMessage && <div className="w-full bg-emerald-50 border border-emerald-200 text-emerald-600 px-5 py-4 rounded-xl mb-8 text-xs font-bold flex items-center gap-3"><CheckCircle2 size={20} />{successMessage}</div>}

                        <form className="w-full space-y-6" onSubmit={handleSend}>
                            
                            {sendMode === 'broadcast' ? (
                                <div className="space-y-2 animate-in fade-in duration-300">
                                    <label className="text-[11px] font-bold text-slate-500 uppercase tracking-widest pl-1">Audience Preset</label>
                                    <select 
                                        value={targetAudience}
                                        onChange={(e) => setTargetAudience(e.target.value)}
                                        className="w-full px-5 py-4 bg-slate-50 text-slate-900 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 transition-all text-sm font-bold appearance-none cursor-pointer"
                                    >
                                        <option value="all">🌐 Broadcast to All (Students & Staff)</option>
                                        <option value="students">🎓 All Students Only</option>
                                        <option value="attendants">🛡️ All Staff Members Only</option>
                                    </select>
                                </div>
                            ) : (
                                <div className="p-4 bg-blue-50 border border-blue-100 rounded-2xl animate-in slide-in-from-top-2 duration-300">
                                    <p className="text-[11px] text-blue-700 font-bold mb-3 flex items-center gap-2">
                                        <Users size={14} /> Selected Recipients ({selectedIds.length})
                                    </p>
                                    <div className="flex flex-wrap gap-2 max-h-32 overflow-y-auto pr-2 custom-scrollbar">
                                        {selectedIds.length === 0 && <p className="text-[10px] text-blue-400 italic">Please select individuals from the directory...</p>}
                                        {selectedIds.map(id => {
                                            const user = directory.find(u => (u.firebase_uid || u.id) === id);
                                            return (
                                                <div key={id} className="flex items-center gap-1.5 px-2.5 py-1.5 bg-white border border-blue-200 rounded-lg text-[10px] font-bold text-blue-600 shadow-sm">
                                                    {user?.name} <X size={10} className="cursor-pointer hover:text-rose-500" onClick={() => handleToggleId(id)} />
                                                </div>
                                            );
                                        })}
                                    </div>
                                </div>
                            )}

                            <div className="space-y-2">
                                <label className="text-[11px] font-bold text-slate-500 uppercase tracking-widest pl-1">Subject Header</label>
                                <input type="text" required value={title} onChange={(e) => setTitle(e.target.value)} className="w-full px-5 py-4 bg-slate-50 text-slate-900 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 transition-all text-sm font-medium" placeholder="e.g., Water Maintenance Update" />
                            </div>

                            <div className="space-y-2">
                                <label className="text-[11px] font-bold text-slate-500 uppercase tracking-widest pl-1">Communication Content</label>
                                <textarea required value={message} onChange={(e) => setMessage(e.target.value)} rows={6} className="w-full px-5 py-4 bg-slate-50 text-slate-900 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 transition-all text-sm resize-none font-medium leading-relaxed" placeholder="Type your detailed message here..."></textarea>
                            </div>

                            <button type="submit" disabled={loading} className="w-full h-14 rounded-xl text-white font-bold tracking-[0.15em] text-xs transition-all disabled:opacity-70 flex items-center justify-center bg-blue-600 hover:bg-blue-700 shadow-lg shadow-blue-500/20 active:scale-[0.98]">
                                {loading ? <Loader2 className="animate-spin w-4 h-4" /> : <><Send className="w-4 h-4 mr-2" /> DISPATCH TO NETWORK</>}
                            </button>
                        </form>
                    </div>

                    {/* RIGHT COLUMN: Transmission Log */}
                    <div className="xl:col-span-1 space-y-6">
                        <div className="bg-white p-6 sm:p-8 rounded-[32px] border border-slate-100 shadow-sm h-[800px] flex flex-col">
                            <h4 className="text-[11px] font-black tracking-[0.2em] text-blue-600 uppercase mb-6 flex items-center gap-2 flex-shrink-0">
                                <History className="w-4 h-4" /> Message History
                            </h4>
                            
                            <div className="overflow-y-auto pr-2 space-y-4 flex-grow custom-scrollbar">
                                {historyLoading ? (
                                    <div className="flex justify-center py-10"><Loader2 className="animate-spin text-slate-300" /></div>
                                ) : history.length === 0 ? (
                                    <p className="text-center text-slate-400 text-sm py-10 font-medium">No previous logs.</p>
                                ) : (
                                    history.map((item, idx) => (
                                        <div key={idx} className="p-4 rounded-2xl bg-slate-50 border border-slate-100 hover:border-blue-200 transition-colors">
                                            <div className="flex flex-col gap-2 mb-3 border-b border-slate-200 pb-3">
                                                <h5 className="font-bold text-slate-900 text-sm">{item.title}</h5>
                                                <div>{renderAudienceBadge(item.target_audience)}</div>
                                            </div>
                                            <p className="text-xs text-slate-600 mb-3 leading-relaxed">"{item.message}"</p>
                                            <p className="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                                                {new Date(item.created_at).toLocaleDateString()} • {new Date(item.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                                            </p>
                                        </div>
                                    ))
                                )}
                            </div>
                        </div>
                    </div>

                </div>
            </div>
        </div>
    );
}