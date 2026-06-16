"use client";

import React, { useState, useEffect } from 'react';
import { Loader2, Clock, ShieldCheck, AlertTriangle, CheckCircle2, XCircle, MapPin, Phone, User, Home, UserPlus } from 'lucide-react';
import { apiFetch } from '../../components/api';
import { SectionHeader, ModalWrapper, Select, SubmitButton } from '../../components/SharedUI';

export default function PermitsPage() {
    const [permits, setPermits] = useState<any[]>([]);
    const [attendants, setAttendants] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    // Assignment Modal State
    const [permitToAssign, setPermitToAssign] = useState<any | null>(null);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [permitsData, attendantsData] = await Promise.all([
                apiFetch('/leave-permits/'),
                apiFetch('/attendants/')
            ]);
            
            setPermits(permitsData.results || permitsData || []);
            setAttendants(attendantsData.results || attendantsData || []);
        } catch (error) { 
            console.error(error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { 
        fetchData(); 
    }, []);

    const getStatusBadge = (status: string) => {
        const styles: any = {
            'APPROVED': "bg-emerald-50 text-emerald-600 border-emerald-200",
            'DENIED': "bg-rose-50 text-rose-600 border-rose-200",
            'INSPECTING': "bg-amber-50 text-amber-600 border-amber-200",
            'REQUESTED': "bg-blue-50 text-blue-600 border-blue-200"
        };
        const icons: any = {
            'APPROVED': <CheckCircle2 size={12}/>,
            'DENIED': <XCircle size={12}/>,
            'INSPECTING': <AlertTriangle size={12}/>,
            'REQUESTED': <ShieldCheck size={12}/>
        };
        return (
            <span className={`flex w-fit items-center gap-1.5 text-[9px] font-black px-2.5 py-1.5 rounded-md border tracking-widest uppercase shadow-sm ${styles[status] || styles['REQUESTED']}`}>
                {icons[status] || icons['REQUESTED']} {status}
            </span>
        );
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-300">
            <SectionHeader title="Exit Permit Authorizations" />
            
            {loading ? (
                <div className="flex justify-center py-20"><Loader2 className="animate-spin text-blue-500" size={40} /></div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {permits.length === 0 && (
                        <div className="col-span-full py-20 text-center">
                            <ShieldCheck size={48} className="mx-auto text-slate-300 mb-4 opacity-50" />
                            <p className="text-blue-950 font-bold">No Permits Requested</p>
                            <p className="text-slate-500 text-xs mt-1">Students have not requested any leave permits yet.</p>
                        </div>
                    )}

                    {permits.map((p: any) => (
                        <div key={p.id} className="bg-white border border-blue-100 rounded-2xl p-6 hover:shadow-md transition-all flex flex-col h-full shadow-sm relative overflow-hidden">
                            <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-blue-400 to-blue-600"></div>

                            {/* Header: Status & Date */}
                            <div className="flex justify-between items-start mb-4 mt-1">
                                {getStatusBadge(p.status)}
                                <div className="text-right">
                                    <span className="text-[10px] font-bold text-slate-500 flex items-center justify-end gap-1.5 uppercase tracking-tighter">
                                        <Clock size={12} className="text-blue-500"/> 
                                        {new Date(p.departure_date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                    </span>
                                    <span className="text-[9px] text-slate-400 font-medium">{new Date(p.departure_date).toLocaleDateString()}</span>
                                </div>
                            </div>

                            {/* Student Info Section */}
                            <div className="mb-5 p-3 bg-slate-50 rounded-xl border border-slate-100">
                                <div className="flex items-center gap-3 mb-2">
                                    <div className="h-8 w-8 rounded-full bg-blue-600 flex items-center justify-center text-white text-xs font-bold">
                                        {p.student_details?.name?.charAt(0) || <User size={14}/>}
                                    </div>
                                    <div>
                                        <h4 className="text-sm font-black text-blue-950 leading-none">{p.student_details?.name || "Unknown Student"}</h4>
                                        <p className="text-[10px] text-slate-500 font-bold mt-1 flex items-center gap-1 uppercase">
                                            <Home size={10}/> {p.student_details?.room_number_only || "Room N/A"} • {p.student_details?.block_name || "No Block"}
                                        </p>
                                    </div>
                                </div>
                            </div>

                            {/* Destination & Contact Details */}
                            <div className="space-y-3 mb-6 flex-1">
                                <div className="flex gap-3">
                                    <MapPin size={14} className="text-blue-500 mt-1 shrink-0"/>
                                    <div>
                                        <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Destination</p>
                                        <p className="text-xs font-bold text-slate-700">{p.destination_address}, {p.destination_province}</p>
                                    </div>
                                </div>
                                <div className="flex gap-3">
                                    <Phone size={14} className="text-blue-500 mt-1 shrink-0"/>
                                    <div>
                                        <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Guardian Contact</p>
                                        <p className="text-xs font-bold text-slate-700">{p.parent_cell_number}</p>
                                    </div>
                                </div>

                                <div className="bg-blue-50/50 p-4 rounded-xl border border-blue-100 relative mt-4">
                                    <div className="absolute top-0 left-4 -translate-y-1/2 bg-white border border-blue-100 px-2.5 py-0.5 text-[8px] font-bold text-blue-500 uppercase tracking-widest rounded-full shadow-sm">Reason</div>
                                    <p className="text-xs text-slate-600 italic leading-relaxed pt-1">"{p.reason}"</p>
                                </div>
                            </div>

                            {/* Actions */}
                            <div className="mt-auto pt-4 border-t border-slate-100">
                                {p.status === 'REQUESTED' ? (
                                    <button 
                                        onClick={() => setPermitToAssign(p)}
                                        className="w-full py-3 bg-blue-600 hover:bg-blue-500 text-white text-[10px] font-black tracking-widest uppercase rounded-xl transition-all shadow-md active:scale-[0.98] flex items-center justify-center gap-2"
                                    >
                                        <UserPlus size={14} /> Assign to Staff
                                    </button>
                                ) : p.status === 'INSPECTING' ? (
                                    <div className="w-full py-3 text-center text-[10px] font-black tracking-widest uppercase rounded-xl border border-amber-200 bg-amber-50 text-amber-600 flex justify-center items-center gap-2">
                                        <AlertTriangle size={14} /> Awaiting Inspection
                                    </div>
                                ) : (
                                    <div className="w-full py-3 text-center text-[10px] font-black tracking-widest uppercase rounded-xl border border-slate-200 bg-slate-50 text-slate-400">
                                        Processed ({p.status})
                                    </div>
                                )}
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* ASSIGNMENT MODAL */}
            {permitToAssign && (
                <AssignPermitModal 
                    permit={permitToAssign} 
                    attendants={attendants} 
                    onClose={() => setPermitToAssign(null)} 
                    onSuccess={() => { setPermitToAssign(null); fetchData(); }} 
                />
            )}
        </div>
    );
}

// ============================================================================
// ASSIGN PERMIT MODAL
// ============================================================================
function AssignPermitModal({ permit, attendants, onClose, onSuccess }: any) {
    const [selectedAttendant, setSelectedAttendant] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    // STRICT ROLE FILTER: Only allow ATTENDANT roles for room inspections
    const availableStaff = attendants.filter((a: any) => a.role === 'ATTENDANT');

    const handleAssign = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError('');

        if (!selectedAttendant) {
            setError("Please select a staff member to assign.");
            setLoading(false);
            return;
        }

        try {
            await apiFetch(`/leave-permits/${permit.id}/`, { 
                method: 'PATCH', 
                body: JSON.stringify({ 
                    status: 'INSPECTING', 
                    assigned_attendant: selectedAttendant // Note: See backend requirement below
                }) 
            });
            onSuccess();
        } catch (err: any) {
            setError(err.message || "Failed to delegate inspection. Please try again.");
            setLoading(false);
        }
    };

    return (
        <ModalWrapper title="Delegate Room Inspection" onClose={onClose}>
            <form onSubmit={handleAssign} className="space-y-6">
                <div className="p-4 bg-slate-50 border border-slate-100 rounded-xl mb-4">
                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Inspection Details</p>
                    <p className="text-sm font-bold text-blue-950">
                        {permit.student_details?.name || "Student"} requires exit clearance.
                    </p>
                    <div className="mt-2 flex gap-2">
                        <span className="text-[10px] font-bold text-slate-600 bg-white border border-slate-200 px-2 py-1 rounded">
                            Room {permit.student_details?.room_number_only || "N/A"}
                        </span>
                        <span className="text-[10px] font-bold text-slate-600 bg-white border border-slate-200 px-2 py-1 rounded">
                            Block {permit.student_details?.block_name || "N/A"}
                        </span>
                    </div>
                </div>

                {error && <div className="p-3 bg-rose-50 text-rose-600 text-xs rounded-xl flex items-center gap-2"><AlertTriangle size={16} /> {error}</div>}

                {availableStaff.length === 0 ? (
                    <div className="p-4 bg-amber-50 border border-amber-200 rounded-xl text-center">
                        <p className="text-amber-800 text-xs font-bold">No Room Attendants Available</p>
                        <p className="text-amber-700 text-[10px] mt-1">You need to add staff members with the "Room Attendant" role before delegating exit inspections.</p>
                    </div>
                ) : (
                    <Select label="Assign to Maintenance Staff" value={selectedAttendant} onChange={(e: any) => setSelectedAttendant(e.target.value)} required>
                        <option value="">-- Select Room Attendant --</option>
                        {availableStaff.map((staff: any) => (
                            <option key={staff.id} value={staff.id}>{staff.name} {staff.surname}</option>
                        ))}
                    </Select>
                )}

                <SubmitButton loading={loading} text="DELEGATE INSPECTION" disabled={availableStaff.length === 0} />
            </form>
        </ModalWrapper>
    );
}