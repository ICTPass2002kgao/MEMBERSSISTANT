"use client";

import React, { useState, useRef, useEffect, KeyboardEvent, ClipboardEvent } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { 
    ArrowLeft, 
    MailCheck, 
    Loader2, 
    ShieldCheck
} from 'lucide-react';
import { apiFetch } from '../components/api'; // Adjust path based on your structure

export default function OTPVerificationPage() {
    const router = useRouter();
    const searchParams = useSearchParams();
    const email = searchParams?.get('email') || 'your email address';

    const [otp, setOtp] = useState<string[]>(new Array(6).fill(""));
    const [activeOTPIndex, setActiveOTPIndex] = useState<number>(0);
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [isResending, setIsResending] = useState<boolean>(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<boolean>(false);

    const inputRef = useRef<HTMLInputElement[]>([]);

    useEffect(() => {
        // Auto-focus the first input on mount
        inputRef.current[0]?.focus();
    }, []);

    const handleChange = (e: React.ChangeEvent<HTMLInputElement>, index: number): void => {
        const { value } = e.target;
        if (error) setError(null);

        // Only allow numbers
        if (!/^[0-9]*$/.test(value)) return;

        const newOTP: string[] = [...otp];
        newOTP[index] = value.substring(value.length - 1);
        setOtp(newOTP);

        // Move to next input if value is entered
        if (value && index < 5) {
            setActiveOTPIndex(index + 1);
            inputRef.current[index + 1]?.focus();
        }

        // Auto verify if all 6 digits are filled
        if (value && index === 5 && newOTP.every((val) => val !== "")) {
            handleVerify(newOTP.join(""));
        }
    };

    const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>, index: number): void => {
        if (e.key === "Backspace") {
            e.preventDefault();
            const newOTP = [...otp];
            
            if (otp[index]) {
                // If there's a value in the current box, just clear it
                newOTP[index] = "";
                setOtp(newOTP);
            } else if (index > 0) {
                // If the current box is empty, clear the previous one and move focus back
                newOTP[index - 1] = "";
                setOtp(newOTP);
                setActiveOTPIndex(index - 1);
                inputRef.current[index - 1]?.focus();
            }
        } else if (e.key === "ArrowLeft" && index > 0) {
            e.preventDefault();
            setActiveOTPIndex(index - 1);
            inputRef.current[index - 1]?.focus();
        } else if (e.key === "ArrowRight" && index < 5) {
            e.preventDefault();
            setActiveOTPIndex(index + 1);
            inputRef.current[index + 1]?.focus();
        }
    };

    const handlePaste = (e: ClipboardEvent<HTMLInputElement>) => {
        e.preventDefault();
        const pastedData = e.clipboardData.getData("text/plain").trim();
        
        // Check if pasted data is exactly 6 numbers
        if (/^[0-9]{6}$/.test(pastedData)) {
            const pastedArray = pastedData.split("");
            setOtp(pastedArray);
            setActiveOTPIndex(5);
            inputRef.current[5]?.focus();
            handleVerify(pastedData);
        }
    };

    const handleVerify = async (otpCode?: string) => {
        const codeToVerify = otpCode || otp.join("");
        if (codeToVerify.length !== 6) {
            setError("Please enter the complete 6-digit code.");
            return;
        }

        setIsLoading(true);
        setError(null);

        try {
            // Replace with your actual verification API call
            /*
            const response = await apiFetch('/verify-otp/', {
                method: 'POST',
                body: JSON.stringify({ email, otp: codeToVerify })
            });
            */
            
            // Simulating network delay
            await new Promise(resolve => setTimeout(resolve, 1500));

            setSuccess(true);
            setTimeout(() => {
                // Redirect to login or next onboarding step after success
                router.push('/login');
            }, 2000);

        } catch (err: any) {
            setError(err.message || "Wrong code, please try again.");
            setOtp(new Array(6).fill(""));
            setActiveOTPIndex(0);
            inputRef.current[0]?.focus();
        } finally {
            setIsLoading(false);
        }
    };

    const handleResend = async () => {
        setIsResending(true);
        setError(null);
        
        try {
            // Replace with your actual resend API call
            /*
            await apiFetch('/resend-otp/', {
                method: 'POST',
                body: JSON.stringify({ email })
            });
            */
            await new Promise(resolve => setTimeout(resolve, 1500));
            alert("A new code has been sent to your email.");
            
            // Clear inputs for the new code
            setOtp(new Array(6).fill(""));
            setActiveOTPIndex(0);
            inputRef.current[0]?.focus();
        } catch (err: any) {
            setError("Failed to resend code. Please check your connection.");
        } finally {
            setIsResending(false);
        }
    };

    if (success) {
        return (
            <div className="min-h-screen bg-slate-50 relative flex items-center justify-center p-6 text-slate-800 font-sans">
                <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-red-600/5 blur-[120px] pointer-events-none"></div>
                <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-red-900/5 blur-[120px] pointer-events-none"></div>

                <div className="p-10 sm:p-14 rounded-[32px] bg-white/80 backdrop-blur-xl border border-white/60 shadow-[0_8px_30px_rgb(0,0,0,0.06)] flex flex-col items-center max-w-sm w-full relative overflow-hidden z-10 text-center animate-in zoom-in duration-300">
                    <div className="absolute top-0 left-0 w-full h-1 bg-emerald-500"></div>
                    
                    <div className="w-20 h-20 bg-emerald-50 text-emerald-500 rounded-full flex items-center justify-center mb-6 shadow-inner border border-emerald-100">
                        <ShieldCheck className="w-10 h-10" strokeWidth={2} />
                    </div>
                    
                    <h2 className="text-3xl font-black tracking-tight mb-3 text-slate-900">Verified!</h2>
                    <p className="text-slate-500 mb-2 font-medium">Your account has been successfully verified.</p>
                    <p className="text-slate-400 text-xs font-bold uppercase tracking-widest mt-4 animate-pulse">Redirecting to login...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-slate-50 relative overflow-hidden flex items-center justify-center p-6 text-slate-800 font-sans">
            
            {/* Global Background Glows */}
            <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-red-600/5 blur-[120px] pointer-events-none z-0"></div>
            <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-red-900/5 blur-[120px] pointer-events-none z-0"></div>

            <div className="z-10 w-full max-w-md animate-in slide-in-from-bottom-8 duration-300"> 
                {/* Back Button */}
                <button 
                    onClick={() => router.back()} 
                    className="mb-6 flex items-center gap-2 text-xs font-bold text-slate-500 hover:text-red-700 transition-colors uppercase tracking-widest"
                >
                    <ArrowLeft className="w-4 h-4" /> Go Back
                </button>

                <div className="p-8 sm:p-12 rounded-[32px] bg-white/80 backdrop-blur-xl border border-white/60 shadow-[0_8px_30px_rgb(0,0,0,0.06)] flex flex-col items-center relative overflow-hidden">
                    
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

                    {/* OTP Input Fields */}
                    <div className="flex justify-between w-full gap-2 mb-8">
                        {otp.map((_, index) => (
                            <input
                                key={index}
                                ref={(el) => { inputRef.current[index] = el!; }}
                                type="text"
                                inputMode="numeric"
                                autoComplete="one-time-code"
                                pattern="\d{1}"
                                maxLength={1}
                                value={otp[index]}
                                onChange={(e) => handleChange(e, index)}
                                onKeyDown={(e) => handleKeyDown(e, index)}
                                onPaste={handlePaste}
                                onFocus={(e) => e.target.select()}
                                className="w-12 h-14 sm:w-14 sm:h-16 text-center text-2xl font-black text-red-700 bg-white border border-slate-200 rounded-xl outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all shadow-[inset_0_2px_4px_rgba(0,0,0,0.02)] selection:bg-red-200"
                            />
                        ))}
                    </div>

                    {error && (
                        <div className="w-full bg-rose-50 border border-rose-200 text-rose-700 px-5 py-3 rounded-xl mb-6 text-xs font-bold text-center shadow-sm">
                            {error}
                        </div>
                    )}

                    <button
                        onClick={() => handleVerify()}
                        disabled={isLoading || otp.join("").length !== 6}
                        className="w-full h-14 rounded-xl text-white font-black tracking-[0.15em] text-xs transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center bg-gradient-to-r from-red-800 to-red-700 hover:from-red-900 hover:to-red-800 shadow-lg shadow-red-900/20 active:scale-[0.98]"
                    >
                        {isLoading ? (
                            <div className="flex items-center gap-3">
                                <Loader2 className="animate-spin w-5 h-5 text-white" />
                                <span>VERIFYING...</span>
                            </div>
                        ) : 'VERIFY ACCOUNT'}
                    </button>

                    <div className="mt-8 text-center pt-6 border-t border-slate-200/60 w-full flex flex-col items-center gap-2">
                        <p className="text-xs font-medium text-slate-500">Didn't receive the code?</p>
                        <button 
                            onClick={handleResend}
                            disabled={isResending}
                            className="text-sm font-bold text-red-700 hover:text-red-800 transition-colors disabled:opacity-50 flex items-center gap-2"
                        >
                            {isResending ? <><Loader2 className="w-3 h-3 animate-spin"/> Sending...</> : 'Resend Code'}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}