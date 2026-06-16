"use client";

import React, { useState, useEffect, useMemo } from 'react';
import { 
  Plus, AlertCircle, Loader2, User, Search, X, 
  Package, ShieldCheck, Trash2, CheckCircle2
} from 'lucide-react';
import { apiFetch } from '../../components/api';
import { SectionHeader, ModalWrapper, Input, SubmitButton } from '../../components/SharedUI';

export default function GatePassesPage() {
    const [gatePasses, setGatePasses] = useState<any[]>([]);
    const [students, setStudents] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    
    // Search State
    const [searchTerm, setSearchTerm] = useState("");

    // Modal Management
    const [isModalOpen, setIsModalOpen] = useState(false);

    const fetchGatePassData = async () => {
        setLoading(true);
        try {
            const [gpData, sData] = await Promise.all([
                apiFetch('/gate-passes/').catch(() => []),
                apiFetch('/students/').catch(() => []) 
            ]);
            
            const fetchedPasses = gpData.results || gpData || [];
            const fetchedStudents = sData.results || sData || [];
            
            // Sort passes by newest first
            fetchedPasses.sort((a: any, b: any) => 
                new Date(b.issued_at || b.created_at || 0).getTime() - new Date(a.issued_at || a.created_at || 0).getTime()
            );

            setGatePasses(fetchedPasses);
            setStudents(fetchedStudents);
        } catch (error) { 
            console.error("System Fetch Error:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { fetchGatePassData(); }, []);

    // --- SEARCH LOGIC ---
    const filteredGatePasses = useMemo(() => {
        return gatePasses.filter(gp => {
            // Find the linked student to allow searching by their actual name
            const matchedStudent = students.find(s => s.id === gp.student);
            const studentName = matchedStudent 
                ? `${matchedStudent.name} ${matchedStudent.surname}`.toLowerCase() 
                : `${gp.student_name || ''} ${gp.student_surname || ''}`.toLowerCase();
                
            const assetName = (gp.asset_name || '').toLowerCase();
            return studentName.includes(searchTerm.toLowerCase()) || assetName.includes(searchTerm.toLowerCase());
        });
    }, [gatePasses, students, searchTerm]);

    const handleRevoke = async (id: string) => {
        if (!window.confirm("Are you sure you want to revoke and archive this gate pass?")) return;
        try {
            await apiFetch(`/gate-passes/${id}/`, { 
                method: 'PATCH', 
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ is_active: false }) 
            });
            fetchGatePassData();
        } catch (error) { console.error("Revocation failed"); }
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
            {/* Header Section */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="Property Gate Passes" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        Active Authorizations: {gatePasses.filter(gp => gp.is_active).length} Passes
                    </p>
                </div>
                <button 
                    onClick={() => setIsModalOpen(true)} 
                    className="flex items-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-2xl text-[11px] font-black uppercase tracking-[0.2em] transition-all shadow-lg shadow-blue-600/20 active:scale-95"
                >
                    <Plus size={16} /> Issue Gate Pass
                </button>
            </div>

            {/* Filters */}
            <div className="bg-white border border-blue-100 p-6 rounded-[28px] shadow-sm">
                <div className="relative w-full md:w-[400px]">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300" size={18} />
                    <input 
                        type="text"
                        placeholder="Search by resident name or asset..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full bg-blue-50/50 border border-blue-100 pl-12 pr-10 py-3.5 rounded-2xl text-sm outline-none focus:bg-white focus:border-blue-400 transition-all"
                    />
                    {searchTerm && (
                        <button onClick={() => setSearchTerm("")} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-rose-500 transition-all">
                            <X size={16} />
                        </button>
                    )}
                </div>
            </div>

            {/* Gate Pass Logs Table */}
            <div className="bg-white border border-blue-100 rounded-[28px] shadow-sm overflow-hidden">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1000px]">
                        <thead className="bg-slate-50/50 border-b border-blue-50 text-slate-400 text-[10px] uppercase tracking-[0.2em]">
                            <tr>
                                <th className="py-5 px-6 font-black w-12 text-center">Resident</th>
                                <th className="py-5 px-6 font-black">Authorized Assets</th>
                                <th className="py-5 px-6 font-black text-center">Status</th>
                                <th className="py-5 px-6 font-black text-center">Valid Until</th>
                                <th className="py-5 px-6 font-black text-right sticky right-0 bg-white">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-blue-50 text-sm">
                            {loading ? (
                                <tr><td colSpan={5} className="py-24 text-center"><Loader2 className="animate-spin mx-auto text-blue-500" size={32} /></td></tr>
                            ) : filteredGatePasses.length === 0 ? (
                                <tr><td colSpan={5} className="py-24 text-center text-slate-400 font-bold uppercase tracking-widest italic">No gate passes recorded.</td></tr>
                            ) : filteredGatePasses.map((gp: any) => {
                                const expiryDate = gp.expires_at ? new Date(gp.expires_at) : null;
                                const isExpired = (expiryDate && new Date() > expiryDate) || !gp.is_active;

                                // FIX: Look up the student data dynamically based on the Django ID
                                const matchedStudent = students.find(s => s.id === gp.student);
                                const displayName = matchedStudent ? matchedStudent.name : (gp.student_name || 'Resident');
                                const displaySurname = matchedStudent ? matchedStudent.surname : (gp.student_surname || '');
                                const displayNo = matchedStudent ? matchedStudent.student_number : (gp.student_number || 'N/A');
                                const displayFace = matchedStudent ? matchedStudent.face_url : gp.student_face_url;

                                // Dynamically split the bundled string from Django into an array
                                const assetNames = (gp.asset_name || 'Unknown Asset').split(' + ');
                                const assetNums = (gp.asset_number || 'N/A').split(' + ');

                                return (
                                    <tr key={gp.id} className="hover:bg-blue-50/30 transition-all group">
                                        <td className="py-4 px-6">
                                            <div className="flex items-center gap-3">
                                                <div className="w-10 h-10 rounded-2xl bg-blue-50 border border-blue-100 flex items-center justify-center text-blue-400 shadow-sm overflow-hidden">
                                                    {displayFace ? (
                                                        <img src={displayFace} alt="profile" className="w-full h-full object-cover" />
                                                    ) : (
                                                        <User size={18} />
                                                    )}
                                                </div>
                                                <div>
                                                    <div className="font-black text-blue-950 text-base">
                                                        {displayName} {displaySurname}
                                                    </div>
                                                    <div className="text-[10px] text-slate-400 font-bold tracking-tight">{displayNo}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td className="py-4 px-6">
                                            <div className="flex flex-col gap-2 max-w-[300px]">
                                                {assetNames.map((name: string, i: number) => (
                                                    <div key={i} className="flex items-start gap-2">
                                                        <Package size={14} className="text-blue-400 mt-0.5 shrink-0" />
                                                        <div>
                                                            <div className="font-bold text-slate-700 text-sm leading-tight">{name}</div>
                                                            {assetNums[i] && assetNums[i] !== 'N/A' && (
                                                                <div className="text-[10px] text-slate-400 font-mono mt-0.5">S/N: {assetNums[i]}</div>
                                                            )}
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        </td>
                                        <td className="py-4 px-6 text-center">
                                            <span className={`px-3 py-1.5 rounded-xl text-[9px] font-black tracking-widest border ${
                                                !isExpired ? 'bg-emerald-50 text-emerald-600 border-emerald-100' : 'bg-rose-50 text-rose-600 border-rose-100'
                                            }`}>
                                                {!isExpired ? 'ACTIVE' : 'EXPIRED / REVOKED'}
                                            </span>
                                        </td>
                                        <td className="py-4 px-6 text-center">
                                            <div className="text-xs font-bold text-slate-600">
                                                {expiryDate ? expiryDate.toLocaleDateString() : 'N/A'}
                                            </div>
                                        </td>
                                        <td className="py-4 px-6 text-right sticky right-0 bg-white group-hover:bg-blue-50/10 transition-all border-l border-blue-50">
                                            {!isExpired ? (
                                                <button 
                                                    onClick={() => handleRevoke(gp.id)}
                                                    className="p-2 text-slate-300 hover:text-rose-600 hover:bg-white rounded-xl shadow-sm transition-all"
                                                    title="Revoke Gate Pass"
                                                >
                                                    <Trash2 size={16}/>
                                                </button>
                                            ) : (
                                                <span className="text-slate-300 text-[10px] font-black uppercase tracking-widest">Archived</span>
                                            )}
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Create Gate Pass Modal */}
            {isModalOpen && (
                <CreateGatePassModal 
                    students={students}
                    onClose={() => setIsModalOpen(false)} 
                    onSuccess={() => { setIsModalOpen(false); fetchGatePassData(); }} 
                />
            )}
        </div>
    );
}

// --- HIGHLY SCALABLE CREATE GATE PASS MODAL ---
function CreateGatePassModal({ students, onClose, onSuccess }: any) {
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    
    // Searchable Autocomplete State (Fix for 3000 students)
    const [studentSearch, setStudentSearch] = useState("");
    const [selectedStudent, setSelectedStudent] = useState<any | null>(null);

    // Dynamic Assets State (Fix for multiple items)
    const [assets, setAssets] = useState([{ name: '', number: '' }]);

    // Filter students down to top 5 based on search query
    const searchResults = useMemo(() => {
        if (!studentSearch.trim()) return [];
        const search = studentSearch.toLowerCase();
        return students.filter((s: { name: any; surname: any; student_number: string; id_number: string; }) => 
            `${s.name} ${s.surname}`.toLowerCase().includes(search) ||
            s.student_number.toLowerCase().includes(search) ||
            (s.id_number && s.id_number.toLowerCase().includes(search))
        ).slice(0, 5); // Limit rendering to keep DOM fast
    }, [students, studentSearch]);

    // Handle Asset Item Modifications
    const handleAssetChange = (index: number, field: 'name' | 'number', value: string) => {
        const newAssets = [...assets];
        newAssets[index][field] = value;
        setAssets(newAssets);
    };

    const addAssetRow = () => {
        if (assets.length >= 6) {
            setError("Maximum of 6 items allowed per single gate pass bundle.");
            return;
        }
        setAssets([...assets, { name: '', number: '' }]);
    };

    const removeAssetRow = (index: number) => {
        const newAssets = assets.filter((_, i) => i !== index);
        setAssets(newAssets);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        
        if (!selectedStudent || !selectedStudent.id) {
            setError("Error: The selected student record is missing a valid database ID.");
            return;
        }

        const validAssets = assets.filter(a => a.name.trim() !== "");
        if (validAssets.length === 0) {
            setError("You must provide at least one asset name.");
            return;
        }

        setLoading(true);
        setError('');

        const finalNames = validAssets.map(a => a.name.trim()).join(' + ');
        const finalNumbers = validAssets.map(a => a.number.trim() || 'N/A').join(' + ');

        const submitData = new FormData();
        submitData.append('student', selectedStudent.id);
        submitData.append('asset_name', finalNames);
        submitData.append('asset_number', finalNumbers);
        submitData.append('is_active', 'true');

        try {
            await apiFetch('/gate-passes/', {
                method: 'POST',
                body: submitData 
            });
            onSuccess();
        } catch (err: any) {
            if (typeof err === 'object' && err !== null && !err.message) {
                const firstKey = Object.keys(err)[0];
                setError(`${firstKey.toUpperCase()}: ${err[firstKey]}`);
            } else {
                setError(err.message || 'Failed to authorize and generate gate pass.');
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <ModalWrapper title="Issue Asset Gate Pass" onClose={onClose}>
            <form onSubmit={handleSubmit} className="space-y-6">
                {error && (
                    <div className="p-3 bg-rose-50 text-rose-600 text-[10px] font-black uppercase tracking-widest border border-rose-100 rounded-xl flex items-center gap-2">
                        <AlertCircle size={14}/>{error}
                    </div>
                )}

                {/* --- SCALABLE STUDENT SELECTOR --- */}
                <div className="space-y-3">
                    <h4 className="text-[10px] font-black text-blue-400 uppercase tracking-[0.2em] flex items-center gap-2">
                        <span className="w-5 h-5 rounded-md bg-blue-100 text-blue-600 flex items-center justify-center">1</span> 
                        Assign to Resident
                    </h4>
                    
                    {!selectedStudent ? (
                        <div className="relative">
                            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300" size={16} />
                            <input 
                                type="text"
                                placeholder="Search by Name, Student No. or ID..."
                                value={studentSearch}
                                onChange={(e) => setStudentSearch(e.target.value)}
                                className="w-full bg-blue-50/50 border border-blue-100 pl-11 pr-4 py-3 rounded-xl text-sm outline-none focus:bg-white focus:border-blue-400 transition-all"
                            />
                            
                            {studentSearch && (
                                <div className="absolute z-10 w-full mt-2 bg-white border border-blue-100 rounded-xl shadow-lg overflow-hidden">
                                    {searchResults.length > 0 ? (
                                        searchResults.map((s: any) => (
                                            <button
                                                key={s.id}
                                                type="button"
                                                onClick={() => {
                                                    setSelectedStudent(s);
                                                    setStudentSearch("");
                                                }}
                                                className="w-full text-left px-4 py-3 hover:bg-blue-50 transition-all flex justify-between items-center border-b border-slate-50 last:border-0"
                                            >
                                                <div>
                                                    <div className="font-bold text-sm text-blue-950">{s.name} {s.surname}</div>
                                                    <div className="text-[10px] text-slate-400 font-bold tracking-widest uppercase">ID: {s.student_number}</div>
                                                </div>
                                            </button>
                                        ))
                                    ) : (
                                        <div className="px-4 py-4 text-center text-xs font-bold text-slate-400 uppercase">
                                            No residents found.
                                        </div>
                                    )}
                                </div>
                            )}
                        </div>
                    ) : (
                        <div className="flex items-center justify-between bg-emerald-50 border border-emerald-100 p-4 rounded-xl">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-xl bg-emerald-100 flex items-center justify-center text-emerald-600">
                                    <CheckCircle2 size={20} />
                                </div>
                                <div>
                                    <div className="font-black text-emerald-900">{selectedStudent.name} {selectedStudent.surname}</div>
                                    <div className="text-[10px] text-emerald-600 font-bold tracking-widest uppercase">Room: {selectedStudent.room_number_only || 'Unassigned'}</div>
                                </div>
                            </div>
                            <button 
                                type="button" 
                                onClick={() => setSelectedStudent(null)}
                                className="text-xs font-bold text-slate-400 hover:text-rose-500 underline"
                            >
                                Change
                            </button>
                        </div>
                    )}
                </div>

                {/* --- DYNAMIC ASSET BUILDER --- */}
                <div className={`space-y-4 transition-all duration-300 ${!selectedStudent ? 'opacity-40 pointer-events-none' : 'opacity-100'}`}>
                    <div className="flex items-center justify-between pt-2">
                        <h4 className="text-[10px] font-black text-blue-400 uppercase tracking-[0.2em] flex items-center gap-2">
                            <span className="w-5 h-5 rounded-md bg-blue-100 text-blue-600 flex items-center justify-center">2</span> 
                            Asset Bundle Items
                        </h4>
                        <span className="text-[10px] font-bold text-slate-400">{assets.length} Item(s)</span>
                    </div>
                    
                    <div className="p-5 border border-blue-50 rounded-2xl bg-blue-50/10 space-y-4">
                        {assets.map((asset, index) => (
                            <div key={index} className="flex gap-3 items-start relative group">
                                <div className="flex-1 space-y-3">
                                    <Input 
                                        label={`Asset ${index + 1} Name`} 
                                        placeholder="e.g. MacBook Pro M2"
                                        value={asset.name} 
                                        onChange={(e: any) => handleAssetChange(index, 'name', e.target.value)}
                                        required={index === 0} 
                                    />
                                    <Input 
                                        label="Serial Number (Optional)" 
                                        placeholder="e.g. SN-894723"
                                        value={asset.number} 
                                        onChange={(e: any) => handleAssetChange(index, 'number', e.target.value)}
                                    />
                                </div>
                                {assets.length > 1 && (
                                    <button 
                                        type="button" 
                                        onClick={() => removeAssetRow(index)}
                                        className="mt-8 p-2 text-rose-400 hover:text-rose-600 hover:bg-rose-50 rounded-xl transition-all"
                                    >
                                        <Trash2 size={18} />
                                    </button>
                                )}
                            </div>
                        ))}

                        <button 
                            type="button"
                            onClick={addAssetRow}
                            className="w-full py-3 border-2 border-dashed border-blue-200 hover:border-blue-400 text-blue-500 rounded-xl text-xs font-black uppercase tracking-widest transition-all flex justify-center items-center gap-2"
                        >
                            <Plus size={14} /> Add Another Item to Bundle
                        </button>
                    </div>
                </div>

                <SubmitButton loading={loading} text="Issue 3-Month Pass" />
            </form>
        </ModalWrapper>
    );
}