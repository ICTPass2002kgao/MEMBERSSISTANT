"use client";

import React, { useState, useRef, useEffect, KeyboardEvent, ClipboardEvent } from 'react';
import { createUserWithEmailAndPassword, deleteUser } from 'firebase/auth';
import { auth } from '../firebase/config'; // Adjust path based on your structure
import Link from 'next/link';
import { 
    UserPlus, 
    Loader2, 
    CheckCircle2, 
    UploadCloud, 
    FileText, 
    CheckCircle,
    ShieldCheck,
    MailCheck,
    ArrowLeft
} from 'lucide-react';
import { BASE_URL, apiFetch } from '../components/api'; // Adjust path based on your structure

export default function RegisterStudent() {
    // Multi-step Registration State
    // 1 = Form, 2 = OTP Verification, 3 = Success
    const [step, setStep] = useState<number>(1);

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
    
    // OTP State
    const [otp, setOtp] = useState<string[]>(new Array(6).fill(""));
    const [expectedOtp, setExpectedOtp] = useState<string>("");
    const [activeOTPIndex, setActiveOTPIndex] = useState<number>(0);
    const inputRef = useRef<HTMLInputElement[]>([]);

    // Loading & Error States
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState<boolean>(false);

    // ==========================================
    // STEP 1: HANDLE FORM SUBMISSION & SEND OTP
    // ==========================================
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
        
        setLoading(true);

        try {
            // 1. Generate 6-digit OTP
            const generatedOTP = Math.floor(100000 + Math.random() * 900000).toString();
            setExpectedOtp(generatedOTP);

            // 2. Send Email API Call
            // Replace this with your actual email sending endpoint logic
            /*
            await apiFetch('/send-email/', {
                method: 'POST',
                body: JSON.stringify({
                    email: email,
                    subject: "Verification Code",
                    message: `Hello ${name} ${surname},\n\nYour 6-digit verification code is: ${generatedOTP}\n\nThis code expires soon.`
                })
            });
            */
            
            // Simulating network delay for email sending
            await new Promise(resolve => setTimeout(resolve, 1000));
            console.log("Mock OTP Sent:", generatedOTP); // Remove in production

            // 3. Move to OTP Step
            setStep(2);
            
            // Focus first OTP input after render
            setTimeout(() => {
                inputRef.current[0]?.focus();
            }, 100);

        } catch (err: any) {
            setError(err.message || 'Failed to send verification email. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    // ==========================================
    // STEP 2: OTP VERIFICATION LOGIC
    // ==========================================
    const handleOtpChange = (e: React.ChangeEvent<HTMLInputElement>, index: number): void => {
        const { value } = e.target;
        if (error) setError(null);
        if (!/^[0-9]*$/.test(value)) return;

        const newOTP: string[] = [...otp];
        newOTP[index] = value.substring(value.length - 1);
        setOtp(newOTP);

        if (value && index < 5) {
            setActiveOTPIndex(index + 1);
            inputRef.current[index + 1]?.focus();
        }

        if (value && index === 5 && newOTP.every((val) => val !== "")) {
            verifyAndRegister(newOTP.join(""));
        }
    };

    const handleOtpKeyDown = (e: KeyboardEvent<HTMLInputElement>, index: number): void => {
        if (e.key === "Backspace") {
            e.preventDefault();
            const newOTP = [...otp];
            if (otp[index]) {
                newOTP[index] = "";
                setOtp(newOTP);
            } else if (index > 0) {
                newOTP[index - 1] = "";
                setOtp(newOTP);
                setActiveOTPIndex(index - 1);
                inputRef.current[index - 1]?.focus();
            }
        }
    };

    const verifyAndRegister = async (enteredOtp?: string) => {
        const codeToVerify = enteredOtp || otp.join("");
        if (codeToVerify.length !== 6) {
            setError("Please enter the complete 6-digit code.");
            return;
        }

        setLoading(true);
        setError(null);

        // Verify OTP
        if (codeToVerify !== expectedOtp) {
            setError("Wrong code, please try again.");
            setOtp(new Array(6).fill(""));
            inputRef.current[0]?.focus();
            setLoading(false);
            return;
        }

        // If OTP is correct, proceed with Firebase & Backend Registration
        try {
            const userCredential = await createUserWithEmailAndPassword(auth, email, password);
            const user = userCredential.user;

            try {
                const formData = new FormData();
                formData.append('firebase_uid', user.uid);
                formData.append('student_number', studentNo);
                formData.append('name', name);
                formData.append('surname', surname);
                formData.append('id_number', idNumber);
                formData.append('gender', gender);
                formData.append('phone', phone);
                formData.append('email', email);
                
                if (idDocument) formData.append('id_document', idDocument);
                if (proofOfRegistration) formData.append('proof_of_registration', proofOfRegistration);

                const response = await fetch(`${BASE_URL || 'http://localhost:8000'}/student-self-register/`, {
                    method: 'POST',
                    body: formData,
                });

                if (!response.ok) {
                    const errorData = await response.json();
                    throw new Error(errorData.error || 'Failed to register student on the server.');
                }

                setStep(3); // Success Screen
                
            } catch (backendErr: any) {
                await deleteUser(user);
                throw new Error(`Registration Sync Failed: ${backendErr.message}`);
            }

        } catch (err: any) {
            setError(err.message.replace('Firebase: ', ''));
            // If creation fails, we keep them on the OTP screen but show the error
        } finally {
            setLoading(false);
        }
    };

    const handleResendOtp = async () => {
        setLoading(true);
        setError(null);
        try {
            const newOTP = Math.floor(100000 + Math.random() * 900000).toString();
            setExpectedOtp(newOTP);
            // Replace with your actual email logic
            await new Promise(resolve => setTimeout(resolve, 1000)); 
            alert("A new code has been sent to your email.");
            setOtp(new Array(6).fill(""));
            inputRef.current[0]?.focus();
        } catch (err) {
            setError("Failed to resend code. Please try again.");
        } finally {
            setLoading(false);
        }
    };

    // ==========================================
    // RENDER LOGIC
    // ==========================================

    if (step === 3) {
        return (
            <div className="min-h-screen bg-slate-50 relative flex items-center justify-center p-6 text-slate-800 font-sans">
                <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-red-600/5 blur-[120px] pointer-events-none"></div>
                <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-red-900/5 blur-[120px] pointer-events-none"></div>

                <div className="p-10 sm:p-14 rounded-[32px] bg-white/80 backdrop-blur-xl border border-white/60 shadow-[0_8px_30px_rgb(0,0,0,0.06)] flex flex-col items-center max-w-md w-full relative overflow-hidden z-10 text-center animate-in zoom-in duration-300">
                    <div className="absolute top-0 left-0 w-full h-1 bg-emerald-500"></div>
                    
                    <div className="w-20 h-20 bg-emerald-50 text-emerald-500 rounded-full flex items-center justify-center mb-6 shadow-inner border border-emerald-100">
                        <CheckCircle2 className="w-10 h-10" strokeWidth={2} />
                    </div>
                    
                    <h2 className="text-3xl font-black tracking-tight mb-3 text-slate-900">Registration Complete!</h2>
                    <p className="text-slate-500 mb-8 font-medium">Your student profile has been successfully created. You can now log in to apply for residences.</p>
                    
                    <Link href="/login" className="w-full py-4 rounded-xl bg-gradient-to-r from-red-800 to-red-700 text-white font-black uppercase tracking-wider shadow-lg shadow-red-900/20 hover:from-red-900 hover:to-red-800 transition-all hover:-translate-y-0.5 block">
                        PROCEED TO LOGIN
                    </Link>
                </div>
            </div>
        );
    }

    if (step === 2) {
        return (
            <div className="min-h-screen bg-slate-50 relative flex items-center justify-center p-6 text-slate-800 font-sans">
                <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-red-600/5 blur-[120px] pointer-events-none z-0"></div>
                <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-red-900/5 blur-[120px] pointer-events-none z-0"></div>

                <div className="z-10 w-full max-w-md"> 
                    <button 
                        onClick={() => setStep(1)} 
                        className="mb-6 flex items-center gap-2 text-xs font-bold text-slate-500 hover:text-red-700 transition-colors uppercase tracking-widest"
                    >
                        <ArrowLeft className="w-4 h-4" /> Back to form
                    </button>

                    <div className="p-8 sm:p-12 rounded-[32px] bg-white/80 backdrop-blur-xl border border-white/60 shadow-[0_8px_30px_rgb(0,0,0,0.06)] flex flex-col items-center relative overflow-hidden animate-in slide-in-from-right-8 duration-300">
                        <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-red-800 to-red-500"></div>

                        <div className="p-5 rounded-full bg-red-50 border border-red-100 mb-6 shadow-sm">
                            <MailCheck className="w-10 h-10 text-red-700" strokeWidth={1.5} />
                        </div>

                        <h2 className="text-3xl font-black tracking-tight mb-2 text-center text-slate-900">
                            Verification
                        </h2>
                        <p className="text-slate-500 text-sm font-medium text-center mb-1">
                            Enter the 6-digit code we sent to:
                        </p>
                        <p className="text-red-700 font-bold text-center mb-8">
                            {email}
                        </p>

                        <div className="flex justify-between w-full gap-2 mb-8">
                            {otp.map((_, index) => (
                                <input
                                    key={index}
                                    ref={(el) => { inputRef.current[index] = el!; }}
                                    type="text"
                                    inputMode="numeric"
                                    maxLength={1}
                                    value={otp[index]}
                                    onChange={(e) => handleOtpChange(e, index)}
                                    onKeyDown={(e) => handleOtpKeyDown(e, index)}
                                    onFocus={(e) => e.target.select()}
                                    className="w-12 h-14 sm:w-14 sm:h-16 text-center text-2xl font-black text-red-700 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all shadow-sm selection:bg-red-200"
                                />
                            ))}
                        </div>

                        {error && (
                            <div className="w-full bg-rose-50 border border-rose-200 text-rose-700 px-5 py-3 rounded-xl mb-6 text-xs font-bold text-center shadow-sm">
                                {error}
                            </div>
                        )}

                        <button
                            onClick={() => verifyAndRegister()}
                            disabled={loading || otp.join("").length !== 6}
                            className="w-full h-14 rounded-xl text-white font-black tracking-[0.15em] text-xs transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center bg-gradient-to-r from-red-800 to-red-700 hover:from-red-900 hover:to-red-800 shadow-lg shadow-red-900/20 active:scale-[0.98]"
                        >
                            {loading ? (
                                <div className="flex items-center gap-3">
                                    <Loader2 className="animate-spin w-5 h-5 text-white" />
                                    <span>VERIFYING & REGISTERING...</span>
                                </div>
                            ) : 'VERIFY ACCOUNT'}
                        </button>

                        <div className="mt-8 text-center pt-6 border-t border-slate-200/60 w-full flex flex-col items-center gap-2">
                            <p className="text-xs font-medium text-slate-500">Didn't receive the code?</p>
                            <button 
                                onClick={handleResendOtp}
                                disabled={loading}
                                className="text-sm font-bold text-red-700 hover:text-red-800 transition-colors disabled:opacity-50 flex items-center gap-2"
                            >
                                {loading ? <><Loader2 className="w-3 h-3 animate-spin"/> Sending...</> : 'Resend Code'}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        );
    }

    // Default Render: Step 1 (Form)
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