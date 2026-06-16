"use client";

import React, { useState, useEffect, useMemo } from 'react';
import { 
  Plus, AlertCircle, CheckCircle2, Loader2, User, 
  Edit2, Trash2, Search, X, Filter, Building2 
} from 'lucide-react';
import { apiFetch } from '../../components/api';
import { SectionHeader, ModalWrapper, Input, Select, SubmitButton } from '../../components/SharedUI';

// --- MAIN DIRECTORY PAGE ---
export default function StudentsPage() {
    const [students, setStudents] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    
    // Filter & Search States
    const [searchTerm, setSearchTerm] = useState("");
    const [propertyFilter, setPropertyFilter] = useState("");
    const [blockFilter, setBlockFilter] = useState("");
    const [roomNumberFilter, setRoomNumberFilter] = useState("");

    // Property Data for Filters
    const [accommodations, setAccommodations] = useState<any[]>([]);
    const [blocks, setBlocks] = useState<any[]>([]);

    // Modal Management
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [studentToEdit, setStudentToEdit] = useState<any | null>(null);

    const fetchStudents = async () => {
        setLoading(true);
        try {
            const [sData, aData, bData] = await Promise.all([
                apiFetch('/students/'),
                apiFetch('/accommodations/'),
                apiFetch('/blocks/')
            ]);
            
            const fetchedStudents = sData.results || sData || [];
            
            // STRICT FILTER: Only show students who are officially placed in a room 
            // OR have been explicitly verified/accepted by the landlord and are awaiting onboarding.
            const validResidents = fetchedStudents.filter((s: any) => 
                s.room !== null || s.verification_status === true
            );

            setStudents(validResidents);
            setAccommodations(aData.results || aData || []);
            setBlocks(bData.results || bData || []);
        } catch (error) { 
            console.error("System Fetch Error:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { fetchStudents(); }, []);

    // --- SEARCH & FILTER LOGIC ---
    const filteredStudents = useMemo(() => {
        return students.filter(s => {
            const matchesSearch = 
                `${s.name} ${s.surname}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
                s.student_number.toLowerCase().includes(searchTerm.toLowerCase());
            
            const matchesProperty = propertyFilter === "" || s.accommodation_name === accommodations.find(a => a.id === propertyFilter)?.name;
            const matchesBlock = blockFilter === "" || s.block_name === blocks.find(b => b.id === blockFilter)?.name;
            const matchesRoom = roomNumberFilter === "" || (s.room_number_only && s.room_number_only.includes(roomNumberFilter));

            return matchesSearch && matchesProperty && matchesBlock && matchesRoom;
        });
    }, [students, searchTerm, propertyFilter, blockFilter, roomNumberFilter, accommodations, blocks]);

    const toggleClearance = async (id: string, current: boolean) => {
        try {
            await apiFetch(`/students/${id}/`, { 
                method: 'PATCH', 
                body: JSON.stringify({ is_cleared_for_exit: !current }) 
            });
            fetchStudents();
        } catch (error) { console.error("Toggle failed"); }
    };

    const handleDelete = async (id: string, name: string) => {
        if (!window.confirm(`Warning: This will permanently delete ${name} and their system access.`)) return;
        try {
            await apiFetch(`/students/${id}/`, { method: 'DELETE' });
            fetchStudents(); 
        } catch (error) { console.error(error); }
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
            {/* Header Section */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="Resident Directory" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        System Tracking: {filteredStudents.length} Verified Records
                    </p>
                </div>
                <button 
                    onClick={() => { setStudentToEdit(null); setIsModalOpen(true); }} 
                    className="flex items-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-2xl text-[11px] font-black uppercase tracking-[0.2em] transition-all shadow-lg shadow-blue-600/20 active:scale-95"
                >
                    <Plus size={16} /> Add New Resident
                </button>
            </div>

            {/* Glassmorphic Search & Filter Engine */}
            <div className="bg-white border border-blue-100 p-6 rounded-[28px] shadow-sm space-y-4">
                <div className="flex flex-col lg:flex-row gap-4">
                    <div className="relative flex-1">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300" size={18} />
                        <input 
                            type="text"
                            placeholder="Lookup by name or student number..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full bg-blue-50/50 border border-blue-100 pl-12 pr-4 py-3.5 rounded-2xl text-sm outline-none focus:bg-white focus:border-blue-400 transition-all"
                        />
                    </div>

                    <div className="flex flex-wrap gap-2">
                        <select 
                            value={propertyFilter} 
                            onChange={(e) => { setPropertyFilter(e.target.value); setBlockFilter(""); }}
                            className="bg-white border border-blue-100 px-4 py-3 rounded-xl text-[11px] font-bold text-slate-500 outline-none focus:border-blue-400 transition-all min-w-[160px]"
                        >
                            <option value="">All Accommodations</option>
                            {accommodations.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
                        </select>

                        <select 
                            value={blockFilter} 
                            onChange={(e) => setBlockFilter(e.target.value)}
                            disabled={!propertyFilter}
                            className="bg-white border border-blue-100 px-4 py-3 rounded-xl text-[11px] font-bold text-slate-500 outline-none focus:border-blue-400 transition-all min-w-[160px] disabled:opacity-50"
                        >
                            <option value="">All Blocks</option>
                            {blocks.filter(b => b.accommodation === propertyFilter).map(b => (
                                <option key={b.id} value={b.id}>{b.name}</option>
                            ))}
                        </select>

                        <input 
                            type="text"
                            placeholder="Room #"
                            value={roomNumberFilter}
                            onChange={(e) => setRoomNumberFilter(e.target.value)}
                            className="w-24 bg-white border border-blue-100 px-4 py-3 rounded-xl text-[11px] font-bold outline-none focus:border-blue-400 transition-all"
                        />

                        <button onClick={() => { setSearchTerm(""); setPropertyFilter(""); setBlockFilter(""); setRoomNumberFilter(""); }} className="p-3 text-slate-400 hover:text-rose-500 transition-all">
                            <X size={20} />
                        </button>
                    </div>
                </div>
            </div>

            {/* Resident Table Container */}
            <div className="bg-white border border-blue-100 rounded-[28px] shadow-sm overflow-hidden">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1400px]">
                        <thead className="bg-slate-50/50 border-b border-blue-50 text-slate-400 text-[10px] uppercase tracking-[0.2em]">
                            <tr>
                                <th className="py-5 px-6 font-black w-12 text-center">Identity</th>
                                <th className="py-5 px-6 font-black">Resident Profile</th>
                                <th className="py-5 px-6 font-black">Gender</th>
                                <th className="py-5 px-6 font-black">Student No.</th>
                                <th className="py-5 px-6 font-black">Property Details</th>
                                <th className="py-5 px-6 font-black text-center">Room</th>
                                <th className="py-5 px-6 font-black text-center">Clearance</th>
                                <th className="py-5 px-6 font-black text-right sticky right-0 bg-white">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-blue-50 text-sm">
                            {loading ? (
                                <tr><td colSpan={8} className="py-24 text-center"><Loader2 className="animate-spin mx-auto text-blue-500" size={32} /></td></tr>
                            ) : filteredStudents.length === 0 ? (
                                <tr><td colSpan={8} className="py-24 text-center text-slate-400 font-bold uppercase tracking-widest italic">No matching records found.</td></tr>
                            ) : filteredStudents.map((s: any) => (
                                <tr key={s.id} className="hover:bg-blue-50/30 transition-all group">
                                    <td className="py-4 px-6">
                                        <div className="w-10 h-10 rounded-2xl bg-blue-50 border border-blue-100 flex items-center justify-center text-blue-400 overflow-hidden shadow-sm">
                                            {s.face_url ? <img src={s.face_url} className="w-full h-full object-cover" alt="p" /> : <User size={18} />}
                                        </div>
                                    </td>
                                    <td className="py-4 px-6">
                                        <div className="font-black text-blue-950 text-base">{s.name} {s.surname}</div>
                                        <div className="text-[10px] text-slate-400 font-bold lowercase tracking-tighter">{s.email}</div>
                                    </td>
                                    <td className="py-4 px-6">
                                        <span className="text-[9px] font-black uppercase bg-slate-100 text-slate-500 px-2 py-1 rounded-md">{s.gender}</span>
                                    </td>
                                    <td className="py-4 px-6 font-bold text-blue-500 tracking-widest">{s.student_number}</td>
                                    <td className="py-4 px-6">
                                        {s.room ? (
                                            <>
                                                <div className="font-black text-blue-800 text-xs">{s.accommodation_name}</div>
                                                <div className="flex gap-2 mt-1">
                                                    <span className="text-[9px] font-bold text-slate-400 uppercase">{s.block_name}</span>
                                                    {s.unit_name && s.unit_name !== "Unassigned Unit" && (
                                                        <span className="text-[9px] font-black text-purple-500 uppercase">Unit: {s.unit_name}</span>
                                                    )}
                                                </div>
                                            </>
                                        ) : (
                                            <div className="inline-flex items-center gap-1.5 px-2 py-1 bg-amber-50 text-amber-600 rounded text-[9px] font-black uppercase tracking-widest border border-amber-100">
                                                <AlertCircle size={10} /> Needs Physical Onboarding
                                            </div>
                                        )}
                                    </td>
                                    <td className="py-4 px-6 text-center">
                                        {s.room ? (
                                            <span className="px-3 py-1.5 bg-blue-600 text-white rounded-lg text-[10px] font-black shadow-md shadow-blue-600/20">
                                                ROOM: {s.room_number_only}
                                            </span>
                                        ) : (
                                            <span className="text-slate-300 font-black text-[10px] tracking-widest">---</span>
                                        )}
                                    </td>
                                    <td className="py-4 px-6 text-center">
                                        <button 
                                            onClick={() => toggleClearance(s.id, s.is_cleared_for_exit)} 
                                            disabled={!s.room}
                                            className={`px-4 py-2 rounded-xl text-[9px] font-black tracking-widest border transition-all ${
                                                !s.room ? 'bg-slate-50 text-slate-300 border-slate-100 cursor-not-allowed' :
                                                s.is_cleared_for_exit ? 'bg-emerald-50 text-emerald-600 border-emerald-100 hover:bg-emerald-100' : 'bg-rose-50 text-rose-600 border-rose-100 hover:bg-rose-100'
                                            }`}
                                        >
                                            {s.is_cleared_for_exit ? 'GRANTED' : 'REVOKED'}
                                        </button>
                                    </td>
                                    <td className="py-4 px-6 text-right sticky right-0 bg-white group-hover:bg-blue-50/10 transition-all border-l border-blue-50">
                                        <div className="flex items-center justify-end gap-2">
                                            <button 
                                                onClick={() => { setStudentToEdit(s); setIsModalOpen(true); }} 
                                                className={`px-3 py-1.5 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                                                    !s.room ? 'bg-amber-100 text-amber-700 hover:bg-amber-200' : 'text-slate-400 hover:text-blue-600 hover:bg-white shadow-sm'
                                                }`}
                                            >
                                                {!s.room ? 'Complete Setup' : <Edit2 size={14}/>}
                                            </button>
                                            <button onClick={() => handleDelete(s.id, s.name)} className="p-2 text-slate-300 hover:text-rose-600 hover:bg-white rounded-xl shadow-sm transition-all"><Trash2 size={14}/></button>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>

            {isModalOpen && (
                <StudentModal 
                    initialData={studentToEdit} 
                    students={students} 
                    onClose={() => setIsModalOpen(false)} 
                    onSuccess={() => { setIsModalOpen(false); fetchStudents(); }} 
                />
            )}
        </div>
    );
}

// --- STUDENT MODAL COMPONENT ---
function StudentModal({ initialData, students, onClose, onSuccess }: any) {
    const isEditMode = !!initialData;
    const [formData, setFormData] = useState<any>(initialData || { gender: 'MALE' });
    const [faceFile, setFaceFile] = useState<File | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    
    // Dropdown States
    const [accommodations, setAccommodations] = useState<any[]>([]);
    const [blocks, setBlocks] = useState<any[]>([]);
    const [units, setUnits] = useState<any[]>([]); 
    const [rooms, setRooms] = useState<any[]>([]);
    
    const [selectedAccommodation, setSelectedAccommodation] = useState('');
    const [selectedBlock, setSelectedBlock] = useState('');
    const [selectedUnit, setSelectedUnit] = useState(''); 

    useEffect(() => {
        const fetchProperties = async () => {
            try {
                const [aData, bData, uData, rData] = await Promise.all([
                    apiFetch('/accommodations/'), 
                    apiFetch('/blocks/'), 
                    apiFetch('/units/'), 
                    apiFetch('/rooms/')
                ]);
                setAccommodations(aData.results || aData || []);
                const fetchedBlocks = bData.results || bData || [];
                setBlocks(fetchedBlocks);
                setUnits(uData.results || uData || []);
                setRooms(rData.results || rData || []);
                
                if (initialData?.room) {
                    const roomObj = (rData.results || rData || []).find((r: any) => r.id === initialData.room);
                    if (roomObj) {
                        const blockObj = fetchedBlocks.find((b: any) => b.id === roomObj.block);
                        if (blockObj) setSelectedAccommodation(blockObj.accommodation || '');
                        setSelectedBlock(roomObj.block || '');
                        if (roomObj.unit) setSelectedUnit(roomObj.unit); 
                    }
                }
            } catch (err) { console.error("Dropdown fetch error"); }
        };
        fetchProperties();
    }, [initialData]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault(); 
        setLoading(true); 
        setError('');

        // Gender & Occupancy Guard
        const roomIdToCheck = formData.room_id || formData.room;
        if (roomIdToCheck) {
            const selectedRoomObj = rooms.find(r => r.id === roomIdToCheck);
            if (selectedRoomObj) {
                let targetGender = 'MIXED';
                if (selectedRoomObj.unit) {
                    targetGender = units.find(u => u.id === selectedRoomObj.unit)?.gender_target || 'MIXED';
                } else if (selectedRoomObj.block) {
                    targetGender = blocks.find(b => b.id === selectedRoomObj.block)?.gender_target || 'MIXED';
                }
                
                if (targetGender !== 'MIXED' && targetGender !== formData.gender) {
                    setError(`Gender Mismatch: Cannot place a ${formData.gender} resident in a ${targetGender} area.`);
                    setLoading(false); return;
                }
            }
        }

        const submitData = new FormData();
        Object.keys(formData).forEach(key => {
            if (!['room', 'id', 'face_url'].includes(key) && formData[key] !== null) {
                submitData.append(key, formData[key]);
            }
        });

        // CRITICAL FIX: The Django Serializer expects the exact key 'room', not 'room_id'.
        if (formData.room_id) {
            submitData.append('room', formData.room_id);
            submitData.append('room_id', formData.room_id); 
        }

        if (faceFile) submitData.append('face_image', faceFile);

        try {
            const endpoint = isEditMode ? `/students/${initialData.id}/` : '/add-student/';
            await apiFetch(endpoint, { method: isEditMode ? 'PATCH' : 'POST', body: submitData });
            onSuccess();
        } catch (err: any) { 
            setError(err.message || 'Operation failed.'); 
        } finally { setLoading(false); }
    };

    return (
        <ModalWrapper title={isEditMode ? (initialData.room ? "Update Resident Profile" : "Complete Physical Onboarding") : "Register New Resident"} onClose={onClose}>
            <form onSubmit={handleSubmit} className="space-y-4">
                {error && <div className="p-3 bg-rose-50 text-rose-600 text-[10px] font-black uppercase tracking-widest border border-rose-100 rounded-xl flex items-center gap-2"><AlertCircle size={14}/>{error}</div>}
                
                <div className="grid grid-cols-2 gap-3">
                    <Input label="Name" value={formData.name || ''} onChange={(e:any) => setFormData({...formData, name: e.target.value})} required />
                    <Input label="Surname" value={formData.surname || ''} onChange={(e:any) => setFormData({...formData, surname: e.target.value})} required />
                </div>
                
                <div className="grid grid-cols-2 gap-3">
                    <Select label="Gender" value={formData.gender || 'MALE'} onChange={(e:any) => setFormData({...formData, gender: e.target.value})} required>
                        <option value="MALE">Male</option>
                        <option value="FEMALE">Female</option>
                    </Select>
                    <Input label="Student No." value={formData.student_number || ''} onChange={(e:any) => setFormData({...formData, student_number: e.target.value})} required disabled={isEditMode} />
                </div>

                {!isEditMode && <Input label="ID Number (Generates PIN)" onChange={(e:any) => setFormData({...formData, id_number: e.target.value})} required />}
                <Input label="Phone" value={formData.phone || ''} onChange={(e:any) => setFormData({...formData, phone: e.target.value})} />
                
                <div className="space-y-1">
                    <label className="text-[10px] font-black text-slate-400 uppercase">
                        Facial Profile Image {(!isEditMode || !initialData.face_url) && <span className="text-rose-500">*</span>}
                    </label>
                    <input 
                        type="file" 
                        accept="image/*" 
                        onChange={(e:any) => setFaceFile(e.target.files[0])} 
                        required={!isEditMode || !initialData.face_url} 
                        className="w-full text-xs text-slate-400 file:mr-4 file:py-2 file:px-4 file:rounded-xl file:border-0 file:bg-blue-50 file:text-blue-600" 
                    />
                </div>

                <div className="p-5 border border-blue-50 rounded-2xl bg-blue-50/10 space-y-3">
                    <h4 className="text-[9px] font-black text-blue-400 uppercase tracking-[0.2em] mb-2">Room Allocation</h4>
                    <Select label="Property" value={selectedAccommodation} onChange={(e:any) => { setSelectedAccommodation(e.target.value); setSelectedBlock(''); setSelectedUnit(''); setFormData({...formData, room_id: ''}); }}>
                        <option value="">-- Choose Property --</option>
                        {accommodations.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
                    </Select>
                    <Select label="Block" value={selectedBlock} onChange={(e:any) => { setSelectedBlock(e.target.value); setSelectedUnit(''); setFormData({...formData, room_id: ''}); }} disabled={!selectedAccommodation}>
                        <option value="">-- Choose Block --</option>
                        {blocks.filter(b => b.accommodation === selectedAccommodation).map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
                    </Select>
                    <Select label="Unit (Optional)" value={selectedUnit} onChange={(e:any) => { setSelectedUnit(e.target.value); setFormData({...formData, room_id: ''}); }} disabled={!selectedBlock}>
                        <option value="">-- Direct Room --</option>
                        {units.filter(u => u.block === selectedBlock).map(u => <option key={u.id} value={u.id}>{u.name}</option>)}
                    </Select>
                    <Select label="Available Room" value={formData.room_id || formData.room || ''} onChange={(e:any) => setFormData({...formData, room_id: e.target.value})} disabled={!selectedBlock}>
                        <option value="">-- Assign a Room --</option>
                        {rooms.filter(r => {
                            if (selectedUnit) { if (r.unit !== selectedUnit) return false; } 
                            else { if (r.block !== selectedBlock || r.unit) return false; }
                            const isTaken = students.some((s: any) => s.room === r.id);
                            return !isTaken || (initialData && initialData.room === r.id);
                        }).map(r => <option key={r.id} value={r.id}>{r.room_number}</option>)}
                    </Select>
                </div>
                <SubmitButton loading={loading} text={isEditMode ? (initialData.room ? "Save Changes" : "Complete Onboarding") : "Register Resident"} />
            </form>
        </ModalWrapper>
    );
}