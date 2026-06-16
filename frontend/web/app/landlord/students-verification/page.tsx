"use client";

import React, { useState, useEffect } from 'react';
import { 
  Loader2, User, AlertTriangle, ShieldAlert, CheckCircle2, 
  Search, Fingerprint, RefreshCcw, X, AlertCircle 
} from 'lucide-react';
import { apiFetch } from '../../components/api';
import { SectionHeader } from '../../components/SharedUI';

export default function StudentsVerification() {
    const [unverifiedStudents, setUnverifiedStudents] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState("");
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isProcessingBulk, setIsProcessingBulk] = useState(false);

    const fetchUnverifiedStudents = async () => {
        setLoading(true);
        try {
            const data = await apiFetch('/students/');
            const allStudents = data.results || data || [];
            
            // STRICT FILTER: Only show students who actually have a ROOM assigned
            // and currently have a false verification status.
            const pending = allStudents.filter((s: any) => s.room !== null && s.verification_status === false);
            setUnverifiedStudents(pending);
        } catch (error) { 
            console.error("Queue fetch error:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    const handleBulkReset = async () => {
        setIsProcessingBulk(true);
        try {
            const data = await apiFetch('/students/');
            const allStudents = data.results || data || [];
            
            // STRICT FILTER: We only want to trigger a new cycle for ACTUAL RESIDENTS.
            // We must NOT reset the status of pending applicants who don't have a room yet.
            const validResidents = allStudents.filter((s: any) => s.room !== null);
            
            // Execute all updates in parallel
            await Promise.all(validResidents.map((s: any) => 
                apiFetch(`/students/${s.id}/`, {
                    method: 'PATCH',
                    body: JSON.stringify({ verification_status: false })
                })
            ));
            
            await fetchUnverifiedStudents();
            setIsModalOpen(false); // Close modal on success
        } catch (error) {
            console.error("Bulk reset failed:", error);
        } finally {
            setIsProcessingBulk(false);
        }
    };

    useEffect(() => { fetchUnverifiedStudents(); }, []);

    const filteredStudents = unverifiedStudents.filter(s => 
        `${s.name} ${s.surname}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
        s.student_number.includes(searchTerm)
    );

    return (
        <div className="relative space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
            {/* --- CUSTOM MODAL OVERLAY --- */}
            {isModalOpen && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 backdrop-blur-md bg-blue-950/20 animate-in fade-in duration-300">
                    <div className="bg-white w-full max-w-md rounded-[32px] shadow-2xl shadow-blue-950/20 border border-white p-8 animate-in zoom-in-95 duration-300">
                        <div className="flex flex-col items-center text-center">
                            <div className="w-20 h-20 bg-rose-50 rounded-full flex items-center justify-center mb-6 ring-8 ring-rose-50/50">
                                <AlertCircle className="text-rose-500" size={40} />
                            </div>
                            
                            <h3 className="text-2xl font-black text-blue-950 tracking-tight">Reset Verification?</h3>
                            <p className="text-slate-500 text-sm mt-3 leading-relaxed">
                                You are about to mark <b>all assigned residents</b> as unverified. This will repopulate the queue for a new physical occupancy check.
                            </p>

                            <div className="grid grid-cols-2 gap-3 w-full mt-10">
                                <button 
                                    onClick={() => setIsModalOpen(false)}
                                    disabled={isProcessingBulk}
                                    className="py-4 rounded-2xl bg-slate-100 text-slate-600 font-black text-[11px] uppercase tracking-widest hover:bg-slate-200 transition-all disabled:opacity-50"
                                >
                                    Cancel
                                </button>
                                <button 
                                    onClick={handleBulkReset}
                                    disabled={isProcessingBulk}
                                    className="py-4 rounded-2xl bg-rose-500 text-white font-black text-[11px] uppercase tracking-widest shadow-lg shadow-rose-500/30 hover:bg-rose-600 transition-all flex items-center justify-center gap-2 disabled:bg-rose-300"
                                >
                                    {isProcessingBulk ? (
                                        <Loader2 size={16} className="animate-spin" />
                                    ) : (
                                        "Yes, Reset All"
                                    )}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* --- TOP BAR --- */}
            <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4 mb-8">
                <div>
                    <SectionHeader title="Verification Hub" />
                    <p className="text-slate-400 text-[11px] font-bold uppercase tracking-[0.2em] mt-1">Live Occupancy Management</p>
                </div>
                
                <div className="flex flex-wrap items-center gap-4 w-full lg:w-auto">
                    <div className="relative flex-1 lg:w-80">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300" size={18} />
                        <input 
                            type="text" 
                            placeholder="Quick lookup resident..." 
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full bg-white border border-blue-100 pl-12 pr-4 py-3 rounded-2xl text-sm outline-none focus:border-blue-400 focus:ring-4 focus:ring-blue-500/5 transition-all shadow-sm"
                        />
                    </div>

                    <button 
                        onClick={() => setIsModalOpen(true)}
                        className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-2xl text-[11px] font-black uppercase tracking-[0.15em] transition-all shadow-lg shadow-blue-600/20 active:scale-95"
                    >
                        <RefreshCcw size={16} />
                        Trigger New Cycle
                    </button>
                </div>
            </div>

            {/* --- DATA TABLE --- */}
            <div className="bg-white border border-blue-100 rounded-[32px] overflow-hidden shadow-[0_8px_30px_rgb(239,246,255,0.5)] flex flex-col">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1000px]">
                        <thead className="bg-blue-50/50 border-b border-blue-100 text-blue-400 text-[10px] uppercase tracking-[0.2em] whitespace-nowrap">
                            <tr>
                                <th className="py-6 px-8 font-black w-12 text-center">Identity</th>
                                <th className="py-6 px-8 font-black">Resident Profile</th>
                                <th className="py-6 px-8 font-black">Location</th>
                                <th className="py-6 px-8 font-black text-center">Status</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-blue-50 text-sm">
                            {loading ? (
                                <tr><td colSpan={4} className="py-32 text-center"><Loader2 className="animate-spin mx-auto text-blue-500" size={40} /></td></tr>
                            ) : filteredStudents.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="py-32 text-center">
                                        <CheckCircle2 size={56} className="mx-auto text-emerald-300 mb-6 opacity-40" />
                                        <p className="text-blue-950 font-black text-2xl tracking-tight">Queue Synchronized</p>
                                        <p className="text-slate-400 text-sm mt-2">All residents are physically verified.</p>
                                    </td>
                                </tr>
                            ) : (
                                filteredStudents.map((s: any) => (
                                    <tr key={s.id} className="hover:bg-blue-50/30 transition-all group">
                                        <td className="py-5 px-8">
                                            <div className="relative w-14 h-14 mx-auto">
                                                <img 
                                                    src={s.face_url || 'https://via.placeholder.com/150'} 
                                                    className="w-full h-full rounded-2xl object-cover border-2 border-white shadow-md ring-1 ring-blue-100" 
                                                    alt="p" 
                                                />
                                            </div>
                                        </td>
                                        <td className="py-5 px-8">
                                            <div className="font-black text-blue-950 text-base leading-none">{s.name} {s.surname}</div>
                                            <div className="text-[10px] text-blue-400 font-bold uppercase mt-2 tracking-widest">{s.student_number} | {s.accommodation_name}</div>
                                        </td>
                                        <td className="py-5 px-8">
                                            <div className="flex items-center gap-2">
                                                <span className="text-[10px] font-black text-slate-400 bg-slate-100 px-3 py-1.5 rounded-lg uppercase tracking-wider">
                                                    {s.block_name || 'BLOCK SS'}
                                                </span>
                                                <span className="text-[10px] font-black text-blue-600 bg-blue-100 px-3 py-1.5 rounded-lg uppercase tracking-wider">
                                                    ROOM: {s.room_number_only || '00'}
                                                </span>
                                            </div>
                                        </td>
                                        <td className="py-5 px-8 text-center">
                                            <div className="inline-flex items-center gap-2 bg-rose-50 text-rose-500 border border-rose-100 px-4 py-2.5 rounded-2xl text-[10px] font-black uppercase tracking-widest">
                                                <Fingerprint size={14} className="animate-pulse" />
                                                Unverified
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}