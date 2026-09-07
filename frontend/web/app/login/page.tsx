"use client";

import React, { useState, FormEvent, useEffect } from 'react';
import { signInWithEmailAndPassword, signInAnonymously } from 'firebase/auth';
import { auth } from '../firebase/config'; // Adjust path if needed
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { ShieldCheck, Loader2, Cookie, X, Lock, User, ArrowRight } from 'lucide-react';
import { apiFetch } from '../components/api'; // Adjust path if needed

interface LoginResponse {
    message?: string;
    role?: string;
    user_data?: any;
    error?: string;
}

// Professional-grade cookie helper ensuring Secure and SameSite policies
const setSecureCookie = (name: string, value: string, days: number = 7) => {
    const expires = new Date(Date.now() + days * 86400000).toUTCString();
    document.cookie = `${name}=${encodeURIComponent(value)}; expires=${expires}; path=/; Secure; SameSite=Strict`;
};

export default function LoginPage() {
    // Changed from email to identifier to support Student Numbers
    const [identifier, setIdentifier] = useState<string>('');
    const [password, setPassword] = useState<string>('');
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState<boolean>(false);
    const [anonLoading, setAnonLoading] = useState<boolean>(false);
    
    // Cookie Banner State
    const [showCookieBanner, setShowCookieBanner] = useState<boolean>(false);
    
    const router = useRouter();

    useEffect(() => {
        const consent = localStorage.getItem('cookie_consent');
        if (!consent) {
            setShowCookieBanner(true);
        }
    }, []);
useEffect(() => {
    const user = auth.currentUser;
    if (user) {
        const redirect = sessionStorage.getItem('redirectAfterLogin');
        if (redirect) {
            sessionStorage.removeItem('redirectAfterLogin');
            router.push(redirect);
        } else {
            router.push('/');
        }
    }
}, []);
    const handleAcceptCookies = () => {
        localStorage.setItem('cookie_consent', 'accepted');
        setShowCookieBanner(false);
    };

    const handleIgnoreCookies = () => {
        localStorage.setItem('cookie_consent', 'ignored');
        setShowCookieBanner(false);
    };

    const handleLogin = async (e: FormEvent<HTMLFormElement>): Promise<void> => {
        e.preventDefault();
        setError(null);
        setLoading(true);

        try { 
            const trimmedIdentifier = identifier.trim();
            // Append student email domain if it's just a student number (doesn't contain '@')
            const loginEmail = trimmedIdentifier.includes('@') 
                ? trimmedIdentifier 
                : `${trimmedIdentifier}@edu.vut.ac.za`;

            const userCredential = await signInWithEmailAndPassword(auth, loginEmail, password);
            const user = userCredential.user;
 
            const idToken = await user.getIdToken();
 
            const data: LoginResponse = await apiFetch('/login/', {
                method: 'POST',
                body: JSON.stringify({ id_token: idToken }), 
            });

            // Set secure cookies for session persistence
            setSecureCookie('fb_id_token', idToken);
            if (data.role) setSecureCookie('user_role', data.role);
            if (data.user_data) setSecureCookie('user_data', JSON.stringify(data.user_data));

            // Dynamic routing based on the exact roles from your Flutter logic
            const baseRole = data.role;
            const specificRole = data.user_data?.role;

            if (baseRole === 'student') {
                router.push('/accommodations'); 
            } else if (baseRole === 'responder') {
                router.push('/responder/dashboard'); // Or /responder/verify depending on your web flow
            } else if (baseRole === 'staff') {
                if (specificRole === 'SECURITY') {
                    router.push('/security/dashboard');
                } else {
                    router.push('/staff/dashboard'); // Attendant dashboard
                }
            } else if (baseRole === 'admin') {
                router.push('/admin'); 
            } else {
                // Fallback / Default for Landlords
                router.push('/landlord/dashboard'); 
            }
            
        } catch (err: any) {
            if (err.code === 'auth/invalid-credential' || err.code === 'auth/user-not-found' || err.code === 'auth/wrong-password') {
                setError('Invalid credentials. Please check your details and try again.');
            } else {
                setError(err.message || 'An unexpected error occurred.');
            }
        } finally {
            setLoading(false);
        }
    };

    const handleAnonymousLogin = async () => {
        setError(null);
        setAnonLoading(true);
        try {
            await signInAnonymously(auth);
            router.push('/'); // Or '/student/dashboard' for limited access depending on your setup
        } catch (err: any) {
            setError(err.message || 'Anonymous login failed.');
        } finally {
            setAnonLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-slate-50 relative overflow-hidden flex items-center justify-center p-6 text-slate-800 font-sans py-12">
            
            {/* Premium Light Background Atmosphere */}
            <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-red-600/5 blur-[120px] pointer-events-none z-0"></div>
            <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-red-900/5 blur-[120px] pointer-events-none z-0"></div>

            <div className="z-10 w-full max-w-md animate-in zoom-in-95 duration-300">
                <div className="p-8 sm:p-12 rounded-[32px] bg-white/80 backdrop-blur-xl border border-white/60 shadow-[0_8px_30px_rgb(0,0,0,0.06)] flex flex-col items-center relative overflow-hidden">
                    
                    <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-red-800 to-red-500"></div>

                    <Link href="/">
                        <div className="p-4 rounded-full bg-red-50 border border-red-100 mb-6 shadow-sm hover:scale-105 transition-transform cursor-pointer">
                            <Lock className="w-10 h-10 text-red-700" strokeWidth={1.5} />
                        </div>
                    </Link>

                    <h2 className="text-3xl font-black tracking-tight mb-2 text-center text-slate-900">
                        Student Heights
                    </h2>
                    <p className="text-red-700 tracking-[0.15em] mb-8 text-center text-[10px] font-bold uppercase">
                        Resident & Staff Portal
                    </p>

                    {error && (
                        <div className="w-full bg-rose-50 border border-rose-200 text-rose-700 px-5 py-4 rounded-xl mb-8 text-xs font-bold text-center flex items-center justify-center gap-2 shadow-sm">
                            <ShieldCheck className="w-4 h-4 shrink-0" />
                            <p>{error}</p>
                        </div>
                    )}

                    <form className="w-full space-y-5" onSubmit={handleLogin}>
                        <div className="space-y-1.5 relative">
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Student No. or Staff Email</label>
                            <div className="relative">
                                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                                    <User className="h-5 w-5 text-slate-400" />
                                </div>
                                <input
                                    type="text"
                                    required
                                    value={identifier}
                                    onChange={(e) => setIdentifier(e.target.value)}
                                    className="w-full pl-11 pr-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                    placeholder="e.g. 219000000"
                                />
                            </div>
                        </div>

                        <div className="space-y-1.5 relative">
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Security Credential</label>
                            <div className="relative">
                                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                                    <ShieldCheck className="h-5 w-5 text-slate-400" />
                                </div>
                                <input
                                    type="password"
                                    required
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    className="w-full pl-11 pr-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                    placeholder="••••••••••••"
                                />
                            </div>
                        </div>

                        <div className="flex justify-end pt-1">
                            <Link href="/forgot-password" className="text-[11px] font-bold text-red-600 hover:text-red-800 transition-colors">
                                Forgot Password?
                            </Link>
                        </div>

                        <div className="pt-4 space-y-4">
                            <button
                                type="submit"
                                disabled={loading || anonLoading}
                                className="w-full h-14 rounded-xl text-white font-black tracking-[0.15em] text-xs transition-all disabled:opacity-70 flex items-center justify-center bg-gradient-to-r from-red-800 to-red-700 hover:from-red-900 hover:to-red-800 shadow-lg shadow-red-900/20 active:scale-[0.98]"
                            >
                                {loading ? (
                                    <div className="flex items-center gap-3">
                                        <Loader2 className="animate-spin w-4 h-4 text-white" />
                                        <span>AUTHORIZING...</span>
                                    </div>
                                ) : 'AUTHORIZE'}
                            </button>

                            <button
                                type="button"
                                onClick={handleAnonymousLogin}
                                disabled={loading || anonLoading}
                                className="w-full h-14 rounded-xl text-red-700 font-bold tracking-wider text-xs transition-all flex items-center justify-center bg-transparent border-2 border-red-200 hover:border-red-700 hover:bg-red-50 active:scale-[0.98]"
                            >
                                {anonLoading ? (
                                    <Loader2 className="animate-spin w-4 h-4 text-red-700" />
                                ) : 'PROCEED WITHOUT LOGIN'}
                            </button>
                        </div>
                    </form>

                    <div className="mt-8 text-center pt-6 border-t border-slate-200/60 w-full">
                        <Link href="/register" className="text-xs font-bold text-slate-500 hover:text-slate-800 transition-colors block">
                            Don't have an account? <span className="text-red-600 ml-1 hover:underline underline-offset-4">Sign Up</span>
                        </Link>
                    </div>
                </div>
            </div>

            {/* Premium Cookie Consent Banner */}
            {showCookieBanner && (
                <div className="fixed bottom-0 left-0 w-full z-40 p-4 sm:p-6 animate-in slide-in-from-bottom-10 duration-500">
                    <div className="max-w-4xl mx-auto bg-white/95 backdrop-blur-2xl border border-slate-200 rounded-[24px] shadow-[0_-10px_40px_rgb(0,0,0,0.08)] p-6 sm:px-8 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6 relative overflow-hidden">
                        
                        <div className="absolute top-0 left-0 w-1 h-full bg-red-600"></div>

                        <div className="flex items-start gap-4">
                            <div className="p-3 bg-red-50 border border-red-100 rounded-full shrink-0">
                                <Cookie className="w-6 h-6 text-red-700" />
                            </div>
                            <div>
                                <h3 className="text-slate-900 font-black text-sm sm:text-base mb-1">Cookie Preferences</h3>
                                <p className="text-slate-500 font-medium text-xs sm:text-sm leading-relaxed max-w-2xl">
                                    We use cookies to secure your session and improve platform performance. Strictly necessary authentication cookies are always active.
                                </p>
                            </div>
                        </div>

                        <div className="flex items-center gap-3 w-full sm:w-auto shrink-0">
                            <button
                                onClick={handleIgnoreCookies}
                                className="flex-1 sm:flex-none px-6 py-3 rounded-xl border border-slate-200 text-slate-600 text-xs font-bold uppercase tracking-wider hover:bg-slate-50 hover:text-slate-900 transition-colors shadow-sm"
                            >
                                Ignore
                            </button>
                            <button
                                onClick={handleAcceptCookies}
                                className="flex-1 sm:flex-none px-6 py-3 rounded-xl bg-slate-900 text-white text-xs font-bold uppercase tracking-wider hover:bg-slate-800 transition-colors shadow-lg"
                            >
                                Accept All
                            </button>
                            <button 
                                onClick={handleIgnoreCookies}
                                className="hidden sm:flex p-2 text-slate-400 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors ml-2"
                                aria-label="Close"
                            >
                                <X className="w-5 h-5" />
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}