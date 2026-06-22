"use client";

import React, { useState, FormEvent } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from './firebase/config'; // Adjust path if needed
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { ShieldCheck, Loader2 } from 'lucide-react';
import { apiFetch } from './components/api'; // Adjust path if needed

interface LoginResponse {
    message?: string;
    role?: string;
    user_data?: any;
    error?: string;
}

export default function LoginPage() {
    const [email, setEmail] = useState<string>('');
    const [password, setPassword] = useState<string>('');
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState<boolean>(false);
    
    const router = useRouter();

    const handleLogin = async (e: FormEvent<HTMLFormElement>): Promise<void> => {
        e.preventDefault();
        setError(null);
        setLoading(true);

        try { 
            const userCredential = await signInWithEmailAndPassword(auth, email.trim(), password);
            const user = userCredential.user;
 
            const idToken = await user.getIdToken();
 
            const data: LoginResponse = await apiFetch('/login/', {
                method: 'POST',
                body: JSON.stringify({ id_token: idToken }), 
            });

            // --- CRITICAL FIX: Save credentials for the Dashboard to use ---
            localStorage.setItem('fb_id_token', idToken);
            if (data.role) localStorage.setItem('user_role', data.role);
            if (data.user_data) localStorage.setItem('user_data', JSON.stringify(data.user_data));

            // 4. Role-based Routing based on the Professional Profile
            if (data.role === 'admin') {
                router.push('/admin'); 
            } else if (data.role === 'landlord') {
                router.push('/landlord/dashboard'); 
            } else {
                router.push('/dashboard'); // Fallback
            }
            

        } catch (err: any) {
            // Provide a cleaner error message for Firebase auth failures
            if (err.code === 'auth/invalid-credential' || err.code === 'auth/user-not-found' || err.code === 'auth/wrong-password') {
                setError('Invalid professional credentials. Please try again.');
            } else {
                setError(err.message || 'An unexpected error occurred.');
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-[#020617] relative overflow-hidden flex items-center justify-center p-6 text-slate-100 font-sans">
            
            {/* Premium Background Atmosphere */}
            <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-blue-600/10 blur-[120px] pointer-events-none"></div>
            <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-blue-900/20 blur-[120px] pointer-events-none"></div>

            <div className="z-10 w-full max-w-xl">
                <div className="p-10 sm:p-14 rounded-[32px] bg-slate-900/40 backdrop-blur-xl border border-slate-800/60 shadow-2xl shadow-black/50 flex flex-col items-center relative overflow-hidden">
                    
                    {/* Subtle Top Border Glow */}
                    <div className="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-blue-500/50 to-transparent"></div>

                    {/* Professional Security Icon */}
                    <div className="p-4 rounded-2xl bg-slate-800/50 border border-slate-700/50 mb-8 shadow-lg shadow-black/50">
                        <ShieldCheck className="w-10 h-10 text-blue-500" strokeWidth={1.5} />
                    </div>

                    <h2 className="text-3xl font-bold tracking-tight mb-2 text-center text-white">
                        Management Portal
                    </h2>
                    <p className="text-slate-500 tracking-[0.2em] mb-10 text-center text-[10px] font-bold uppercase">
                        Authorize System Access
                    </p>

                    {error && (
                        <div className="w-full bg-rose-500/10 border border-rose-500/20 text-rose-400 px-5 py-4 rounded-xl mb-8 text-xs font-medium text-center flex items-center justify-center gap-2">
                            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            {error}
                        </div>
                    )}

                    <form className="w-full space-y-6" onSubmit={handleLogin}>
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

                        {/* Password Input */}
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Security Credential</label>
                            <input
                                type="password"
                                required
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
                                        <span>VERIFYING...</span>
                                    </div>
                                ) : 'AUTHORIZE SESSION'}
                            </button>
                        </div>
                    </form>

                    <div className="mt-8 text-center space-y-4">
                        <Link href="/register" className="text-[11px] font-medium text-slate-400 hover:text-white transition-colors block">
                            Need a professional account? <span className="text-blue-400 font-bold ml-1 hover:underline underline-offset-4">Register here</span>
                        </Link>
                        
                        <div className="text-[10px] text-slate-500">
                            By logging in, you agree to our{' '}
                            <Link href="./terms-and-conditons" className="text-slate-400 hover:text-white underline underline-offset-2 transition-colors">
                                Terms & Conditions
                            </Link>
                            {' '}and{' '}
                            <Link href="./privacy-policy" className="text-slate-400 hover:text-white underline underline-offset-2 transition-colors">
                                Privacy Policy
                            </Link>.
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}