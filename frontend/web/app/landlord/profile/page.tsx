"use client";

import React, { useState, useEffect } from 'react';
import { User, Phone, Mail, AlertCircle, CheckCircle2, ShieldAlert, Smartphone, ShieldCheck } from 'lucide-react';
import { apiFetch } from '../../components/api'; 
import { SectionHeader, Input, SubmitButton } from '../../components/SharedUI';

interface LandlordData {
    id?: string;
    firebase_uid?: string;
    name?: string;
    surname?: string;
    phone?: string;
    email?: string;
    is_verified?: boolean;
    manual_verification_status?: boolean;
    digital_verification_status?: boolean;
    seller_paystack_account?: string;
}

export default function LandlordProfilePage() {
    const [formData, setFormData] = useState<LandlordData>({});
    const [loading, setLoading] = useState<boolean>(true);
    const [saving, setSaving] = useState<boolean>(false);
    const [message, setMessage] = useState({ type: '', text: '' });

    useEffect(() => {
        // 1. Check local storage for instantaneous display
        const storedUserData = localStorage.getItem('user_data');
        if (storedUserData) {
            try {
                const parsedRaw = JSON.parse(storedUserData);
                const parsed = parsedRaw.user_data ? parsedRaw.user_data : parsedRaw;
                if (parsed && (parsed.id || parsed.email)) {
                    setFormData(parsed);
                }
            } catch (e) {
                console.error("Failed to parse local user data.");
            }
        }

        // 2. Fetch directly from backend /landlords/me/ using the authenticated Bearer token
        const fetchProfile = async () => {
            try {
                const data = await apiFetch('/landlords/me/');
                if (data && (data.id || data.email)) {
                    setFormData(data);
                    localStorage.setItem('user_data', JSON.stringify(data));
                }
            } catch (err) {
                console.error("Failed to fetch fresh profile data:", err);
            } finally {
                setLoading(false);
            }
        };
        
        fetchProfile();
    }, []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);
        setMessage({ type: '', text: '' });

        try {
            const response = await apiFetch(`/landlords/${formData.id}/`, {
                method: 'PATCH',
                body: JSON.stringify({
                    name: formData.name,
                    surname: formData.surname,
                    phone: formData.phone,
                })
            });

            localStorage.setItem('user_data', JSON.stringify(response));
            setFormData(response);
            setMessage({ type: 'success', text: 'Profile updated successfully!' });
            
            setTimeout(() => window.location.reload(), 1500);
            
        } catch (err: any) {
            setMessage({ type: 'error', text: err.message || 'Failed to update profile.' });
        } finally {
            setSaving(false);
        }
    };

    if (loading && !formData.email && !formData.id) {
        return (
            <div className="py-20 flex justify-center items-center">
                <Loader2 className="animate-spin text-blue-500 w-10 h-10" />
            </div>
        );
    }

    const isBasicInfoComplete = Boolean(formData.name && formData.surname && formData.phone);
    const isVerified = Boolean(formData.is_verified);

    return (
        <div className="max-w-4xl mx-auto space-y-8 animate-in fade-in duration-500">
            <SectionHeader title="Professional Profile" />
            
            {/* Missing Configuration Alerts */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {!isBasicInfoComplete && (
                    <div className="p-5 bg-amber-50 border border-amber-200 rounded-[24px] flex items-start gap-4 text-amber-700 shadow-sm">
                        <AlertCircle size={24} className="shrink-0 mt-0.5" />
                        <div>
                            <p className="font-black text-sm tracking-tight mb-1">Missing Basic Info</p>
                            <p className="text-xs leading-relaxed font-medium">Please provide your First Name, Surname, and Phone Number below to identify yourself in the system.</p>
                        </div>
                    </div>
                )}

                {!isVerified && (
                    <div className="p-5 bg-rose-50 border border-rose-200 rounded-[24px] flex items-start gap-4 text-rose-700 shadow-sm mb-4">
                        <ShieldAlert size={24} className="shrink-0 mt-0.5" />
                        <div>
                            <p className="font-black text-sm tracking-tight mb-1">Identity Unverified</p>
                            <p className="text-xs leading-relaxed font-medium mb-2">You must complete biometric verification via our mobile app to register properties or admit students.</p>
                            <p className="text-[10px] uppercase tracking-wider font-black bg-rose-200/50 inline-block px-2 py-1 rounded">
                                Please Note: As soon as your verification is successful, your 1-month free trial immediately starts. 
                            </p>
                            <br /><p className="text-[10px] uppercase tracking-wider font-stretch-200% text-white bg-green-600 inline-block px-2 py-1 mt-2 rounded ">
And you can be able to unsubscribe at any time before the trial ends.                            </p>
                        </div>
                    </div>
                )}
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                
                {/* Main Profile Form */}
                <div className="lg:col-span-2 bg-white border border-blue-50 rounded-[32px] p-8 shadow-xl shadow-blue-900/5">
                    <h3 className="text-lg font-black text-blue-950 mb-6 tracking-tight">Personal Details</h3>
                    <form onSubmit={handleSubmit} className="space-y-6">
                        {message.text && (
                            <div className={`p-4 rounded-2xl text-sm font-bold flex items-center gap-3 ${message.type === 'error' ? 'bg-rose-50 text-rose-600 border border-rose-100' : 'bg-emerald-50 text-emerald-600 border border-emerald-100'}`}>
                                {message.type === 'success' ? <CheckCircle2 size={20} /> : <AlertCircle size={20} />}
                                {message.text}
                            </div>
                        )}

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                            <Input 
                                label="First Name" 
                                value={formData.name || ''} 
                                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setFormData({...formData, name: e.target.value})} 
                                required 
                                icon={User}
                            />
                            <Input 
                                label="Surname" 
                                value={formData.surname || ''} 
                                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setFormData({...formData, surname: e.target.value})} 
                                required 
                                icon={User}
                            />
                        </div>

                        <Input 
                            label="Phone Number" 
                            value={formData.phone || ''} 
                            onChange={(e: React.ChangeEvent<HTMLInputElement>) => setFormData({...formData, phone: e.target.value})} 
                            required 
                            placeholder="e.g. 082 123 4567"
                            icon={Phone}
                        />

                        <div className="pt-6 border-t border-blue-50">
                            <Input 
                                label="Email Address (Login ID)" 
                                value={formData.email || ''} 
                                disabled 
                                icon={Mail}
                            />
                            <p className="text-[10px] text-slate-400 font-bold tracking-widest uppercase mt-2 ml-1">Email cannot be changed directly for security reasons.</p>
                        </div>

                        <div className="pt-4">
                            <SubmitButton loading={saving} text="SAVE PROFILE DETAILS" />
                        </div>
                    </form>
                </div>

                {/* Mobile Verification Block */}
                <div className="bg-slate-900 rounded-[32px] p-8 shadow-xl shadow-slate-900/20 text-white relative overflow-hidden flex flex-col justify-between">
                    <div className="absolute top-[-50px] right-[-50px] w-40 h-40 bg-blue-500/20 blur-[50px] rounded-full pointer-events-none"></div>

                    <div>
                        <div className="w-12 h-12 rounded-2xl bg-white/10 flex items-center justify-center border border-white/10 mb-6">
                            {isVerified ? <ShieldCheck size={24} className="text-emerald-400" /> : <Smartphone size={24} className="text-blue-400" />}
                        </div>

                        <h3 className="text-xl font-black tracking-tight mb-2">
                            {isVerified ? "Security Verified" : "Mobile Verification"}
                        </h3>
                        
                        {isVerified ? (
                            <p className="text-sm text-slate-400 leading-relaxed font-medium">
                                Your biometrics and legal documents have been successfully verified. Your account is fully active and secured.
                            </p>
                        ) : (
                            <div className="space-y-4">
                                <p className="text-sm text-slate-400 leading-relaxed font-medium">
                                    To unlock platform features, you must securely verify your identity using your smartphone.
                                </p>
                                <ul className="text-xs text-slate-300 space-y-2 font-medium">
                                    <li className="flex items-center gap-2"><span className="w-1.5 h-1.5 rounded-full bg-blue-500"></span> Download the Mobile App</li>
                                    <li className="flex items-center gap-2"><span className="w-1.5 h-1.5 rounded-full bg-blue-500"></span> Log in with your email</li>
                                    <li className="flex items-center gap-2"><span className="w-1.5 h-1.5 rounded-full bg-blue-500"></span> Follow the on-screen prompts</li>
                                </ul>
                            </div>
                        )}
                    </div>

                    {!isVerified && (
                        <div className="mt-8 space-y-3">
                            <a href="#" className="w-full flex items-center gap-4 bg-white/10 hover:bg-white/20 border border-white/10 p-3 rounded-2xl transition-all group">
                                <svg className="w-6 h-6 fill-white" viewBox="0 0 384 512" xmlns="http://www.w3.org/2000/svg">
                                    <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"/>
                                </svg>
                                <div className="flex flex-col text-left">
                                    <span className="text-[9px] font-bold text-slate-400 uppercase tracking-widest">Download on the</span>
                                    <span className="text-sm font-black text-white leading-none">App Store</span>
                                </div>
                            </a>

                            <a href="#" className="w-full flex items-center gap-4 bg-white/10 hover:bg-white/20 border border-white/10 p-3 rounded-2xl transition-all group">
                                <svg className="w-6 h-6 fill-white" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
                                    <path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l256.6-256L47 0zm425.2 225.6l-58.9-34.1-65.7 64.5 65.7 64.5 60.1-34.1c18-14.3 18-46.5-1.2-60.8zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z"/>
                                </svg>
                                <div className="flex flex-col text-left">
                                    <span className="text-[9px] font-bold text-slate-400 uppercase tracking-widest">GET IT ON</span>
                                    <span className="text-sm font-black text-white leading-none">Google Play</span>
                                </div>
                            </a>

                            <a href="#" className="w-full flex items-center gap-4 bg-white/10 hover:bg-white/20 border border-white/10 p-3 rounded-2xl transition-all group">
                                <div className="w-6 h-6 flex items-center justify-center bg-red-600 rounded-md">
                                    <svg className="w-4 h-4 fill-white" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm3.53 14.53l-1.06 1.06-4.59-4.59v-5h1.5v4.38l4.15 4.15z"/>
                                    </svg>
                                </div>
                                <div className="flex flex-col text-left">
                                    <span className="text-[9px] font-bold text-slate-400 uppercase tracking-widest">EXPLORE IT ON</span>
                                    <span className="text-sm font-black text-white leading-none">AppGallery</span>
                                </div>
                            </a>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}

function Loader2({ className }: { className?: string }) {
    return (
        <svg className={`animate-spin ${className}`} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
    );
}