"use client";

import React, { useState, useEffect, useMemo } from 'react';
import { 
  Activity, Loader2, Search, X, 
  ShieldAlert, Clock, User, Fingerprint, MapPin
} from 'lucide-react';
import { apiFetch } from '../../components/api'; 
import { SectionHeader } from '../../components/SharedUI'; 

export default function EmergencyLogsPage() {
    const [logs, setLogs] = useState<any[]>([]);
    const [respondersMap, setRespondersMap] = useState<Record<string, string>>({});
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState("");

    const fetchData = async () => {
        setLoading(true);
        try {
            // 1. Fetch Responders to map UID to exact names
            const respondersRes = await apiFetch(`/medical-responders/`);
            const respondersList = respondersRes.results || respondersRes || [];
            
            const newRespondersMap: Record<string, string> = {};
            respondersList.forEach((r: any) => {
                newRespondersMap[r.firebase_uid] = `${r.name} ${r.surname}`;
            });
            setRespondersMap(newRespondersMap);

            // 2. Fetch the permanent audit logs
            const response = await apiFetch(`/emergency-access-logs/`);
            let fetchedLogs = response.results || response || [];
            
            // Sort by newest first to ensure the latest audits are at the top
            fetchedLogs.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
            
            setLogs(fetchedLogs);
        } catch (error) { 
            console.error("Audit Log Fetch Error:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { 
        fetchData(); 
        const interval = setInterval(fetchData, 30000); // Live sync every 30 seconds
        return () => clearInterval(interval);
    }, []);

    const filteredLogs = useMemo(() => {
        return logs.filter(log => {
            if (!searchTerm) return true;
            const searchLower = searchTerm.toLowerCase();
            const exactResponderName = respondersMap[log.accessed_by_uid] || "";
            
            return (
                (log.student_number && log.student_number.toLowerCase().includes(searchLower)) ||
                (log.student_name && log.student_name.toLowerCase().includes(searchLower)) ||
                (log.accessed_by_uid && log.accessed_by_uid.toLowerCase().includes(searchLower)) ||
                (exactResponderName.toLowerCase().includes(searchLower))
            );
        });
    }, [logs, searchTerm, respondersMap]);

    // Format ISO date to readable string matching South African locale standard
    const formatDate = (dateString: string) => {
        const date = new Date(dateString);
        return new Intl.DateTimeFormat('en-ZA', {
            year: 'numeric', month: 'short', day: 'numeric',
            hour: '2-digit', minute: '2-digit', second: '2-digit'
        }).format(date);
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="Emergency Audit Logs" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        Total Recorded Access Events: {filteredLogs.length}
                    </p>
                </div>
            </div>

            {/* POPIA Compliance Warning Banner */}
            <div className="bg-red-50 border border-red-100 p-4 rounded-2xl flex items-start gap-4 shadow-sm">
                <ShieldAlert className="text-red-500 shrink-0 mt-0.5" size={20} />
                <div>
                    <h3 className="text-red-700 text-xs font-black uppercase tracking-widest">Strict Confidentiality Audit</h3>
                    <p className="text-red-600/80 text-sm font-medium mt-1">
                        This table represents the immutable POPIA compliance log. It records every instance where medical biometrics were used to unlock a student's restricted health profile. These records cannot be altered or deleted.
                    </p>
                </div>
            </div>

            {/* Search Engine */}
            <div className="bg-white border border-slate-200 p-6 rounded-[28px] shadow-sm space-y-4">
                <div className="flex flex-col lg:flex-row gap-4">
                    <div className="relative flex-1">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                        <input 
                            type="text"
                            placeholder="Search by Student ID, Name, or Responder..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full bg-slate-50 border border-slate-200 pl-12 pr-4 py-3.5 rounded-2xl text-sm outline-none focus:bg-white focus:border-red-400 focus:ring-4 focus:ring-red-50 transition-all font-medium text-slate-700 placeholder-slate-400"
                        />
                    </div>
                    <button onClick={() => setSearchTerm("")} className="p-3 text-slate-400 hover:text-red-600 bg-slate-50 hover:bg-red-50 rounded-xl transition-all border border-transparent hover:border-red-100">
                        <X size={20} />
                    </button>
                </div>
            </div>

            {/* Audit Log Table */}
            <div className="bg-white border border-slate-200 rounded-[28px] shadow-sm overflow-hidden">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1000px]">
                        <thead className="bg-slate-50/80 border-b border-slate-100 text-slate-400 text-[10px] uppercase tracking-[0.2em]">
                            <tr>
                                <th className="py-5 px-6 font-black"><div className="flex items-center gap-2"><Clock size={14}/> Timestamp</div></th>
                                <th className="py-5 px-6 font-black"><div className="flex items-center gap-2"><User size={14}/> Patient (Student)</div></th>
                                <th className="py-5 px-6 font-black"><div className="flex items-center gap-2"><Fingerprint size={14}/> Authorized By (Responder)</div></th>
                                <th className="py-5 px-6 font-black"><div className="flex items-center gap-2"><MapPin size={14}/> Incident Coordinates</div></th>
                                <th className="py-5 px-6 font-black text-right">Verification Status</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100 text-sm">
                            {loading ? (
                                <tr><td colSpan={5} className="py-24 text-center"><Loader2 className="animate-spin mx-auto text-red-500" size={32} /></td></tr>
                            ) : filteredLogs.length === 0 ? (
                                <tr><td colSpan={5} className="py-24 text-center text-slate-400 font-bold uppercase tracking-widest italic">No access logs found in system.</td></tr>
                            ) : filteredLogs.map((log: any) => (
                                <tr key={log.id} className="hover:bg-slate-50/50 transition-all group">
                                    <td className="py-4 px-6">
                                        <div className="font-bold text-slate-700">{formatDate(log.created_at)}</div>
                                        <div className="text-[10px] text-slate-400 font-bold uppercase mt-1 tracking-widest">Log ID: {log.id.split('-')[0]}</div>
                                    </td>
                                    
                                    <td className="py-4 px-6">
                                        <div className="font-black text-slate-900 text-base">{log.student_name}</div>
                                        <div className="text-[10px] text-red-400 font-bold uppercase mt-1 tracking-widest">ID: {log.student_number}</div>
                                    </td>
                                    
                                    <td className="py-4 px-6">
                                        <div className="font-bold text-slate-700 mb-1">
                                            {respondersMap[log.accessed_by_uid] || "Unknown Responder"}
                                        </div>
                                        <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border bg-slate-100 text-slate-600 border-slate-200 text-[9px] font-black tracking-widest">
                                            UID: {log.accessed_by_uid.substring(0, 15)}...
                                        </div>
                                    </td>

                                    <td className="py-4 px-6">
                                        {/* Handling potential null coordinates safely */}
                                        <div className="text-xs font-bold text-slate-600">
                                            Lat: {log.latitude != null ? Number(log.latitude).toFixed(5) : 'N/A'}
                                        </div>
                                        <div className="text-xs font-bold text-slate-600">
                                            Lng: {log.longitude != null ? Number(log.longitude).toFixed(5) : 'N/A'}
                                        </div>
                                    </td>
                                    
                                    <td className="py-4 px-6 text-right">
                                        <span className="inline-flex items-center gap-1.5 text-[9px] font-black tracking-widest uppercase text-emerald-600 bg-emerald-50 border border-emerald-100 px-2.5 py-1 rounded-lg">
                                            <Activity size={12} /> DUAL-SCAN VERIFIED
                                        </span>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}