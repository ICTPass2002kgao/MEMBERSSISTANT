"use client";

import React, { useState, useEffect, useMemo } from 'react';
import { 
  Plus, AlertCircle, Loader2, UserCog, Trash2, Star, 
  ShieldCheck, Wrench, HardHat, Hammer, CheckCircle2, 
  Search, Filter, X 
} from 'lucide-react';
import { apiFetch } from '../../components/api';
import { SectionHeader, ModalWrapper, Input, Select, SubmitButton } from '../../components/SharedUI';

export default function AttendantsPage() {
    const [attendants, setAttendants] = useState<any[]>([]);
    const [activeIssues, setActiveIssues] = useState<any[]>([]); 
    const [loading, setLoading] = useState(true);
    const [isModalOpen, setIsModalOpen] = useState(false);

    // --- SEARCH & FILTER STATES ---
    const [searchTerm, setSearchTerm] = useState("");
    const [roleFilter, setRoleFilter] = useState("");
    const [statusFilter, setStatusFilter] = useState(""); // "BUSY" or "AVAILABLE"

    const fetchAttendantsAndIssues = async () => {
        setLoading(true);
        try {
            const storedUser = JSON.parse(localStorage.getItem('user_data') || '{}');
            
            const [attendantsData, issuesData] = await Promise.all([
                apiFetch(`/attendants/?landlord__id=${storedUser.id}`),
                apiFetch('/issues/')
            ]);
            
            let fetchedList = attendantsData.results || attendantsData || [];
            let fetchedIssues = (issuesData.results || issuesData || []).filter((i: any) => i.status === 'ATTENDING');
            
            // Premium Sorting: Highest rating first
            fetchedList.sort((a: any, b: any) => (b.average_rating || 0) - (a.average_rating || 0));
            
            setAttendants(fetchedList);
            setActiveIssues(fetchedIssues);
        } catch (error) { 
            console.error("System Fetch Error:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { fetchAttendantsAndIssues(); }, []);

    // --- PRO FILTER ENGINE ---
    const filteredAttendants = useMemo(() => {
        return attendants.filter(staff => {
            const matchesSearch = 
                `${staff.name} ${staff.surname}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
                staff.email.toLowerCase().includes(searchTerm.toLowerCase());
            
            const matchesRole = roleFilter === "" || staff.role === roleFilter;

            const staffIsBusy = activeIssues.some(issue => issue.assigned_attendant === staff.id);
            const matchesStatus = statusFilter === "" || 
                (statusFilter === "BUSY" && staffIsBusy) || 
                (statusFilter === "AVAILABLE" && !staffIsBusy);

            return matchesSearch && matchesRole && matchesStatus;
        });
    }, [attendants, searchTerm, roleFilter, statusFilter, activeIssues]);

    const resetFilters = () => {
        setSearchTerm("");
        setRoleFilter("");
        setStatusFilter("");
    };

    const handleDelete = async (id: string, name: string) => {
        if (!window.confirm(`Revoke all system access for ${name}?`)) return;
        try {
            await apiFetch(`/attendants/${id}/`, { method: 'DELETE' });
            fetchAttendantsAndIssues(); 
        } catch (error) { alert("Failed to delete staff member."); }
    };

    const renderStars = (rating: number | null) => {
        if (!rating) return <span className="text-[10px] italic text-slate-400">Unrated</span>;
        return (
            <div className="flex items-center gap-1">
                {[1, 2, 3, 4, 5].map((star) => (
                    <Star key={star} size={12} className={star <= Math.round(rating) ? "text-amber-400 fill-amber-400" : "text-slate-200"} />
                ))}
                <span className="text-xs font-black text-slate-700 ml-1">{rating.toFixed(1)}</span>
            </div>
        );
    };

    const renderRoleBadge = (role: string) => {
        const styles: any = {
            SECURITY: "bg-blue-50 text-blue-600 border-blue-100",
            ATTENDANT: "bg-purple-50 text-purple-600 border-purple-100",
            GENERAL: "bg-slate-50 text-slate-600 border-slate-100"
        };
        const icons: any = {
            SECURITY: <ShieldCheck size={12}/>,
            ATTENDANT: <Wrench size={12}/>,
            GENERAL: <HardHat size={12}/>
        };
        return (
            <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border text-[9px] font-black tracking-widest uppercase ${styles[role] || styles.GENERAL}`}>
                {icons[role] || icons.GENERAL} {role.replace('_', ' ')}
            </span>
        );
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
            {/* Header */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="Staff Directory" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        Active Personnel: {filteredAttendants.length} / {attendants.length}
                    </p>
                </div>
                <button onClick={() => setIsModalOpen(true)} className="flex items-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-2xl text-[11px] font-black uppercase tracking-widest shadow-lg shadow-blue-600/20 transition-all active:scale-95">
                    <Plus size={16} /> Provision Staff
                </button>
            </div>

            {/* Glassmorphic Search & Filter Engine */}
            <div className="bg-white border border-blue-100 p-6 rounded-[28px] shadow-sm space-y-4">
                <div className="flex flex-col lg:flex-row gap-4">
                    <div className="relative flex-1">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300" size={18} />
                        <input 
                            type="text"
                            placeholder="Search staff by name or email..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full bg-blue-50/50 border border-blue-100 pl-12 pr-4 py-3.5 rounded-2xl text-sm outline-none focus:bg-white focus:border-blue-400 transition-all font-medium"
                        />
                    </div>

                    <div className="flex flex-wrap gap-2">
                        <select 
                            value={roleFilter} 
                            onChange={(e) => setRoleFilter(e.target.value)}
                            className="bg-white border border-blue-100 px-4 py-3 rounded-xl text-[11px] font-bold text-slate-500 outline-none focus:border-blue-400 transition-all min-w-[140px]"
                        >
                            <option value="">All Roles</option>
                            <option value="ATTENDANT">Attendants</option>
                            <option value="SECURITY">Security</option>
                            <option value="GENERAL">General Staff</option>
                        </select>

                        <select 
                            value={statusFilter} 
                            onChange={(e) => setStatusFilter(e.target.value)}
                            className="bg-white border border-blue-100 px-4 py-3 rounded-xl text-[11px] font-bold text-slate-500 outline-none focus:border-blue-400 transition-all min-w-[140px]"
                        >
                            <option value="">Any Status</option>
                            <option value="AVAILABLE">Available</option>
                            <option value="BUSY">Busy / Active</option>
                        </select>

                        <button onClick={resetFilters} className="p-3 text-slate-400 hover:text-rose-500 transition-all">
                            <X size={20} />
                        </button>
                    </div>
                </div>
            </div>

            {/* Main Staff Table */}
            <div className="bg-white border border-blue-100 rounded-[28px] shadow-sm overflow-hidden">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1200px]">
                        <thead className="bg-slate-50/50 border-b border-blue-50 text-slate-400 text-[10px] uppercase tracking-[0.2em]">
                            <tr>
                                <th className="py-5 px-6 font-black">Staff Member</th>
                                <th className="py-5 px-6 font-black">Role</th>
                                <th className="py-5 px-6 font-black">Contact Details</th>
                                <th className="py-5 px-6 font-black">Live Status</th>
                                <th className="py-5 px-6 font-black text-center">Performance</th>
                                <th className="py-5 px-6 font-black text-center">Lifetime Jobs</th>
                                <th className="py-5 px-6 font-black text-right sticky right-0 bg-white">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-blue-50 text-sm">
                            {loading ? (
                                <tr><td colSpan={7} className="py-24 text-center"><Loader2 className="animate-spin mx-auto text-blue-500" size={32} /></td></tr>
                            ) : filteredAttendants.length === 0 ? (
                                <tr><td colSpan={7} className="py-24 text-center text-slate-400 font-bold uppercase tracking-widest italic">No personnel found.</td></tr>
                            ) : filteredAttendants.map((staff: any) => {
                                const staffActiveJobs = activeIssues.filter(issue => issue.assigned_attendant === staff.id);
                                const isBusy = staffActiveJobs.length > 0;

                                return (
                                    <tr key={staff.id} className="hover:bg-blue-50/30 transition-all group">
                                        <td className="py-4 px-6">
                                            <div className="font-black text-blue-950 text-base">{staff.name} {staff.surname}</div>
                                            <div className="text-[10px] text-blue-400 font-bold uppercase mt-1 tracking-widest">ID: {staff.id.split('-')[0]}</div>
                                        </td>
                                        
                                        <td className="py-4 px-6">{renderRoleBadge(staff.role)}</td>
                                        
                                        <td className="py-4 px-6">
                                            <div className="text-xs font-bold text-slate-600">{staff.email}</div>
                                            <div className="text-[10px] text-slate-400 font-medium mt-1">{staff.phone}</div>
                                        </td>
                                        
                                        <td className="py-4 px-6">
                                            {isBusy ? (
                                                <div className="flex flex-col gap-1">
                                                    <span className="inline-flex items-center gap-1.5 text-[9px] font-black tracking-widest uppercase text-rose-600 bg-rose-50 border border-rose-100 px-2.5 py-1 rounded-lg">
                                                        <Hammer size={12} className="animate-pulse" /> Resolving Room {staffActiveJobs[0].room_number}
                                                    </span>
                                                </div>
                                            ) : (
                                                <span className="inline-flex items-center gap-1.5 text-[9px] font-black tracking-widest uppercase text-emerald-600 bg-emerald-50 border border-emerald-100 px-2.5 py-1 rounded-lg">
                                                    <CheckCircle2 size={12} /> Ready for Dispatch
                                                </span>
                                            )}
                                        </td>
                                        
                                        <td className="py-4 px-6 flex justify-center">{renderStars(staff.average_rating)}</td>
                                        
                                        <td className="py-4 px-6 text-center">
                                            <span className="px-3 py-1 bg-blue-50 text-blue-600 rounded-lg text-[10px] font-black border border-blue-100">
                                                {staff.resolved_issues_count || 0}
                                            </span>
                                        </td>
                                        
                                        <td className="py-4 px-6 text-right sticky right-0 bg-white group-hover:bg-blue-50/10 transition-all border-l border-blue-50">
                                            <button 
                                                onClick={() => handleDelete(staff.id, staff.name)}
                                                className="p-2 text-slate-300 hover:text-rose-600 hover:bg-white rounded-xl shadow-sm transition-all"
                                            >
                                                <Trash2 size={16}/>
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
                <AddAttendantModal onClose={() => setIsModalOpen(false)} onSuccess={() => { setIsModalOpen(false); fetchAttendantsAndIssues(); }} />
            )}
        </div>
    );
}

// --- ADD STAFF MODAL ---
function AddAttendantModal({ onClose, onSuccess }: any) {
    const [formData, setFormData] = useState<any>({ role: 'ATTENDANT' });
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault(); 
        setLoading(true); 
        setError('');

        try {
            await apiFetch('/add-attendant/', { method: 'POST', body: JSON.stringify(formData) });
            onSuccess();
        } catch (err: any) { 
            setError(err.message || 'System failed to provision account.'); 
        } finally { 
            setLoading(false); 
        }
    };

    return (
        <ModalWrapper title="Provision Staff Account" onClose={onClose}>
            <form onSubmit={handleSubmit} className="space-y-4">
                {error && <div className="p-3 bg-rose-50 text-rose-600 text-[10px] font-black uppercase tracking-widest border border-rose-100 rounded-xl flex items-center gap-2"><AlertCircle size={14}/>{error}</div>}
                
                <div className="grid grid-cols-2 gap-3">
                    <Input label="First Name" value={formData.name || ''} onChange={(e:any) => setFormData({...formData, name: e.target.value})} required />
                    <Input label="Surname" value={formData.surname || ''} onChange={(e:any) => setFormData({...formData, surname: e.target.value})} required />
                </div>
                <Input label="Identity Number (Password Source)" onChange={(e:any) => setFormData({...formData, id_number: e.target.value})} required />
                <Input label="Corporate Email" type="email" value={formData.email || ''} onChange={(e:any) => setFormData({...formData, email: e.target.value})} required />
                <Input label="Contact Number" value={formData.phone || ''} onChange={(e:any) => setFormData({...formData, phone: e.target.value})} required />
                
                <Select label="System Access Level" value={formData.role} onChange={(e:any) => setFormData({...formData, role: e.target.value})} required>
                    <option value="ATTENDANT">Room Attendant (Maintenance Hub)</option>
                    <option value="SECURITY">Security Officer (Gate & Biometrics)</option>
                    <option value="GENERAL">General Administrative Staff</option>
                </Select>

                <SubmitButton loading={loading} text="Authorize & Register" />
            </form>
        </ModalWrapper>
    );
}