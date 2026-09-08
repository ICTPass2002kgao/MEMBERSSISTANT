"use client";

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { 
    UserPlus, 
    Loader2, 
    CheckCircle, 
    UploadCloud, 
    FileText, 
    ShieldCheck
} from 'lucide-react';
import Link from 'next/link';
import { sendEmail } from '../components/api';
import { setRegistrationData, setExpectedOtp } from '../../lib/registrationStore';

export default function RegisterStudent() {
    const router = useRouter();

    // Student Details State
    const [studentNo, setStudentNo] = useState<string>('');
    const [name, setName] = useState<string>('');
    const [surname, setSurname] = useState<string>('');
    const [idNumber, setIdNumber] = useState<string>('');
    const [phone, setPhone] = useState<string>('');
    const [email, setEmail] = useState<string>('');
    const [gender, setGender] = useState<string>('MALE');
    const [password, setPassword] = useState<string>('');
    
    // File Upload State
    const [idDocument, setIdDocument] = useState<File | null>(null);
    const [proofOfRegistration, setProofOfRegistration] = useState<File | null>(null);
    const [acceptedTerms, setAcceptedTerms] = useState<boolean>(false);
    
    // Loading & Error States
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState<boolean>(false);

    const handleInitialSubmit = async (e: React.FormEvent<HTMLFormElement>): Promise<void> => {
        e.preventDefault();
        setError(null);
        
        if (idNumber.length !== 13) {
            setError('Please provide a valid 13-digit Identification Number.');
            return;
        }

        if (!acceptedTerms) {
            setError('You must accept the Terms & Conditions and Privacy Policy to register.');
            return;
        }

        // Additional validation: ensure all required text fields are non-empty
        if (
            !studentNo.trim() ||
            !name.trim() ||
            !surname.trim() ||
            !phone.trim() ||
            !email.trim() ||
            !password.trim()
        ) {
            setError('All required fields must be filled in.');
            return;
        }
        
        setLoading(true);

        try {
            // 1. Generate 6-digit OTP
            const generatedOTP = Math.floor(100000 + Math.random() * 900000).toString();
            
            // 2. Send Email
            await sendEmail(
                email,
                "Verification Code",
                `Hello ${name} ${surname},\n\nYour 6-digit verification code is: ${generatedOTP}\n\nThis code expires soon.`
            );

            // 3. Store registration data and expected OTP in shared store
            setRegistrationData({
                studentNo,
                name,
                surname,
                idNumber,
                phone,
                email,
                gender,
                password,
                idDocument,
                proofOfRegistration,
                acceptedTerms,
            });
            setExpectedOtp(generatedOTP);
 
            router.push(`/verify-email?email=${encodeURIComponent(email)}`);

        } catch (err: any) {
            setError(err.message || 'Failed to send verification email. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-slate-50 relative overflow-hidden flex items-center justify-center p-6 text-slate-800 font-sans py-12">
            <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-red-600/5 blur-[120px] pointer-events-none"></div>
            <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-red-900/5 blur-[120px] pointer-events-none"></div>

            <div className="z-10 w-full max-w-3xl animate-in slide-in-from-left-8 duration-300">
                <div className="p-8 sm:p-12 rounded-[32px] bg-white/80 backdrop-blur-xl border border-white/60 shadow-[0_8px_30px_rgb(0,0,0,0.06)] flex flex-col relative overflow-hidden">
                    <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-red-800 to-red-500"></div>

                    <div className="flex flex-col items-center mb-10">
                        <div className="p-4 rounded-2xl bg-red-50 border border-red-100 mb-6 shadow-sm">
                            <UserPlus className="w-10 h-10 text-red-700" strokeWidth={1.5} />
                        </div>
                        <h2 className="text-3xl font-black tracking-tight mb-2 text-center text-slate-900">
                            Student Registration
                        </h2>
                        <p className="text-red-700 tracking-[0.2em] text-center text-[10px] font-bold uppercase">
                            CREATE YOUR PROFILE
                        </p>
                    </div>

                    {error && (
                        <div className="w-full bg-rose-50 border border-rose-200 text-rose-700 px-5 py-4 rounded-xl mb-8 text-xs font-bold flex items-center gap-3 shadow-sm">
                            <ShieldCheck className="w-5 h-5 shrink-0" />
                            <p>{error}</p>
                        </div>
                    )}

                    <form className="w-full space-y-8" onSubmit={handleInitialSubmit}>
                        <div className="space-y-6">
                            <h3 className="text-sm font-black text-slate-900 uppercase tracking-widest border-b border-slate-200 pb-2">Personal Information</h3>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">First Name</label>
                                    <input
                                        type="text" required value={name} onChange={(e) => setName(e.target.value)}
                                        className="w-full px-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                        placeholder="John"
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Last Name</label>
                                    <input
                                        type="text" required value={surname} onChange={(e) => setSurname(e.target.value)}
                                        className="w-full px-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                        placeholder="Doe"
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">ID / Passport Number</label>
                                    <input
                                        type="text" required value={idNumber} onChange={(e) => setIdNumber(e.target.value)}
                                        className="w-full px-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                        placeholder="13-Digit ID"
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Gender</label>
                                    <select
                                        required value={gender} onChange={(e) => setGender(e.target.value)}
                                        className="w-full px-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900 appearance-none"
                                    >
                                        <option value="MALE">Male</option>
                                        <option value="FEMALE">Female</option>
                                    </select>
                                </div>
                            </div>
                        </div>

                        <div className="space-y-6">
                            <h3 className="text-sm font-black text-slate-900 uppercase tracking-widest border-b border-slate-200 pb-2">Academic & Contact</h3>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Student Number</label>
                                    <input
                                        type="number" required value={studentNo} onChange={(e) => setStudentNo(e.target.value)}
                                        className="w-full px-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                        placeholder="e.g. 219000000"
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Phone Number</label>
                                    <input
                                        type="tel" required value={phone} onChange={(e) => setPhone(e.target.value)}
                                        className="w-full px-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                        placeholder="060 000 0000"
                                    />
                                </div>
                            </div>
                        </div>

                        <div className="space-y-6 bg-red-50/50 p-6 rounded-2xl border border-red-100">
                            <h3 className="text-sm font-black text-red-900 uppercase tracking-widest mb-4">Account Security</h3>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-600 uppercase tracking-widest pl-1">Email Address</label>
                                    <input
                                        type="email" required value={email} onChange={(e) => setEmail(e.target.value)}
                                        className="w-full px-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                        placeholder="student@domain.com"
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-600 uppercase tracking-widest pl-1">Password</label>
                                    <input
                                        type="password" required minLength={6} value={password} onChange={(e) => setPassword(e.target.value)}
                                        className="w-full px-5 py-4 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all text-sm font-medium shadow-sm text-slate-900"
                                        placeholder="••••••••••••"
                                    />
                                </div>
                            </div>
                        </div>

                        <div className="space-y-6">
                            <h3 className="text-sm font-black text-slate-900 uppercase tracking-widest border-b border-slate-200 pb-2 flex items-center gap-2">
                                <FileText className="w-4 h-4 text-slate-400" /> Verification Documents
                            </h3>
                            <p className="text-xs text-slate-500 font-medium">To maintain community security, please upload your verification documents (Optional during initial sign up, but required for applying).</p>
                            
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                <div className={`relative p-4 rounded-2xl border-2 transition-all ${idDocument ? 'border-emerald-500 bg-emerald-50' : 'border-dashed border-slate-300 bg-slate-50 hover:bg-slate-100'}`}>
                                    <input 
                                        type="file" accept=".pdf, .jpg, .jpeg, .png"
                                        onChange={(e) => setIdDocument(e.target.files ? e.target.files[0] : null)}
                                        className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                                    />
                                    <div className="flex items-center gap-4">
                                        <div className={`p-2 rounded-xl shadow-sm border ${idDocument ? 'bg-emerald-500 text-white border-emerald-600' : 'bg-white text-slate-400 border-slate-200'}`}>
                                            {idDocument ? <CheckCircle className="w-5 h-5"/> : <UploadCloud className="w-5 h-5"/>}
                                        </div>
                                        <div className="overflow-hidden">
                                            <p className={`font-bold text-sm truncate ${idDocument ? 'text-emerald-900' : 'text-slate-700'}`}>
                                                {idDocument ? idDocument.name : 'Upload ID Document'}
                                            </p>
                                        </div>
                                    </div>
                                </div>

                                <div className={`relative p-4 rounded-2xl border-2 transition-all ${proofOfRegistration ? 'border-emerald-500 bg-emerald-50' : 'border-dashed border-slate-300 bg-slate-50 hover:bg-slate-100'}`}>
                                    <input 
                                        type="file" accept=".pdf, .jpg, .jpeg, .png"
                                        onChange={(e) => setProofOfRegistration(e.target.files ? e.target.files[0] : null)}
                                        className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                                    />
                                    <div className="flex items-center gap-4">
                                        <div className={`p-2 rounded-xl shadow-sm border ${proofOfRegistration ? 'bg-emerald-500 text-white border-emerald-600' : 'bg-white text-slate-400 border-slate-200'}`}>
                                            {proofOfRegistration ? <CheckCircle className="w-5 h-5"/> : <UploadCloud className="w-5 h-5"/>}
                                        </div>
                                        <div className="overflow-hidden">
                                            <p className={`font-bold text-sm truncate ${proofOfRegistration ? 'text-emerald-900' : 'text-slate-700'}`}>
                                                {proofOfRegistration ? proofOfRegistration.name : 'Proof of Registration'}
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div className="flex items-start gap-3 pt-4">
                            <div className="flex items-center h-5">
                                <input
                                    id="terms" type="checkbox" checked={acceptedTerms} onChange={(e) => setAcceptedTerms(e.target.checked)}
                                    className="w-4 h-4 rounded border-slate-300 text-red-600 focus:ring-red-500 cursor-pointer"
                                />
                            </div>
                            <label htmlFor="terms" className="text-xs text-slate-500 font-medium leading-relaxed cursor-pointer">
                                I have read and agree to the{' '}
                                <Link href="/terms-and-conditions" className="text-red-600 font-bold hover:underline transition-colors" target="_blank">Terms & Conditions</Link>
                                {' '}and{' '}
                                <Link href="/privacy-policy" className="text-red-600 font-bold hover:underline transition-colors" target="_blank">Privacy Policy</Link>.
                            </label>
                        </div>

                        <div className="pt-4">
                            <button
                                type="submit"
                                disabled={loading || !acceptedTerms}
                                className="w-full h-14 rounded-xl text-white font-black tracking-[0.15em] text-xs transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center bg-gradient-to-r from-red-800 to-red-700 hover:from-red-900 hover:to-red-800 shadow-lg shadow-red-900/20 active:scale-[0.98]"
                            >
                                {loading ? (
                                    <div className="flex items-center gap-3">
                                        <Loader2 className="animate-spin w-5 h-5 text-white" />
                                        <span>SENDING CODE...</span>
                                    </div>
                                ) : 'PROCEED TO VERIFICATION'}
                            </button>
                        </div>
                    </form>

                    <div className="mt-8 text-center pt-8 border-t border-slate-200/60">
                        <Link href="/login" className="text-xs font-bold text-slate-500 hover:text-slate-800 transition-colors">
                            Already have a student account? <span className="text-red-600 ml-1 hover:underline underline-offset-4">Login here</span>
                        </Link>
                    </div>
                </div>
            </div>
        </div>
    );
}