"use client";

import React, { useState, useEffect, useMemo } from 'react';
import { 
  AlertTriangle, Loader2, MapPin, Clock, 
  CheckCircle2, Search, ShieldAlert, Image as ImageIcon, X, User
} from 'lucide-react';
import { apiFetch } from '../../components/api';
import { SectionHeader } from '../../components/SharedUI';

export default function EmergencyLogsPage() {
    const [emergencies, setEmergencies] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState("");
    const [statusFilter, setStatusFilter] = useState("");
    
    // State for the Image Preview Modal (Situation Image)
    const [previewImageUrl, setPreviewImageUrl] = useState<string | null>(null);

    const fetchEmergencies = async () => {
        setLoading(true);
        try {
            const response = await apiFetch('/emergencies/');
            let fetchedLogs = response.results || response || [];
            
            // Sort by newest first
            fetchedLogs.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
            
            setEmergencies(fetchedLogs);
        } catch (error) { 
            console.error("Failed to fetch emergency logs:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { 
        fetchEmergencies(); 
    }, []);

    // Filter Engine
    const filteredEmergencies = useMemo(() => {
        return emergencies.filter(log => {
            const searchString = `${log.patient_name} ${log.reporter_name} ${log.emergency_type} ${log.patient_room}`.toLowerCase();
            const matchesSearch = searchString.includes(searchTerm.toLowerCase());
            const matchesStatus = statusFilter === "" || log.status === statusFilter;

            return matchesSearch && matchesStatus;
        });
    }, [emergencies, searchTerm, statusFilter]);

    const getStatusConfig = (status: string) => {
        switch(status) {
            case 'PENDING':
                return { color: 'text-rose-600', bg: 'bg-rose-50', border: 'border-rose-200', icon: <AlertTriangle size={12} className="animate-pulse" />, label: 'Critical - Unassigned' };
            case 'RESPONDING':
                return { color: 'text-amber-600', bg: 'bg-amber-50', border: 'border-amber-200', icon: <ShieldAlert size={12} />, label: 'Staff Responding' };
            case 'RESOLVED':
                return { color: 'text-emerald-600', bg: 'bg-emerald-50', border: 'border-emerald-200', icon: <CheckCircle2 size={12} />, label: 'Resolved / Closed' };
            default:
                return { color: 'text-slate-600', bg: 'bg-slate-50', border: 'border-slate-200', icon: <Clock size={12} />, label: status };
        }
    };

    const openInMaps = (lat: number, lng: number) => {
        if (!lat || !lng) return alert("GPS coordinates were not captured for this emergency.");
        window.open(`https://www.google.com/maps/search/?api=1&query=${lat},${lng}`, '_blank');
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500 relative">
            {/* Header */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="Emergency Dispatch Logs" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        Incident Reports & Tracking Directory
                    </p>
                </div>
            </div>

            {/* Search & Filter */}
            <div className="bg-white border border-rose-100 p-6 rounded-[28px] shadow-sm space-y-4">
                <div className="flex flex-col lg:flex-row gap-4">
                    <div className="relative flex-1">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-rose-300" size={18} />
                        <input 
                            type="text"
                            placeholder="Search by student, room number, or emergency type..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full bg-rose-50/30 border border-rose-100 pl-12 pr-4 py-3.5 rounded-2xl text-sm outline-none focus:bg-white focus:border-rose-400 transition-all font-medium"
                        />
                    </div>
                    <div className="flex gap-2">
                        <select 
                            value={statusFilter} 
                            onChange={(e) => setStatusFilter(e.target.value)}
                            className="bg-white border border-rose-100 px-4 py-3 rounded-xl text-[11px] font-bold text-slate-500 outline-none focus:border-rose-400 transition-all min-w-[160px]"
                        >
                            <option value="">All Statuses</option>
                            <option value="PENDING">Critical (Unassigned)</option>
                            <option value="RESPONDING">Staff Responding</option>
                            <option value="RESOLVED">Resolved / Closed</option>
                        </select>
                    </div>
                </div>
            </div>

            {/* Main Emergency Table */}
            <div className="bg-white border border-slate-100 rounded-[28px] shadow-sm overflow-hidden">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1200px]">
                        <thead className="bg-slate-50/50 border-b border-slate-100 text-slate-400 text-[10px] uppercase tracking-[0.2em]">
                            <tr>
                                <th className="py-5 px-6 font-black">Patient Details</th>
                                <th className="py-5 px-6 font-black">Emergency Type</th>
                                <th className="py-5 px-6 font-black">Reported By</th>
                                <th className="py-5 px-6 font-black">Time & Date</th>
                                <th className="py-5 px-6 font-black">Status</th>
                                <th className="py-5 px-6 font-black text-right sticky right-0 bg-white">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-50 text-sm">
                            {loading ? (
                                <tr><td colSpan={6} className="py-24 text-center"><Loader2 className="animate-spin mx-auto text-rose-500" size={32} /></td></tr>
                            ) : filteredEmergencies.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="py-24 text-center">
                                        <ShieldAlert size={48} className="mx-auto text-slate-200 mb-4" />
                                        <p className="text-slate-400 font-bold uppercase tracking-widest italic">No emergency logs found.</p>
                                    </td>
                                </tr>
                            ) : filteredEmergencies.map((log: any) => {
                                const statusConfig = getStatusConfig(log.status);

                                return (
                                    <tr key={log.id} className="hover:bg-slate-50/50 transition-all group">
                                        <td className="py-4 px-6">
                                            <div className="flex items-center gap-3">
                                                {/* INLINE SECURE FACE DECRYPTION PREVIEW */}
                                                <SecureFacePreview studentId={log.patient_id} />
                                                <div>
                                                    <div className="font-black text-slate-900 text-base">{log.patient_name || 'Unidentified Patient'}</div>
                                                    <div className="text-[10px] text-slate-400 font-bold uppercase mt-1 tracking-widest">
                                                        Room: {log.patient_room || 'Unknown'}
                                                    </div>
                                                </div>
                                            </div>
                                        </td>
                                        
                                        <td className="py-4 px-6">
                                            <span className="inline-flex items-center px-2.5 py-1 rounded-lg border border-slate-200 bg-slate-100 text-slate-700 text-[9px] font-black tracking-widest uppercase mb-1">
                                                {log.emergency_type}
                                            </span>
                                            <p className="text-xs text-slate-500 font-medium line-clamp-2 max-w-xs">
                                                {log.description || "No description provided."}
                                            </p>
                                        </td>
                                        
                                        <td className="py-4 px-6">
                                            <div className="text-xs font-bold text-slate-700">{log.reporter_name}</div>
                                            <div className={`inline-flex mt-1 items-center px-2 py-0.5 rounded border text-[8px] font-black tracking-widest uppercase ${log.reporter_role === 'STUDENT' ? 'bg-blue-50 text-blue-600 border-blue-100' : log.reporter_role === 'SYSTEM' ? 'bg-slate-50 text-slate-500 border-slate-200' : 'bg-purple-50 text-purple-600 border-purple-100'}`}>
                                                {log.reporter_role}
                                            </div>
                                        </td>
                                        
                                        <td className="py-4 px-6">
                                            <div className="text-xs font-bold text-slate-700">
                                                {new Date(log.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                                            </div>
                                            <div className="text-[10px] text-slate-400 font-medium mt-1">
                                                {new Date(log.created_at).toLocaleDateString()}
                                            </div>
                                        </td>
                                        
                                        <td className="py-4 px-6">
                                            <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border text-[9px] font-black tracking-widest uppercase ${statusConfig.bg} ${statusConfig.color} ${statusConfig.border}`}>
                                                {statusConfig.icon} {statusConfig.label}
                                            </span>
                                        </td>
                                        
                                        <td className="py-4 px-6 text-right sticky right-0 bg-white group-hover:bg-slate-50/50 transition-all border-l border-slate-50">
                                            <div className="flex items-center justify-end gap-2">
                                                {/* TRIGGER PREVIEW MODAL */}
                                                {log.situation_image_url && (
                                                    <button 
                                                        onClick={() => setPreviewImageUrl(log.situation_image_url)}
                                                        className="p-2 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-xl shadow-sm transition-all border border-transparent hover:border-blue-100"
                                                        title="View Situation Image"
                                                    >
                                                        <ImageIcon size={16}/>
                                                    </button>
                                                )}
                                                <button 
                                                    onClick={() => openInMaps(log.latitude, log.longitude)}
                                                    className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-xl shadow-sm transition-all border border-transparent hover:border-indigo-100"
                                                    title="GPS Locate on Map"
                                                >
                                                    <MapPin size={16}/>
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* SECURE IMAGE MODAL RENDERER */}
            {previewImageUrl && (
                <SecureImageModal 
                    encryptedUrl={previewImageUrl} 
                    onClose={() => setPreviewImageUrl(null)} 
                />
            )}
        </div>
    );
}

// ---------------------------------------------------------------------------
// 1. SECURE INLINE FACE PREVIEW
// Automatically fetches the student's decrypted biometric face in memory
// ---------------------------------------------------------------------------
function SecureFacePreview({ studentId, className = "w-10 h-10 rounded-full object-cover shadow-sm border border-slate-200 flex-shrink-0" }: { studentId: string | null, className?: string }) {
    const [imgSrc, setImgSrc] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(false);

    useEffect(() => {
        const fetchFace = async () => {
            if (!studentId) {
                setLoading(false);
                setError(true);
                return;
            }
            
            try {
                const response = await apiFetch(`/students/${studentId}/decrypted-face/`, { method: 'GET' });
                
                if (response && response.face_base64) {
                    setImgSrc(`data:image/jpeg;base64,${response.face_base64}`);
                } else {
                    setError(true);
                }
            } catch (err) {
                setError(true);
            } finally {
                setLoading(false);
            }
        };

        fetchFace();
    }, [studentId]);

    if (loading) {
        return (
            <div className={`bg-slate-100 flex items-center justify-center animate-pulse ${className}`}>
                <Loader2 className="animate-spin text-slate-400" size={14} />
            </div>
        );
    }

    if (error || !imgSrc) {
        return (
            <div className={`bg-slate-100 flex items-center justify-center ${className}`}>
                <User className="text-slate-400" size={18} />
            </div>
        );
    }

    return <img src={imgSrc} alt="Patient Biometric" className={className} />;
}

// ---------------------------------------------------------------------------
// 2. SECURE SITUATION IMAGE MODAL
// Intercepts the encrypted Firebase URL, decrypts it via Django, 
// and previews it safely in memory without downloading.
// ---------------------------------------------------------------------------
function SecureImageModal({ encryptedUrl, onClose }: { encryptedUrl: string, onClose: () => void }) {
    const [imgSrc, setImgSrc] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchDecryptedFile = async () => {
            try {
                let rawApiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api';
                const cleanApiUrl = rawApiUrl.endsWith('/') ? rawApiUrl.slice(0, -1) : rawApiUrl;
                
                // --- EXACT COOKIE RETRIEVAL LOGIC FROM YOUR API.TS ---
                let token = '';
                if (typeof document !== 'undefined') {
                    const value = `; ${document.cookie}`;
                    const parts = value.split(`; fb_id_token=`);
                    if (parts.length === 2) {
                        const cookieValue = parts.pop()?.split(';').shift();
                        if (cookieValue) {
                            token = decodeURIComponent(cookieValue);
                        }
                    }
                }

                if (!token) {
                    throw new Error("Authentication token not found in cookies. Please log out and log back in.");
                }

                const fetchUrl = `${cleanApiUrl}/serve-decrypted-file/?token=${token}&file_url=${encodeURIComponent(encryptedUrl)}`;
                
                const response = await fetch(fetchUrl);
                
                if (!response.ok) {
                    const errorText = await response.text();
                    console.error(`Backend Rejected Decryption. Status: ${response.status}. Reason: ${errorText}`);
                    throw new Error(errorText || `HTTP Error ${response.status}`);
                }

                const blob = await response.blob();
                const objectUrl = URL.createObjectURL(blob);
                
                setImgSrc(objectUrl);
            } catch (err: any) {
                console.error("Preview Decryption Error:", err);
                setError(err.message || "Decryption failed.");
            } finally {
                setLoading(false);
            }
        };

        fetchDecryptedFile();

        return () => {
            if (imgSrc) URL.revokeObjectURL(imgSrc);
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [encryptedUrl]);

    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/80 backdrop-blur-sm animate-in fade-in duration-200 p-4">
            <div className="relative bg-white rounded-3xl overflow-hidden shadow-2xl max-w-4xl w-full max-h-[90vh] flex flex-col">
                
                {/* Modal Header */}
                <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-white">
                    <div className="flex items-center gap-3">
                        <ImageIcon size={20} className="text-indigo-600" />
                        <div>
                            <h3 className="text-sm font-black text-slate-900 tracking-tight">Secure Situation Preview</h3>
                            <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest mt-0.5">End-to-End Encrypted View</p>
                        </div>
                    </div>
                    <button 
                        onClick={onClose}
                        className="p-2 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-all"
                    >
                        <X size={20} />
                    </button>
                </div>

                {/* Modal Content */}
                <div className="flex-1 bg-slate-50 flex items-center justify-center p-6 overflow-hidden min-h-[400px]">
                    {loading ? (
                        <div className="flex flex-col items-center gap-3 text-indigo-500">
                            <Loader2 className="animate-spin" size={32} />
                            <span className="text-[10px] font-black uppercase tracking-widest">Decrypting File Protocol...</span>
                        </div>
                    ) : error || !imgSrc ? (
                        <div className="flex flex-col items-center gap-3 text-rose-500 p-6 text-center">
                            <ShieldAlert size={48} className="opacity-50" />
                            <span className="text-xs font-black uppercase tracking-widest">
                                Decryption Failed
                            </span>
                            <span className="text-sm font-medium text-slate-500 mt-2">
                                {error}
                            </span>
                        </div>
                    ) : (
                        <img 
                            src={imgSrc} 
                            alt="Decrypted Situation" 
                            className="max-w-full max-h-full object-contain rounded-xl shadow-lg animate-in zoom-in-95 duration-300"
                        />
                    )}
                </div>
            </div>
        </div>
    );
}