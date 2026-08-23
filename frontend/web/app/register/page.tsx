"use client";

import React, { useState } from 'react';
import { createUserWithEmailAndPassword, deleteUser } from 'firebase/auth';
import { auth } from '../firebase/config'; 
import Link from 'next/link';
import { ShieldCheck, Loader2, CheckCircle2, Lock } from 'lucide-react';
import { apiFetch } from '../components/api';

export default function RegisterLandlord() {
    // State for all model fields
    const [name, setName] = useState<string>('');
    const [surname, setSurname] = useState<string>('');
    const [email, setEmail] = useState<string>('');
    const [phone, setPhone] = useState<string>('');
    const [password, setPassword] = useState<string>('');
    
    // Banking Details State
    const [businessName, setBusinessName] = useState<string>('');
    const [bankCode, setBankCode] = useState<string>('');
    const [accountNumber, setAccountNumber] = useState<string>('');
    
    // Checkbox state for terms and conditions
    const [acceptedTerms, setAcceptedTerms] = useState<boolean>(false);
    
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState<boolean>(false);
    const [success, setSuccess] = useState<boolean>(false);

    interface BackendRegisterRequest {
        firebase_uid: string;
        email: string;
        name: string;
        surname: string;
        phone: string;
        business_name: string;
        bank_code: string;
        account_number: string;
    }

    const handleRegister = async (e: React.FormEvent<HTMLFormElement>): Promise<void> => {
        e.preventDefault();
        setError(null);
        
        if (!acceptedTerms) {
            setError('You must accept the Terms & Conditions and Privacy Policy to register.');
            return;
        }

        if (!bankCode) {
            setError('Please select a bank to configure your payout account.');
            return;
        }
        
        setLoading(true);

        try {
            // 1. Create the account in Firebase (using email/password)
            const userCredential = await createUserWithEmailAndPassword(auth, email, password);
            const user = userCredential.user;

            try {
                // 2. Sync all professional details and banking to Django
                const requestBody: BackendRegisterRequest = {
                    firebase_uid: user.uid,
                    email: email,
                    name: name,
                    surname: surname,
                    phone: phone,
                    business_name: businessName,
                    bank_code: bankCode,
                    account_number: accountNumber,
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
        <div className="min-h-screen bg-[#020617] relative overflow-hidden flex items-center justify-center p-6 text-slate-100 font-sans py-12">
            
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

                        <div className="w-full h-[1px] bg-slate-800/60 my-8"></div>

                        {/* Secure Banking Section */}
                        <div className="space-y-6 bg-blue-950/20 border border-blue-900/30 p-6 rounded-2xl">
                            
                            <div className="flex items-start gap-4">
                                <div className="p-3 bg-blue-500/10 rounded-lg text-blue-400">
                                    <Lock className="w-6 h-6" />
                                </div>
                                <div>
                                    <h3 className="text-sm font-bold text-white mb-1">Payout Configuration (Encrypted)</h3>
                                    <p className="text-xs text-slate-400 leading-relaxed">
                                        These banking details are strictly used to provision your automated zero-fee split payment merchant account. Student payments are routed directly to this account. Your data is heavily encrypted and never shared.
                                    </p>
                                </div>
                            </div>

                            <div className="space-y-1.5">
                                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Registered Business / Account Name</label>
                                <input
                                    type="text"
                                    required
                                    value={businessName}
                                    onChange={(e) => setBusinessName(e.target.value)}
                                    className="w-full px-5 py-4 bg-slate-900/80 text-white placeholder-slate-600 border border-slate-700/50 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                    placeholder="Company or Individual Name"
                                />
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 w-full">
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Bank Name</label>
                                    <select
                                        required
                                        value={bankCode}
                                        onChange={(e) => setBankCode(e.target.value)}
                                        className="w-full px-5 py-4 bg-slate-900/80 text-white border border-slate-700/50 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm appearance-none"
                                    >
                                        <option value="" disabled>Select your bank</option>
                                        <option value="250655">First National Bank (FNB)</option>
                                        <option value="051001">Standard Bank</option>
                                        <option value="632005">Absa Bank</option>
                                        <option value="198765">Nedbank</option>
                                        <option value="470010">Capitec Bank</option>
                                        <option value="679000">Discovery Bank</option>
                                        <option value="678910">TymeBank</option>
                                        <option value="580105">Investec</option>
                                    </select>
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Account Number</label>
                                    <input
                                        type="password"
                                        required
                                        value={accountNumber}
                                        onChange={(e) => setAccountNumber(e.target.value)}
                                        className="w-full px-5 py-4 bg-slate-900/80 text-white placeholder-slate-600 border border-slate-700/50 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm font-mono tracking-widest"
                                        placeholder="••••••••••"
                                    />
                                </div>
                            </div>
                        </div>

                        {/* Terms and Conditions Checkbox */}
                        <div className="flex items-start gap-3 pt-4">
                            <div className="flex items-center h-5">
                                <input
                                    id="terms"
                                    type="checkbox"
                                    checked={acceptedTerms}
                                    onChange={(e) => setAcceptedTerms(e.target.checked)}
                                    className="w-4 h-4 rounded border-slate-700 bg-slate-900/50 text-blue-600 focus:ring-blue-500/50 focus:ring-offset-slate-900 cursor-pointer"
                                />
                            </div>
                            <label htmlFor="terms" className="text-[11px] text-slate-400 leading-relaxed cursor-pointer">
                                I have read and agree to the{' '}
                                <Link href="../terms-and-conditions" className="text-blue-400 hover:underline transition-colors" target="_blank">Terms & Conditions</Link>
                                {' '}and{' '}
                                <Link href="../privacy-policy" className="text-blue-400 hover:underline transition-colors" target="_blank">Privacy Policy</Link>.
                            </label>
                        </div>

                        <div className="pt-4">
                            <button
                                type="submit"
                                disabled={loading || !acceptedTerms}
                                className="w-full h-14 rounded-xl text-white font-bold tracking-[0.15em] text-xs transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center bg-blue-600 hover:bg-blue-500 shadow-lg shadow-blue-600/20 active:scale-[0.98]"
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