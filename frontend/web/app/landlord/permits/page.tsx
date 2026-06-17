"use client";

import React, { useState, useEffect } from 'react';
import { 
    Loader2, CheckCircle2, XCircle, Clock, MapPin, 
    User, Calendar, ClipboardCheck, Users, LogIn, LogOut, Search, ShieldCheck, History
} from 'lucide-react';
import { apiFetch } from '../../components/api'; 
import { SectionHeader } from '../../components/SharedUI';

export default function PermitsAndVisitorsPage() {
    const [activeTab, setActiveTab] = useState<'permits' | 'visitors' | 'audits'>('permits');
    
    const [permits, setPermits] = useState<any[]>([]);
    const [visitors, setVisitors] = useState<any[]>([]);
    const [audits, setAudits] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [permitsData, visitorsData, auditsData] = await Promise.all([
                apiFetch('/leave-permits/').catch(() => ({ results: [] })),
                apiFetch('/visitor-registers/').catch(() => ({ results: [] })),
                apiFetch('/visitor-audit-logs/').catch(() => ({ results: [] })) // Make sure this endpoint is registered in urls.py
            ]);
            
            let fetchedPermits = permitsData.results || permitsData || [];
            let fetchedVisitors = visitorsData.results || visitorsData || [];
            let fetchedAudits = auditsData.results || auditsData || [];
            
            // Sort newest first
            fetchedPermits.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
            fetchedVisitors.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
            fetchedAudits.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

            setPermits(fetchedPermits);
            setVisitors(fetchedVisitors);
            setAudits(fetchedAudits);
        } catch (error) { 
            console.error("Failed to fetch clearance data:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { 
        fetchData(); 
        const interval = setInterval(fetchData, 30000); // Auto-refresh every 30s
        return () => clearInterval(interval);
    }, []);

    const updatePermitStatus = async (id: string, newStatus: string) => {
        try {
            await apiFetch(`/leave-permits/${id}/`, { 
                method: 'PATCH', 
                body: JSON.stringify({ status: newStatus }) 
            });
            fetchData(); 
        } catch (error) { 
            console.error("Failed to update permit status"); 
        }
    };

    const formatDate = (isoString?: string | null) => {
        if (!isoString) return { date: '--', time: '--' };
        const date = new Date(isoString);
        return {
            date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
            time: date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
        };
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-300">
            <SectionHeader title="Clearance Hub: Permits & Visitors" />
            
            {/* --- PREMIUM NEUMORPHIC TAB TOGGLE --- */}
            <div className="flex items-center gap-2 bg-blue-50/50 p-1.5 rounded-2xl border border-blue-100/50 w-fit shadow-inner shadow-blue-100/50">
                <button 
                    onClick={() => setActiveTab('permits')}
                    className={`flex items-center gap-2 px-6 py-2.5 rounded-xl text-xs font-black tracking-widest uppercase transition-all duration-300 ${
                        activeTab === 'permits' 
                        ? 'bg-white text-blue-600 shadow-sm shadow-blue-200/50' 
                        : 'text-slate-400 hover:text-blue-500 hover:bg-white/50'
                    }`}
                >
                    <ClipboardCheck size={16} /> Exit Permits
                </button>
                <button 
                    onClick={() => setActiveTab('visitors')}
                    className={`flex items-center gap-2 px-6 py-2.5 rounded-xl text-xs font-black tracking-widest uppercase transition-all duration-300 ${
                        activeTab === 'visitors' 
                        ? 'bg-white text-blue-600 shadow-sm shadow-blue-200/50' 
                        : 'text-slate-400 hover:text-blue-500 hover:bg-white/50'
                    }`}
                >
                    <Users size={16} /> Visitor Logs
                </button>
                <button 
                    onClick={() => setActiveTab('audits')}
                    className={`flex items-center gap-2 px-6 py-2.5 rounded-xl text-xs font-black tracking-widest uppercase transition-all duration-300 ${
                        activeTab === 'audits' 
                        ? 'bg-white text-blue-600 shadow-sm shadow-blue-200/50' 
                        : 'text-slate-400 hover:text-blue-500 hover:bg-white/50'
                    }`}
                >
                    <ShieldCheck size={16} /> Security Audit Logs
                </button>
            </div>

            <div className="bg-white border border-blue-100 rounded-[24px] shadow-sm overflow-hidden">
                <div className="overflow-x-auto custom-scrollbar">
                    
                    {/* ========================================================= */}
                    {/* PERMITS TABLE */}
                    {/* ========================================================= */}
                    {activeTab === 'permits' && (
                        <table className="w-full text-left min-w-[1200px]">
                            <thead className="bg-blue-50/50 border-b border-blue-100 text-slate-500 text-[10px] uppercase tracking-widest whitespace-nowrap">
                                <tr>
                                    <th className="py-5 px-6 font-bold w-32">Requested For</th>
                                    <th className="py-5 px-4 font-bold w-40">Resident</th>
                                    <th className="py-5 px-4 font-bold w-40">Location</th>
                                    <th className="py-5 px-4 font-bold w-48">Destination</th>
                                    <th className="py-5 px-6 font-bold min-w-[200px]">Reason</th>
                                    <th className="py-5 px-4 font-bold w-36">Status</th>
                                    <th className="py-5 px-6 text-right font-bold w-40">Admin Override</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                                {loading && (
                                    <tr>
                                        <td colSpan={7} className="py-12 text-center">
                                            <Loader2 className="animate-spin mx-auto text-blue-500" />
                                        </td>
                                    </tr>
                                )}
                                {!loading && permits.length === 0 && (
                                    <tr>
                                        <td colSpan={7} className="py-16 text-center">
                                            <ClipboardCheck size={48} className="mx-auto text-blue-300 mb-4 opacity-50" />
                                            <p className="text-blue-950 font-bold">No Leave Permits</p>
                                            <p className="text-slate-500 text-xs mt-1">Students have not requested any exit permits recently.</p>
                                        </td>
                                    </tr>
                                )}
                                {!loading && permits.map((permit: any) => {
                                    const { date, time } = formatDate(permit.departure_date);
                                    
                                    // Extract resident details from nested serializer
                                    const student = permit.student_details || {};
                                    
                                    return (
                                        <tr key={permit.id} className="hover:bg-blue-50/30 transition-colors text-sm">
                                            <td className="py-4 px-6 align-middle whitespace-nowrap">
                                                <div className="font-bold text-slate-700">{date}</div>
                                                <div className="text-[10px] text-slate-400 mt-0.5 flex items-center gap-1"><Clock size={10} /> {time}</div>
                                            </td>

                                            <td className="py-4 px-4 align-middle whitespace-nowrap">
                                                <p className="font-black text-blue-950">{student.name || 'Unknown'}</p>
                                                <p className="font-medium text-slate-500 text-xs">{student.surname || 'Student'}</p>
                                            </td>

                                            <td className="py-4 px-4 align-middle">
                                                <div className="flex flex-col gap-1 w-fit">
                                                    <span className="text-[10px] font-bold text-slate-600 bg-slate-100 px-2 py-0.5 rounded uppercase tracking-wider">
                                                        Block {student.block_name || 'N/A'}
                                                    </span>
                                                    <span className="text-[10px] font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded uppercase tracking-wider">
                                                        Room {student.room_number_only || 'N/A'}
                                                    </span>
                                                </div>
                                            </td>

                                            <td className="py-4 px-4 align-middle font-bold text-blue-900">
                                                <div className="flex items-center gap-1.5">
                                                    <MapPin size={14} className="text-blue-400" />
                                                    {permit.destination_province || 'N/A'}
                                                </div>
                                            </td>

                                            <td className="py-4 px-6 align-middle">
                                                <p className="text-xs text-slate-500 line-clamp-2 leading-relaxed max-w-xs">
                                                    {permit.reason || 'No reason provided.'}
                                                </p>
                                            </td>

                                            <td className="py-4 px-4 align-middle whitespace-nowrap">
                                                <span className={`flex w-fit items-center gap-1.5 text-[10px] font-black tracking-widest px-2 py-1 rounded-md border shadow-sm uppercase ${
                                                    permit.status === 'APPROVED' ? 'bg-emerald-50 text-emerald-600 border-emerald-200' :
                                                    permit.status === 'DENIED' ? 'bg-rose-50 text-rose-600 border-rose-200' :
                                                    permit.status === 'INSPECTING' ? 'bg-blue-50 text-blue-600 border-blue-200' :
                                                    'bg-amber-50 text-amber-600 border-amber-200'
                                                }`}>
                                                    {permit.status === 'APPROVED' && <CheckCircle2 size={12} />}
                                                    {permit.status === 'DENIED' && <XCircle size={12} />}
                                                    {permit.status === 'INSPECTING' && <Search size={12} />}
                                                    {permit.status === 'REQUESTED' && <Clock size={12} />}
                                                    {permit.status}
                                                </span>
                                            </td>

                                            <td className="py-4 px-6 text-right align-middle">
                                                {permit.status === 'REQUESTED' || permit.status === 'INSPECTING' ? (
                                                    <div className="flex items-center justify-end gap-2">
                                                        <button onClick={() => updatePermitStatus(permit.id, 'APPROVED')} className="p-2 text-emerald-600 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-colors" title="Force Approve">
                                                            <CheckCircle2 size={16} />
                                                        </button>
                                                        <button onClick={() => updatePermitStatus(permit.id, 'DENIED')} className="p-2 text-rose-600 bg-rose-50 hover:bg-rose-100 rounded-lg transition-colors" title="Force Deny">
                                                            <XCircle size={16} />
                                                        </button>
                                                    </div>
                                                ) : (
                                                    <span className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">Locked</span>
                                                )}
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    )}

                    {/* ========================================================= */}
                    {/* VISITOR LOGS TABLE */}
                    {/* ========================================================= */}
                    {activeTab === 'visitors' && (
                        <table className="w-full text-left min-w-[1200px]">
                            <thead className="bg-slate-50/80 border-b border-slate-200 text-slate-500 text-[10px] uppercase tracking-widest whitespace-nowrap">
                                <tr>
                                    <th className="py-5 px-6 font-bold w-48">Date Registered</th>
                                    <th className="py-5 px-4 font-bold w-48">Visitor Name</th>
                                    <th className="py-5 px-4 font-bold w-40">Host Resident</th>
                                    <th className="py-5 px-4 font-bold w-40">Host Location</th>
                                    <th className="py-5 px-6 font-bold w-32">Time In</th>
                                    <th className="py-5 px-6 font-bold w-32">Time Out</th>
                                    <th className="py-5 px-6 font-bold w-36">Gate Status</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                                {loading && (
                                    <tr>
                                        <td colSpan={7} className="py-12 text-center">
                                            <Loader2 className="animate-spin mx-auto text-blue-500" />
                                        </td>
                                    </tr>
                                )}
                                {!loading && visitors.length === 0 && (
                                    <tr>
                                        <td colSpan={7} className="py-16 text-center">
                                            <Users size={48} className="mx-auto text-slate-300 mb-4 opacity-50" />
                                            <p className="text-slate-700 font-bold">No Visitor Logs</p>
                                            <p className="text-slate-400 text-xs mt-1">There are no visitor registrations on record.</p>
                                        </td>
                                    </tr>
                                )}
                                {!loading && visitors.map((visitor: any) => {
                                    const { date: regDate, time: regTime } = formatDate(visitor.created_at);
                                    const { time: timeIn } = formatDate(visitor.time_in);
                                    const { time: timeOut } = formatDate(visitor.time_out);
                                    
                                    return (
                                        <tr key={visitor.id} className="hover:bg-slate-50/50 transition-colors text-sm">
                                            <td className="py-4 px-6 align-middle whitespace-nowrap">
                                                <div className="font-bold text-slate-700">{regDate}</div>
                                                <div className="text-[10px] text-slate-400 mt-0.5 flex items-center gap-1"><Calendar size={10} /> {regTime}</div>
                                            </td>

                                            <td className="py-4 px-4 align-middle whitespace-nowrap">
                                                <div className="flex items-center gap-3">
                                                    <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-slate-400">
                                                        <User size={14} />
                                                    </div>
                                                    <p className="font-black text-slate-800">{visitor.visitor_name}</p>
                                                </div>
                                            </td>

                                            <td className="py-4 px-4 align-middle whitespace-nowrap">
                                                <p className="font-bold text-blue-900">{visitor.student_name}</p>
                                                <p className="text-xs text-slate-500">{visitor.student_surname}</p>
                                            </td>

                                            <td className="py-4 px-4 align-middle">
                                                <div className="flex flex-col gap-1 w-fit">
                                                    <span className="text-[10px] font-bold text-slate-600 bg-white border border-slate-200 px-2 py-0.5 rounded uppercase tracking-wider shadow-sm">
                                                        {visitor.block_name || 'N/A'}
                                                    </span>
                                                    <span className="text-[10px] font-bold text-slate-500 px-2 py-0.5 uppercase tracking-wider">
                                                        RM: {visitor.room_number || 'N/A'}
                                                    </span>
                                                </div>
                                            </td>

                                            <td className="py-4 px-6 align-middle font-bold">
                                                {visitor.time_in ? (
                                                    <span className="flex items-center gap-1.5 text-emerald-600 bg-emerald-50 px-2 py-1 rounded w-fit text-xs">
                                                        <LogIn size={12} /> {timeIn}
                                                    </span>
                                                ) : (
                                                    <span className="text-slate-300 text-xs tracking-widest">--:--</span>
                                                )}
                                            </td>

                                            <td className="py-4 px-6 align-middle font-bold">
                                                {visitor.time_out ? (
                                                    <span className="flex items-center gap-1.5 text-slate-600 bg-slate-100 px-2 py-1 rounded w-fit text-xs">
                                                        <LogOut size={12} /> {timeOut}
                                                    </span>
                                                ) : (
                                                    <span className="text-slate-300 text-xs tracking-widest">--:--</span>
                                                )}
                                            </td>

                                            <td className="py-4 px-6 align-middle whitespace-nowrap">
                                                <span className={`flex w-fit items-center gap-1.5 text-[10px] font-black tracking-widest px-2 py-1 rounded-md border shadow-sm uppercase ${
                                                    visitor.status === 'SIGNED_IN' ? 'bg-emerald-50 text-emerald-600 border-emerald-200' :
                                                    visitor.status === 'SIGNED_OUT' ? 'bg-slate-50 text-slate-500 border-slate-200' :
                                                    'bg-amber-50 text-amber-600 border-amber-200'
                                                }`}>
                                                    {visitor.status === 'SIGNED_IN' && <LogIn size={12} />}
                                                    {visitor.status === 'SIGNED_OUT' && <CheckCircle2 size={12} />}
                                                    {visitor.status === 'PENDING' && <Clock size={12} />}
                                                    {visitor.status.replace('_', ' ')}
                                                </span>
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    )}

                    {/* ========================================================= */}
                    {/* AUDIT LOGS TABLE */}
                    {/* ========================================================= */}
                    {activeTab === 'audits' && (
                        <table className="w-full text-left min-w-[1200px]">
                           <thead className="bg-purple-50/50 border-b border-purple-100 text-slate-500 text-[10px] uppercase tracking-widest whitespace-nowrap">
    <tr>
        <th className="py-5 px-6 font-bold w-48">Timestamp</th>
        <th className="py-5 px-4 font-bold w-40">Action Taken</th>
        <th className="py-5 px-4 font-bold w-48">Security Officer</th>
        <th className="py-5 px-4 font-bold w-48">Visitor Scanned</th>
        <th className="py-5 px-6 font-bold">Host & Location</th>
    </tr>
</thead>
<tbody className="divide-y divide-slate-100">
    {loading && (
        <tr>
            <td colSpan={5} className="py-12 text-center">
                <Loader2 className="animate-spin mx-auto text-purple-500" />
            </td>
        </tr>
    )}
    {!loading && audits.length === 0 && (
        <tr>
            <td colSpan={5} className="py-16 text-center">
                <History size={48} className="mx-auto text-slate-300 mb-4 opacity-50" />
                <p className="text-slate-700 font-bold">No Audit Records</p>
                <p className="text-slate-400 text-xs mt-1">No security scans have been recorded yet.</p>
            </td>
        </tr>
    )}
    {!loading && audits.map((audit: any) => {
        const { date: logDate, time: logTime } = formatDate(audit.created_at);
        
        const officerName = audit.security_officer ? `${audit.security_officer.name || ''} ${audit.security_officer.surname || ''}` : 'Unknown Officer';
        const visitorName = audit.visitor_record?.visitor_name || 'Unknown Visitor';
        const studentName = audit.student ? `${audit.student.name || ''} ${audit.student.surname || ''}` : 'Unknown Resident';

        return (
            <tr key={audit.id} className="hover:bg-purple-50/30 transition-colors text-sm">
                <td className="py-4 px-6 align-middle whitespace-nowrap">
                    <div className="font-bold text-slate-700">{logDate}</div>
                    <div className="text-[10px] text-slate-400 mt-0.5 flex items-center gap-1"><Clock size={10} /> {logTime}</div>
                </td>

                <td className="py-4 px-4 align-middle whitespace-nowrap">
                    <span className={`flex w-fit items-center gap-1.5 text-[10px] font-black tracking-widest px-2 py-1 rounded-md border shadow-sm uppercase ${
                        audit.action_taken === 'SIGNED_IN' ? 'bg-emerald-50 text-emerald-600 border-emerald-200' :
                        'bg-slate-50 text-slate-600 border-slate-200'
                    }`}>
                        {audit.action_taken === 'SIGNED_IN' ? <LogIn size={12} /> : <LogOut size={12} />}
                        {audit.action_taken.replace('_', ' ')}
                    </span>
                </td>

                <td className="py-4 px-4 align-middle whitespace-nowrap">
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center text-purple-600">
                            <ShieldCheck size={14} />
                        </div>
                        <p className="font-bold text-slate-800">{officerName}</p>
                    </div>
                </td>

                <td className="py-4 px-4 align-middle whitespace-nowrap">
                    <p className="font-bold text-blue-900">{visitorName}</p>
                    <p className="text-[10px] text-slate-500 mt-0.5 uppercase tracking-wider">Visitor Record ID: {audit.visitor_record?.id?.substring(0,8) || 'N/A'}</p>
                </td>

                <td className="py-4 px-6 align-middle">
                    <p className="font-bold text-slate-700">{studentName}</p>
                    <div className="flex gap-2 mt-1">
                        <span className="text-[9px] font-bold text-slate-500 bg-slate-100 px-1.5 py-0.5 rounded uppercase">Block {audit.block_name}</span>
                        <span className="text-[9px] font-bold text-slate-500 bg-slate-100 px-1.5 py-0.5 rounded uppercase">Room {audit.room_number}</span>
                    </div>
                </td>
            </tr>
        );
    })}
</tbody>
                            <tbody className="divide-y divide-slate-100">
                                {loading && (
                                    <tr>
                                        <td colSpan={5} className="py-12 text-center">
                                            <Loader2 className="animate-spin mx-auto text-purple-500" />
                                        </td>
                                    </tr>
                                )}
                                {!loading && audits.length === 0 && (
                                    <tr>
                                        <td colSpan={5} className="py-16 text-center">
                                            <History size={48} className="mx-auto text-slate-300 mb-4 opacity-50" />
                                            <p className="text-slate-700 font-bold">No Audit Records</p>
                                            <p className="text-slate-400 text-xs mt-1">No security scans have been recorded yet.</p>
                                        </td>
                                    </tr>
                                )}
                                {!loading && audits.map((audit: any) => {
                                    const { date: logDate, time: logTime } = formatDate(audit.created_at);
                                    
                                    // Handle missing or nested data safely
                                    const officerName = audit.security_officer ? `${audit.security_officer.name || ''} ${audit.security_officer.surname || ''}` : 'Unknown Officer';
                                    const visitorName = audit.visitor_record?.visitor_name || 'Unknown Visitor';
                                    const studentName = audit.student ? `${audit.student.name || ''} ${audit.student.surname || ''}` : 'Unknown Resident';

                                    return (
                                        <tr key={audit.id} className="hover:bg-purple-50/30 transition-colors text-sm">
                                            <td className="py-4 px-6 align-middle whitespace-nowrap">
                                                <div className="font-bold text-slate-700">{logDate}</div>
                                                <div className="text-[10px] text-slate-400 mt-0.5 flex items-center gap-1"><Clock size={10} /> {logTime}</div>
                                            </td>

                                            <td className="py-4 px-4 align-middle whitespace-nowrap">
                                                <span className={`flex w-fit items-center gap-1.5 text-[10px] font-black tracking-widest px-2 py-1 rounded-md border shadow-sm uppercase ${
                                                    audit.action_taken === 'SIGNED_IN' ? 'bg-emerald-50 text-emerald-600 border-emerald-200' :
                                                    'bg-slate-50 text-slate-600 border-slate-200'
                                                }`}>
                                                    {audit.action_taken === 'SIGNED_IN' ? <LogIn size={12} /> : <LogOut size={12} />}
                                                    {audit.action_taken.replace('_', ' ')}
                                                </span>
                                            </td>

                                            <td className="py-4 px-4 align-middle whitespace-nowrap">
                                                <div className="flex items-center gap-3">
                                                    <div className="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center text-purple-600">
                                                        <ShieldCheck size={14} />
                                                    </div>
                                                    <p className="font-bold text-slate-800">{officerName}</p>
                                                </div>
                                            </td>

                                            <td className="py-4 px-4 align-middle whitespace-nowrap">
                                                <p className="font-bold text-blue-900">{visitorName}</p>
                                                <p className="text-[10px] text-slate-500 mt-0.5 uppercase tracking-wider">Visitor Record ID: {audit.visitor_record?.id?.substring(0,8) || 'N/A'}</p>
                                            </td>

                                            <td className="py-4 px-6 align-middle">
                                                <p className="font-bold text-slate-700">{studentName}</p>
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
        </div>
    );
}