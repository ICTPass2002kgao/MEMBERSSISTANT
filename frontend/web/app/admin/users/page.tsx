"use client";

import React, { useState, useEffect } from 'react';
import { Loader2, Users, GraduationCap, Shield, Building2, Search, Filter } from 'lucide-react';
import { apiFetch } from '../../components/api';

export default function SystemUsersPage() {
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    
    type Student = {
        id: number | string;
        name: string;
        surname: string;
        student_number: string;
        email: string;
    };

    type Staff = {
        id: number | string;
        name: string;
        surname: string;
        role: string;
        email: string;
    };

    type Landlord = {
        id: number | string;
        name: string;
        surname: string;
        email: string;
        phone: string;
        is_verified: boolean;
    };

    const [students, setStudents] = useState<Student[]>([]);
    const [staff, setStaff] = useState<Staff[]>([]);
    const [landlords, setLandlords] = useState<Landlord[]>([]);
    const [activeTab, setActiveTab] = useState<'students' | 'staff' | 'landlords'>('students');

    useEffect(() => {
        const fetchUsers = async () => {
            try {
                // Utilizing apiFetch and catching individual failures
                const [studentsRes, staffRes, landlordsRes] = await Promise.all([
                    apiFetch('/students/').catch(() => []),
                    apiFetch('/attendants/').catch(() => []),
                    apiFetch('/landlords/').catch(() => []),
                ]);

                const fetchedLandlords = landlordsRes.results || landlordsRes || [];
                // Filter to keep only approved/verified landlords
                const approvedLandlords = fetchedLandlords.filter((l: Landlord) => l.is_verified === true);

                setStudents(studentsRes.results || studentsRes || []);
                setStaff(staffRes.results || staffRes || []);
                setLandlords(approvedLandlords);
                
            } catch (err) {
                console.error("Failed to fetch system users", err);
            } finally {
                setLoading(false);
            }
        };
        fetchUsers();
    }, []);

    // Derived state for the currently active list
    const currentList = activeTab === 'students' ? students : activeTab === 'staff' ? staff : landlords;
    
    // Derived state for filtering the active list by search term
    const filteredList = currentList.filter(user => {
        const searchString = `${user.name} ${user.surname} ${user.email}`.toLowerCase();
        return searchString.includes(searchTerm.toLowerCase());
    });

    if (loading) return <div className="flex justify-center py-32"><Loader2 className="animate-spin text-blue-500" size={48} /></div>;

    return (
        <div className="space-y-6 animate-in slide-in-from-right-4 duration-300">
            
            {/* Header & Search Section */}
            <div className="flex flex-col xl:flex-row xl:items-end justify-between gap-6 bg-white p-6 rounded-[28px] border border-blue-50 shadow-sm">
                <div>
                    <h2 className="text-2xl font-black text-blue-950 tracking-tight">System Users</h2>
                    <p className="text-slate-500 text-xs font-medium mt-1">Manage all platform residents, staff members, and verified landlords.</p>
                </div>

                <div className="relative w-full xl:w-72">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-blue-300" size={16} />
                    <input 
                        type="text" 
                        placeholder={`Search ${activeTab}...`} 
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full pl-10 pr-4 py-2.5 bg-blue-50/50 border border-blue-100 rounded-xl outline-none focus:bg-white focus:border-blue-400 transition-all text-sm shadow-inner shadow-blue-50/50 placeholder-blue-300 font-medium"
                    />
                </div>
            </div>

            {/* Navigation Tabs */}
            <div className="flex flex-wrap gap-2 p-1 bg-slate-50 rounded-xl w-full sm:w-max border border-blue-50">
                <button 
                    onClick={() => { setActiveTab('students'); setSearchTerm(''); }}
                    className={`flex-1 sm:flex-none px-5 py-2 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-2 ${
                        activeTab === 'students' 
                        ? 'bg-white text-blue-950 shadow-sm border border-blue-100' 
                        : 'text-slate-500 hover:text-blue-700 border border-transparent'
                    }`}
                >
                    <GraduationCap size={16} /> Students ({students.length})
                </button>
                <button 
                    onClick={() => { setActiveTab('staff'); setSearchTerm(''); }}
                    className={`flex-1 sm:flex-none px-5 py-2 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-2 ${
                        activeTab === 'staff' 
                        ? 'bg-white text-blue-950 shadow-sm border border-blue-100' 
                        : 'text-slate-500 hover:text-blue-700 border border-transparent'
                    }`}
                >
                    <Shield size={16} /> Staff ({staff.length})
                </button>
                <button 
                    onClick={() => { setActiveTab('landlords'); setSearchTerm(''); }}
                    className={`flex-1 sm:flex-none px-5 py-2 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-2 ${
                        activeTab === 'landlords' 
                        ? 'bg-white text-blue-950 shadow-sm border border-blue-100' 
                        : 'text-slate-500 hover:text-blue-700 border border-transparent'
                    }`}
                >
                    <Building2 size={16} /> Landlords ({landlords.length})
                </button>
            </div>

            {/* Data Table */}
            <div className="bg-white rounded-[32px] border border-blue-50 shadow-sm hover:shadow-md transition-all duration-300 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse min-w-[600px]">
                        <thead>
                            <tr className="bg-slate-50/50">
                                <th className="px-8 py-5 text-[10px] font-black tracking-widest text-slate-400 uppercase border-b border-blue-50">Name</th>
                                <th className="px-8 py-5 text-[10px] font-black tracking-widest text-slate-400 uppercase border-b border-blue-50">Identifier</th>
                                <th className="px-8 py-5 text-[10px] font-black tracking-widest text-slate-400 uppercase border-b border-blue-50">Contact</th>
                                <th className="px-8 py-5 text-[10px] font-black tracking-widest text-slate-400 uppercase border-b border-blue-50">Status</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-blue-50/50">
                            {filteredList.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="px-8 py-16 text-center">
                                        <div className="flex flex-col items-center justify-center">
                                            <div className="w-16 h-16 bg-blue-50 rounded-full flex items-center justify-center mb-4 border border-blue-100">
                                                <Filter size={24} className="text-blue-400" />
                                            </div>
                                            <p className="text-slate-900 font-bold text-sm">No users found</p>
                                            <p className="text-slate-500 text-xs mt-1">Try adjusting your search query.</p>
                                        </div>
                                    </td>
                                </tr>
                            ) : (
                                filteredList.map((user) => (
                                    <tr key={user.id} className="hover:bg-blue-50/30 transition-colors">
                                        <td className="px-8 py-4 font-bold text-blue-950 text-sm flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-xl bg-blue-100 flex items-center justify-center text-blue-600 font-black shadow-sm">
                                                {user.name ? user.name.charAt(0) : 'U'}
                                            </div>
                                            {user.name} {user.surname}
                                        </td>
                                        <td className="px-8 py-4 text-sm text-slate-600 font-medium">
                                            {activeTab === 'students'
                                                ? <span className="font-mono text-xs bg-slate-50 px-2 py-1 rounded border border-slate-100">SN: {(user as Student).student_number ?? 'N/A'}</span>
                                                : activeTab === 'staff'
                                                ? <span className="text-xs font-bold text-indigo-600 bg-indigo-50 px-2.5 py-1 rounded-md uppercase tracking-wider">{(user as Staff).role ?? 'STAFF'}</span>
                                                : <span className="text-xs font-bold text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-md uppercase tracking-wider">Verified Landlord</span>
                                            }
                                        </td>
                                        <td className="px-8 py-4 text-xs text-slate-500 font-medium">
                                            {user.email || 'N/A'}
                                        </td>
                                        <td className="px-8 py-4">
                                            <span className="inline-flex px-2.5 py-1 rounded-md bg-emerald-50 text-emerald-600 text-[10px] font-bold border border-emerald-100 uppercase tracking-wider shadow-sm">
                                                Active
                                            </span>
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