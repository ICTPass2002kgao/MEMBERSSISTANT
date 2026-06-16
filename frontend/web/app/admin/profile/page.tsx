"use client";

import React, { useEffect, useState } from 'react';
import { UserCog, Mail, ShieldCheck } from 'lucide-react';

/**
 * @typedef {Object} AdminData
 * @property {string} [name]
 * @property {string} [surname]
 * @property {string} [role]
 * @property {string} [email]
 * @property {string} [firebase_uid]
 */

type AdminData = {
    name?: string;
    surname?: string;
    role?: string;
    email?: string;
    firebase_uid?: string;
};

export default function AdminProfilePage() {
    const [adminData, setAdminData] = useState<AdminData | null>(null);

    useEffect(() => {
        const stored = localStorage.getItem('user_data');
        if (stored) {
            setAdminData(JSON.parse(stored));
        }
    }, []);

    if (!adminData) return null;

    return (
        <div className="space-y-6 max-w-3xl animate-in fade-in duration-500">
            <div>
                <h2 className="text-2xl font-black text-slate-900 tracking-tight">Root Profile</h2>
                <p className="text-slate-500 text-xs font-medium mt-1">System administrator credentials and settings.</p>
            </div>

            <div className="bg-white rounded-[32px] border border-slate-100 shadow-xl shadow-slate-200/40 overflow-hidden">
                <div className="h-32 bg-slate-900 w-full relative">
                    <div className="absolute -bottom-10 left-8">
                        <div className="w-24 h-24 rounded-2xl bg-white p-1 shadow-lg">
                            <div className="w-full h-full bg-slate-100 rounded-xl flex items-center justify-center text-slate-400 border border-slate-200">
                                <UserCog size={40} />
                            </div>
                        </div>
                    </div>
                </div>
                
                <div className="pt-16 px-8 pb-8">
                    <div className="flex items-center gap-3 mb-1">
                        <h3 className="text-2xl font-black text-slate-900">{adminData.name} {adminData.surname}</h3>
                        <ShieldCheck className="text-rose-500" size={20} />
                    </div>
                    <p className="text-sm font-bold text-rose-500 uppercase tracking-widest">{adminData.role || 'Super Administrator'}</p>

                    <div className="mt-8 space-y-4 border-t border-slate-100 pt-6">
                        <div className="flex items-center gap-4 p-4 rounded-2xl bg-slate-50 border border-slate-100">
                            <Mail className="text-slate-400" size={20} />
                            <div>
                                <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Secure Email</p>
                                <p className="text-sm font-bold text-slate-900">{adminData.email}</p>
                            </div>
                        </div>
                        
                        <div className="flex items-center gap-4 p-4 rounded-2xl bg-slate-50 border border-slate-100">
                            <ShieldCheck className="text-slate-400" size={20} />
                            <div>
                                <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Firebase UID (Encrypted)</p>
                                <p className="text-sm font-bold text-slate-900 font-mono">{adminData.firebase_uid}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}