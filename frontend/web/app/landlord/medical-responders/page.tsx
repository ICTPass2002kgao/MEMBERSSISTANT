"use client";

import React, { useState, useEffect, useMemo, useRef } from 'react';
import { 
  Plus, AlertCircle, Loader2, Trash2,
  HeartPulse, Activity, CheckCircle2, 
  Search, X, Siren, Camera
} from 'lucide-react';
import { apiFetch } from '../../components/api'; 
import { SectionHeader, ModalWrapper, Input, SubmitButton } from '../../components/SharedUI'; 

export default function MedicalRespondersPage() {
    const [responders, setResponders] = useState<any[]>([]);
    const [activeEmergencies, setActiveEmergencies] = useState<any[]>([]); 
    const [loading, setLoading] = useState(true);
    const [isModalOpen, setIsModalOpen] = useState(false);

    const [searchTerm, setSearchTerm] = useState("");
    const [statusFilter, setStatusFilter] = useState(""); 

    const fetchRespondersAndEmergencies = async () => {
        setLoading(true);
        try {
            // Now fetching from the dedicated medical responders endpoint
            const [staffData, emergencyData] = await Promise.all([
                apiFetch(`/medical-responders/`),
                apiFetch('/emergencies/')
            ]);
            
            let fetchedList = staffData.results || staffData || [];
            let fetchedEmergencies = (emergencyData.results || emergencyData || []).filter(
                (e: any) => e.status === 'RESPONDING'
            );
            
            setResponders(fetchedList);
            setActiveEmergencies(fetchedEmergencies);
        } catch (error) { 
            console.error("System Fetch Error:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { 
        fetchRespondersAndEmergencies(); 
        const interval = setInterval(fetchRespondersAndEmergencies, 15000); 
        return () => clearInterval(interval);
    }, []);

    const filteredResponders = useMemo(() => {
        return responders.filter(staff => {
            const matchesSearch = 
                `${staff.name} ${staff.surname}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
                staff.email.toLowerCase().includes(searchTerm.toLowerCase());
            
            const isResponding = activeEmergencies.some(e => e.resolved_by === staff.id);
            const matchesStatus = statusFilter === "" || 
                (statusFilter === "RESPONDING" && isResponding) || 
                (statusFilter === "AVAILABLE" && !isResponding);

            return matchesSearch && matchesStatus;
        });
    }, [responders, searchTerm, statusFilter, activeEmergencies]);

    const handleDelete = async (id: string, name: string) => {
        if (!window.confirm(`CRITICAL: Revoke emergency dispatch access and permanently delete account for ${name}?`)) return;
        try {
            await apiFetch(`/medical-responders/${id}/`, { method: 'DELETE' });
            fetchRespondersAndEmergencies(); 
        } catch (error) { alert("Failed to remove responder."); }
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="Medical Response Team" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        Active Dispatch Personnel: {filteredResponders.length}
                    </p>
                </div>
                <button onClick={() => setIsModalOpen(true)} className="flex items-center gap-2 px-6 py-3 bg-red-600 hover:bg-red-700 text-white rounded-2xl text-[11px] font-black uppercase tracking-widest shadow-lg shadow-red-600/20 transition-all active:scale-95">
                    <Plus size={16} /> Add Responder
                </button>
            </div>

            <div className="bg-white border border-slate-200 p-6 rounded-[28px] shadow-sm space-y-4">
                <div className="flex flex-col lg:flex-row gap-4">
                    <div className="relative flex-1">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                        <input 
                            type="text"
                            placeholder="Search medical team by name or email..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full bg-slate-50 border border-slate-200 pl-12 pr-4 py-3.5 rounded-2xl text-sm outline-none focus:bg-white focus:border-red-400 focus:ring-4 focus:ring-red-50 transition-all font-medium text-slate-700 placeholder-slate-400"
                        />
                    </div>

                    <div className="flex flex-wrap gap-2">
                        <select 
                            value={statusFilter} 
                            onChange={(e) => setStatusFilter(e.target.value)}
                            className="bg-white border border-slate-200 px-4 py-3 rounded-xl text-[11px] font-bold text-slate-600 outline-none focus:border-red-400 focus:ring-4 focus:ring-red-50 transition-all min-w-[140px]"
                        >
                            <option value="">Any Status</option>
                            <option value="AVAILABLE">On Standby</option>
                            <option value="RESPONDING">Actively Responding</option>
                        </select>

                        <button onClick={() => {setSearchTerm(""); setStatusFilter("");}} className="p-3 text-slate-400 hover:text-red-600 bg-slate-50 hover:bg-red-50 rounded-xl transition-all border border-transparent hover:border-red-100">
                            <X size={20} />
                        </button>
                    </div>
                </div>
            </div>

            <div className="bg-white border border-slate-200 rounded-[28px] shadow-sm overflow-hidden">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1000px]">
                        <thead className="bg-slate-50/80 border-b border-slate-100 text-slate-400 text-[10px] uppercase tracking-[0.2em]">
                            <tr>
                                <th className="py-5 px-6 font-black">Responder Name</th>
                                <th className="py-5 px-6 font-black">Contact Detail</th>
                                <th className="py-5 px-6 font-black">Live Dispatch Status</th>
                                <th className="py-5 px-6 font-black text-center">Biometric Clearance</th>
                                <th className="py-5 px-6 font-black text-right sticky right-0 bg-slate-50/80 z-10">Revoke Access</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100 text-sm">
                            {loading ? (
                                <tr><td colSpan={5} className="py-24 text-center"><Loader2 className="animate-spin mx-auto text-red-500" size={32} /></td></tr>
                            ) : filteredResponders.length === 0 ? (
                                <tr><td colSpan={5} className="py-24 text-center text-slate-400 font-bold uppercase tracking-widest italic">No responders assigned.</td></tr>
                            ) : filteredResponders.map((staff: any) => {
                                const currentEmergency = activeEmergencies.find(e => e.resolved_by === staff.id);

                                return (
                                    <tr key={staff.id} className="hover:bg-slate-50/50 transition-all group">
                                        <td className="py-4 px-6 flex items-center gap-3">
                                            {/* Render the encrypted face safely if your backend handles it */}
                                            <div className="w-10 h-10 rounded-full bg-slate-200 overflow-hidden border border-slate-300">
                                                {staff.face_url ? (
                                                    <img src="/placeholder-secure-avatar.png" alt="encrypted" className="w-full h-full object-cover opacity-50" title="Face Data Encrypted"/>
                                                ) : (
                                                    <div className="w-full h-full flex items-center justify-center text-slate-400 font-bold">{staff.name[0]}</div>
                                                )}
                                            </div>
                                            <div>
                                                <div className="font-black text-slate-900 text-base">{staff.name} {staff.surname}</div>
                                                <div className="text-[10px] text-red-400 font-bold uppercase mt-1 tracking-widest">ID: {staff.id.split('-')[0]}</div>
                                            </div>
                                        </td>
                                        
                                        <td className="py-4 px-6">
                                            <div className="text-xs font-bold text-slate-700">{staff.email}</div>
                                            <div className="text-[10px] text-slate-400 font-medium mt-1">{staff.phone}</div>
                                        </td>
                                        
                                        <td className="py-4 px-6">
                                            {currentEmergency ? (
                                                <div className="flex flex-col gap-1">
                                                    <span className="inline-flex w-fit items-center gap-1.5 text-[9px] font-black tracking-widest uppercase text-red-600 bg-red-50 border border-red-100 px-2.5 py-1 rounded-lg">
                                                        <Siren size={12} className="animate-pulse" /> Responding to Alert #{currentEmergency.id.substring(0,6)}
                                                    </span>
                                                    <span className="text-[9px] font-bold text-slate-400 ml-1">
                                                        Target Lat: {currentEmergency.latitude.toFixed(4)}
                                                    </span>
                                                </div>
                                            ) : (
                                                <span className="inline-flex items-center gap-1.5 text-[9px] font-black tracking-widest uppercase text-emerald-600 bg-emerald-50 border border-emerald-100 px-2.5 py-1 rounded-lg">
                                                    <CheckCircle2 size={12} /> On Standby
                                                </span>
                                            )}
                                        </td>
                                        
                                        <td className="py-4 px-6 text-center">
                                            {staff.face_url ? (
                                                <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-slate-100 text-slate-600 rounded-lg text-[9px] font-black border border-slate-200 tracking-widest uppercase">
                                                    <Activity size={10}/> DUAL-SCAN ACTIVE
                                                </span>
                                            ) : (
                                                <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-amber-50 text-amber-600 rounded-lg text-[9px] font-black border border-amber-200 tracking-widest uppercase">
                                                    MISSING BIOMETRICS
                                                </span>
                                            )}
                                        </td>
                                        
                                        <td className="py-4 px-6 text-right sticky right-0 bg-white group-hover:bg-slate-50/50 transition-all border-l border-slate-100">
                                            <button 
                                                onClick={() => handleDelete(staff.id, staff.name)}
                                                className="p-2 text-slate-300 hover:text-red-600 hover:bg-red-50 rounded-xl shadow-sm transition-all"
                                                title="Remove Responder"
                                            >
                                                <Trash2 size={18}/>
                                            </button>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            </div>

            {isModalOpen && (
                <AddMedicalResponderModal onClose={() => setIsModalOpen(false)} onSuccess={() => { setIsModalOpen(false); fetchRespondersAndEmergencies(); }} />
            )}
        </div>
    );
}

// --- ADD MEDICAL RESPONDER MODAL ---
function AddMedicalResponderModal({ onClose, onSuccess }: any) {
    const [formData, setFormData] = useState<any>({});
    const [faceImage, setFaceImage] = useState<File | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const fileInputRef = useRef<HTMLInputElement>(null);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault(); 
        
        if (!faceImage) {
            setError("Facial biometric scan is strictly required for the Dual-Scan protocol.");
            return;
        }

        setLoading(true); 
        setError('');

        try {
            // Using FormData for Multipart File Upload
            const payload = new FormData();
            payload.append('name', formData.name);
            payload.append('surname', formData.surname);
            payload.append('id_number', formData.id_number);
            payload.append('email', formData.email);
            payload.append('phone', formData.phone);
            payload.append('face_image', faceImage); 

            // Because it's FormData, apiFetch must not JSON.stringify it.
            // Ensure your apiFetch strips 'Content-Type' headers when body is FormData.
            await apiFetch('/add-medical-responder/', { 
                method: 'POST', 
                body: payload,
                isMultipart: true // Optional flag if your apiFetch helper requires it to bypass JSON stringification
            });
            
            onSuccess();
        } catch (err: any) { 
            setError(err.message || 'System failed to provision account or encrypt biometrics.'); 
        } finally { 
            setLoading(false); 
        }
    };

    return (
        <ModalWrapper title="Provision Medical Responder" onClose={onClose}>
            <form onSubmit={handleSubmit} className="space-y-4">
                {error && (
                    <div className="p-3 bg-red-50 text-red-600 text-[10px] font-black uppercase tracking-widest border border-red-100 rounded-xl flex items-center gap-2">
                        <AlertCircle size={14}/>{error}
                    </div>
                )}
                
                <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 mb-4">
                    <p className="text-xs font-bold text-slate-600 flex items-center gap-2">
                        <HeartPulse size={14} className="text-red-500" />
                        Requires live facial capture. Data will be encrypted in transit and at rest.
                    </p>
                </div>

                <div className="grid grid-cols-2 gap-3">
                    <Input label="First Name" value={formData.name || ''} onChange={(e:any) => setFormData({...formData, name: e.target.value})} required />
                    <Input label="Surname" value={formData.surname || ''} onChange={(e:any) => setFormData({...formData, surname: e.target.value})} required />
                </div>
                <Input label="Identity Number (Password Source)" onChange={(e:any) => setFormData({...formData, id_number: e.target.value})} required />
                <Input label="Corporate Email" type="email" value={formData.email || ''} onChange={(e:any) => setFormData({...formData, email: e.target.value})} required />
                <Input label="Contact Number" value={formData.phone || ''} onChange={(e:any) => setFormData({...formData, phone: e.target.value})} required />
                
                {/* Facial Biometric Upload */}
                <div className="space-y-2 pt-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Biometric Reference Image</label>
                    <div 
                        onClick={() => fileInputRef.current?.click()}
                        className="w-full border-2 border-dashed border-slate-200 rounded-2xl p-6 flex flex-col items-center justify-center cursor-pointer hover:bg-slate-50 hover:border-red-200 transition-all"
                    >
                        <Camera size={24} className={faceImage ? "text-emerald-500" : "text-slate-400"} />
                        <span className="text-xs font-bold text-slate-600 mt-2">
                            {faceImage ? faceImage.name : "Click to select facial scan image"}
                        </span>
                        <input 
                            type="file" 
                            accept="image/jpeg, image/png"
                            className="hidden" 
                            ref={fileInputRef}
                            onChange={(e) => {
                                if (e.target.files && e.target.files.length > 0) {
                                    setFaceImage(e.target.files[0]);
                                }
                            }}
                        />
                    </div>
                </div>

                <div className="pt-4">
                    <SubmitButton loading={loading} text="Authorize Responder" />
                </div>
            </form>
        </ModalWrapper>
    );
}