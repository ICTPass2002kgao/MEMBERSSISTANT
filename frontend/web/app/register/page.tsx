"use client";

import React, { useState } from 'react';
import { createUserWithEmailAndPassword, deleteUser } from 'firebase/auth';
import { auth } from '../firebase/config'; 
import Link from 'next/link';
import { ShieldCheck, Loader2, CheckCircle2 } from 'lucide-react';
import { apiFetch } from '../components/api';

export default function RegisterLandlord() {
    // State for all model fields
    const [name, setName] = useState<string>('');
    const [surname, setSurname] = useState<string>('');
    const [email, setEmail] = useState<string>('');
    const [phone, setPhone] = useState<string>('');
    const [password, setPassword] = useState<string>('');
    
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState<boolean>(false);
    const [success, setSuccess] = useState<boolean>(false);

    interface BackendRegisterRequest {
        firebase_uid: string;
        email: string;
        name: string;
        surname: string;
        phone: string;
    }

    const handleRegister = async (e: React.FormEvent<HTMLFormElement>): Promise<void> => {
        e.preventDefault();
        setError(null);
        setLoading(true);

        try {
            // 1. Create the account in Firebase (using email/password)
            const userCredential = await createUserWithEmailAndPassword(auth, email, password);
            const user = userCredential.user;

            try {
                // 2. Sync all professional details to Django
                const requestBody: BackendRegisterRequest = {
                    firebase_uid: user.uid,
                    email: email,
                    name: name,
                    surname: surname,
                    phone: phone,
                };

                await apiFetch('/register-landlord/', {
                    method: 'POST',
                    body: JSON.stringify(requestBody),
                });

                setSuccess(true);
                
            } catch (backendErr: unknown) {
                // Rollback Firebase if Django fails
                await deleteUser(user);
                throw new Error(`Professional Sync Failed: ${(backendErr as Error).message}`);
            }

        } catch (err: unknown) {
            setError((err as Error).message);
        } finally {
            setLoading(false);
        }
    };

    if (success) {
        return (
            <div className="min-h-screen bg-[#020617] relative flex items-center justify-center p-6 text-slate-100 font-sans">
                {/* Premium Background Atmosphere */}
                <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-blue-600/10 blur-[120px] pointer-events-none"></div>
                <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-blue-900/20 blur-[120px] pointer-events-none"></div>

                <div className="p-10 sm:p-14 rounded-[32px] bg-slate-900/40 backdrop-blur-xl border border-slate-800/60 shadow-2xl shadow-black/50 flex flex-col items-center max-w-md w-full relative overflow-hidden z-10">
                    <div className="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-emerald-500/50 to-transparent"></div>
                    
                    <div className="p-4 rounded-2xl bg-slate-800/50 border border-slate-700/50 mb-8 shadow-lg shadow-black/50">
                        <CheckCircle2 className="w-10 h-10 text-emerald-500" strokeWidth={1.5} />
                    </div>
                    
                    <h2 className="text-3xl font-bold tracking-tight mb-3 text-center text-white">Verified!</h2>
                    <p className="text-slate-400 text-center mb-8 text-sm">Professional Landlord account successfully provisioned.</p>
                    <Link href="/" className="text-blue-400 font-bold hover:underline underline-offset-4 transition-all">
                        Proceed to login
                    </Link>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-[#020617] relative overflow-hidden flex items-center justify-center p-6 text-slate-100 font-sans">
            
            {/* Premium Background Atmosphere */}
            <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-blue-600/10 blur-[120px] pointer-events-none"></div>
            <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-blue-900/20 blur-[120px] pointer-events-none"></div>

            <div className="z-10 w-full max-w-2xl"> 
                <div className="p-10 sm:p-14 rounded-[32px] bg-slate-900/40 backdrop-blur-xl border border-slate-800/60 shadow-2xl shadow-black/50 flex flex-col items-center relative overflow-hidden">
                    
                    {/* Subtle Top Border Glow */}
                    <div className="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-blue-500/50 to-transparent"></div>

                    {/* Professional Security Icon */}
                    <div className="p-4 rounded-2xl bg-slate-800/50 border border-slate-700/50 mb-8 shadow-lg shadow-black/50">
                        <ShieldCheck className="w-10 h-10 text-blue-500" strokeWidth={1.5} />
                    </div>

                    <h2 className="text-3xl font-bold tracking-tight mb-2 text-center text-white">
                        Professional Registry
                    </h2>
                    <p className="text-slate-500 tracking-[0.2em] mb-10 text-center text-[10px] font-bold uppercase">
                        LANDLORD MANAGEMENT PORTAL
                    </p>

                    {error && (
                        <div className="w-full bg-rose-500/10 border border-rose-500/20 text-rose-400 px-5 py-4 rounded-xl mb-8 text-xs font-medium text-center flex items-center justify-center gap-2">
                            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            {error}
                        </div>
                    )}

                    <form className="w-full space-y-6" onSubmit={handleRegister}>
                        {/* Name & Surname Grid */}
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 w-full">
                            <div className="space-y-1.5">
                                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">First Name</label>
                                <input
                                    type="text"
                                    required
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                    placeholder="First Name"
                                />
                            </div>
                            <div className="space-y-1.5">
                                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Last Name</label>
                                <input
                                    type="text"
                                    required
                                    value={surname}
                                    onChange={(e) => setSurname(e.target.value)}
                                    className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                    placeholder="Last Name"
                                />
                            </div>
                        </div>

                        {/* Email Input */}
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Professional Email</label>
                            <input
                                type="email"
                                required
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                placeholder="administrator@domain.com"
                            />
                        </div>

                        {/* Phone Input */}
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Contact Number</label>
                            <input
                                type="tel"
                                required
                                value={phone}
                                onChange={(e) => setPhone(e.target.value)}
                                className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                placeholder="060 000 0000"
                            />
                        </div>

                        {/* Password Input */}
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Security Credential</label>
                            <input
                                type="password"
                                required
                                minLength={6}
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                placeholder="••••••••••••"
                            />
                        </div>

                        <div className="pt-6">
                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full h-14 rounded-xl text-white font-bold tracking-[0.15em] text-xs transition-all disabled:opacity-70 flex items-center justify-center bg-blue-600 hover:bg-blue-500 shadow-lg shadow-blue-600/20 active:scale-[0.98]"
                            >
                                {loading ? (
                                    <div className="flex items-center gap-3">
                                        <Loader2 className="animate-spin w-4 h-4 text-white" />
                                        <span>PROVISIONING...</span>
                                    </div>
                                ) : 'CREATE PROFESSIONAL PROFILE'}
                            </button>
                        </div>
                    </form>

                    <div className="mt-8 text-center">
                        <Link href="/" className="text-[11px] font-medium text-slate-400 hover:text-white transition-colors">
                            Already have a professional account? <span className="text-blue-400 font-bold ml-1 hover:underline underline-offset-4">Login here</span>
                        </Link>
                    </div>
                </div>
            </div>
        </div>
    );
}