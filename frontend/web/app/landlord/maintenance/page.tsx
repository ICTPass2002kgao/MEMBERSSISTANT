"use client";

import React, { useState, useEffect } from 'react';
import { Loader2, AlertCircle, CheckCircle2, MapPin, Wrench, Clock, CreditCard, Key, UserPlus, User } from 'lucide-react';
import { apiFetch } from '../../components/api'; 
import { SectionHeader, ModalWrapper, Select, SubmitButton } from '../../components/SharedUI';

export default function MaintenancePage() {
    const [issues, setIssues] = useState<any[]>([]);
    const [attendants, setAttendants] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    // Assignment Modal State
    const [issueToAssign, setIssueToAssign] = useState<any | null>(null);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [issuesData, attendantsData] = await Promise.all([
                apiFetch('/issues/'),
                apiFetch('/attendants/')
            ]);
            
            let fetchedIssues = issuesData.results || issuesData || [];
            let fetchedAttendants = attendantsData.results || attendantsData || [];
            
            // Sort Priority first, then newest
            fetchedIssues.sort((a: any, b: any) => {
                if (a.is_priority && !b.is_priority) return -1;
                if (!a.is_priority && b.is_priority) return 1;
                return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
            });

            setIssues(fetchedIssues);
            setAttendants(fetchedAttendants);
        } catch (error) { 
            console.error("Failed to fetch maintenance data:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { 
        fetchData(); 
    }, []);

    const updateIssueStatus = async (id: string, newStatus: string) => {
        try {
            await apiFetch(`/issues/${id}/`, { 
                method: 'PATCH', 
                body: JSON.stringify({ status: newStatus }) 
            });
            fetchData(); 
        } catch (error) { 
            console.error("Failed to update status"); 
        }
    };

    const formatDate = (isoString?: string | null) => {
        if (!isoString) return { date: 'N/A', time: '' };
        const date = new Date(isoString);
        return {
            date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
            time: date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
        };
    };

    const getAttendantName = (assignedData: any) => {
        if (!assignedData) return null;
        
        // 1. If Django returns the whole attendant object
        if (typeof assignedData === 'object' && assignedData.name) {
            return `${assignedData.name} ${assignedData.surname}`;
        }
        
        // 2. If Django returns just the ID (UUID String)
        const attendantId = typeof assignedData === 'object' ? assignedData.id : assignedData;
        const attendant = attendants.find(a => a.id === attendantId);
        return attendant ? `${attendant.name} ${attendant.surname}` : 'Unknown Staff';
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-300">
            <SectionHeader title="Active Maintenance Tickets" />
            
            <div className="bg-white border border-blue-100 rounded-[24px] shadow-sm overflow-hidden">
                {/* Horizontal scroll container for the expanded table */}
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1200px]">
                        <thead className="bg-blue-50/50 border-b border-blue-100 text-slate-500 text-[10px] uppercase tracking-widest whitespace-nowrap">
                            <tr>
                                <th className="py-5 px-6 font-bold w-24">Date & Time</th>
                                <th className="py-5 px-4 font-bold w-40">Resident</th>
                                <th className="py-5 px-4 font-bold w-48">Location</th>
                                <th className="py-5 px-4 font-bold w-48">Issue Title</th>
                                <th className="py-5 px-6 font-bold min-w-[200px]">Description</th>
                                <th className="py-5 px-4 font-bold w-36">Status</th>
                                <th className="py-5 px-4 font-bold w-40">Assigned Staff</th>
                                <th className="py-5 px-6 text-right font-bold w-40">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {loading && (
                                <tr>
                                    <td colSpan={8} className="py-12 text-center">
                                        <Loader2 className="animate-spin mx-auto text-blue-500" />
                                    </td>
                                </tr>
                            )}
                            {!loading && issues.length === 0 && (
                                <tr>
                                    <td colSpan={8} className="py-16 text-center">
                                        <CheckCircle2 size={48} className="mx-auto text-emerald-400 mb-4 opacity-50" />
                                        <p className="text-blue-950 font-bold">All systems operational</p>
                                        <p className="text-slate-500 text-xs mt-1">No active maintenance issues reported.</p>
                                    </td>
                                </tr>
                            )}
                            {!loading && issues.map((issue: any) => {
                                let displayDesc = issue.description || '';
                                const match = displayDesc.match(/^\[Location: (.*?)\]\n/);
                                if (match) displayDesc = displayDesc.substring(match[0].length);
                                
                                const assignedName = getAttendantName(issue.assigned_attendant);
                                const { date, time } = formatDate(issue.created_at);

                                return (
                                    <tr key={issue.id} className="hover:bg-blue-50/30 transition-colors text-sm">
                                        
                                        {/* 1. Date & Time */}
                                        <td className="py-4 px-6 align-middle whitespace-nowrap">
                                            <div className="font-bold text-slate-700">{date}</div>
                                            <div className="text-[10px] text-slate-400 mt-0.5 flex items-center gap-1"><Clock size={10} /> {time}</div>
                                        </td>

                                        {/* 2. Resident */}
                                        <td className="py-4 px-4 align-middle whitespace-nowrap">
                                            <p className="font-black text-blue-950">{issue.student_name}</p>
                                            <p className="font-medium text-slate-500 text-xs">{issue.student_surname}</p>
                                        </td>

                                        {/* 3. Location */}
                                        <td className="py-4 px-4 align-middle">
                                            <div className="flex flex-col gap-1 w-fit">
                                                <span className="text-[10px] font-bold text-slate-600 bg-slate-100 px-2 py-0.5 rounded uppercase tracking-wider">
                                                    Block {issue.block_name || 'N/A'}
                                                </span>
                                                {issue.unit_name && (
                                                    <span className="text-[10px] font-bold text-purple-600 bg-purple-50 px-2 py-0.5 rounded uppercase tracking-wider">
                                                        Unit {issue.unit_name}
                                                    </span>
                                                )}
                                                <span className="text-[10px] font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded uppercase tracking-wider">
                                                    Room {issue.room_number || 'N/A'}
                                                </span>
                                            </div>
                                        </td>

                                        {/* 4. Issue Title */}
                                        <td className="py-4 px-4 align-middle font-bold text-blue-900">
                                            {issue.custom_issue_title}
                                            {issue.is_priority && (
                                                <div className="flex w-fit items-center gap-1 mt-1 text-[9px] font-black tracking-widest text-rose-600 bg-rose-50 px-1.5 py-0.5 rounded uppercase">
                                                    <AlertCircle size={10} /> Priority
                                                </div>
                                            )}
                                        </td>

                                        {/* 5. Description */}
                                        <td className="py-4 px-6 align-middle">
                                            <p className="text-xs text-slate-500 line-clamp-3 leading-relaxed max-w-xs" title={displayDesc}>
                                                {displayDesc}
                                            </p>
                                        </td>

                                        {/* 6. Status */}
                                        <td className="py-4 px-4 align-middle whitespace-nowrap">
                                            <span className={`flex w-fit items-center gap-1.5 text-[10px] font-black tracking-widest px-2 py-1 rounded-md border shadow-sm uppercase ${
                                                issue.status === 'RESOLVED' ? 'bg-emerald-50 text-emerald-600 border-emerald-200' :
                                                issue.status === 'ATTENDING' ? 'bg-blue-50 text-blue-600 border-blue-200' :
                                                issue.status === 'AWAITING_PAYMENT' ? 'bg-orange-50 text-orange-600 border-orange-200' :
                                                issue.status === 'READY_FOR_COLLECTION' ? 'bg-purple-50 text-purple-600 border-purple-200' :
                                                'bg-amber-50 text-amber-600 border-amber-200'
                                            }`}>
                                                {issue.status === 'AWAITING_PAYMENT' && <CreditCard size={12} />}
                                                {issue.status === 'READY_FOR_COLLECTION' && <Key size={12} />}
                                                {issue.status.replace('_', ' ')}
                                            </span>
                                        </td>

                                        {/* 7. Assigned Staff */}
                                        <td className="py-4 px-4 align-middle whitespace-nowrap">
                                            {assignedName ? (
                                                <div className="flex items-center gap-1.5 text-xs font-bold text-slate-700">
                                                    <div className="p-1.5 bg-slate-100 rounded-md text-slate-500"><User size={12} /></div>
                                                    {assignedName}
                                                </div>
                                            ) : (
                                                <span className="text-xs italic text-slate-400">Unassigned</span>
                                            )}
                                        </td>

                                        {/* 8. Actions */}
                                        <td className="py-4 px-6 text-right align-middle">
                                            {issue.status === 'PENDING' && (
                                                <button onClick={() => setIssueToAssign(issue)} className="text-[9px] font-bold tracking-widest text-white bg-blue-600 hover:bg-blue-500 px-3 py-2 rounded-lg shadow-sm w-full flex items-center justify-center gap-1.5 uppercase">
                                                    <UserPlus size={12}/> Assign
                                                </button>
                                            )}
                                            {issue.status === 'ATTENDING' && (
                                                <button onClick={() => updateIssueStatus(issue.id, 'RESOLVED')} className="text-[9px] font-bold tracking-widest text-emerald-700 bg-emerald-50 hover:bg-emerald-100 border border-emerald-200 px-3 py-2 rounded-lg shadow-sm w-full flex items-center justify-center gap-1.5 uppercase">
                                                    <CheckCircle2 size={12}/> Resolve
                                                </button>
                                            )}
                                            {issue.status === 'AWAITING_PAYMENT' && (
                                                <span className="text-[10px] text-orange-500 font-bold block text-center">Waiting...</span>
                                            )}
                                            {issue.status === 'READY_FOR_COLLECTION' && (
                                                <button onClick={() => updateIssueStatus(issue.id, 'RESOLVED')} className="text-[9px] font-bold tracking-widest text-white bg-purple-600 hover:bg-purple-500 px-3 py-2 rounded-lg shadow-sm w-full flex items-center justify-center gap-1.5 uppercase">
                                                    <Key size={12}/> Handover
                                                </button>
                                            )}
                                            {issue.status === 'RESOLVED' && (
                                                <div className="flex items-center gap-1 text-emerald-500 font-bold text-xs justify-end">
                                                    <CheckCircle2 size={14} /> Done
                                                </div>
                                            )}
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            </div>

            {issueToAssign && (
                <AssignAttendantModal 
                    issue={issueToAssign} 
                    attendants={attendants} 
                    onClose={() => setIssueToAssign(null)} 
                    onSuccess={() => { setIssueToAssign(null); fetchData(); }} 
                />
            )}
        </div>
    );
}

// ============================================================================
// ASSIGN ATTENDANT MODAL
// ============================================================================
function AssignAttendantModal({ issue, attendants, onClose, onSuccess }: any) {
    const [selectedAttendant, setSelectedAttendant] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    // STRICT ROLE FILTER: Only allow ATTENDANT roles
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
            await apiFetch(`/issues/${issue.id}/`, { 
                method: 'PATCH', 
                body: JSON.stringify({ 
                    status: 'ATTENDING', 
                    assigned_attendant: selectedAttendant,
                    assigned_attendant_id: selectedAttendant // FORCE Django to recognize the ID
                }) 
            });
            onSuccess();
        } catch (err: any) {
            setError(err.message || "Failed to assign attendant. Please try again.");
            setLoading(false);
        }
    };

    return (
        <ModalWrapper title="Delegate Maintenance Issue" onClose={onClose}>
            <form onSubmit={handleAssign} className="space-y-6">
                <div className="p-4 bg-slate-50 border border-slate-100 rounded-xl mb-4">
                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Issue Overview</p>
                    <p className="text-sm font-bold text-blue-950">{issue.custom_issue_title}</p>
                    <div className="mt-2 flex gap-2">
                        <span className="text-[10px] font-bold text-slate-600 bg-white border border-slate-200 px-2 py-1 rounded">Room {issue.room_number}</span>
                        <span className="text-[10px] font-bold text-slate-600 bg-white border border-slate-200 px-2 py-1 rounded">Block {issue.block_name}</span>
                    </div>
                </div>

                {error && <div className="p-3 bg-rose-50 text-rose-600 text-xs rounded-xl flex items-center gap-2"><AlertCircle size={16} /> {error}</div>}

                {availableStaff.length === 0 ? (
                    <div className="p-4 bg-amber-50 border border-amber-200 rounded-xl text-center">
                        <p className="text-amber-800 text-xs font-bold">No Room Attendants Available</p>
                        <p className="text-amber-700 text-[10px] mt-1">You need to add staff members with the "Room Attendant" role before delegating issues.</p>
                    </div>
                ) : (
                    <Select label="Assign to Maintenance Staff" value={selectedAttendant} onChange={(e: any) => setSelectedAttendant(e.target.value)} required>
                        <option value="">-- Select Room Attendant --</option>
                        {availableStaff.map((staff: any) => (
                            <option key={staff.id} value={staff.id}>{staff.name} {staff.surname}</option>
                        ))}
                    </Select>
                )}

                <SubmitButton loading={loading} text="CONFIRM ASSIGNMENT" disabled={availableStaff.length === 0} />
            </form>
        </ModalWrapper>
    );
}