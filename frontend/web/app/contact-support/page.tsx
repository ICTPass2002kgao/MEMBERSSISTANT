"use client";

import React, { useState, FormEvent } from 'react';
import Link from 'next/link';
import { Mail, Loader2, ArrowLeft, HeadphonesIcon, CheckCircle2 } from 'lucide-react';

export default function ContactSupportPage() {
    const [formData, setFormData] = useState({
        name: '',
        email: '',
        role: '',
        category: '',
        subject: '',
        message: ''
    });

    const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
    const [errorMessage, setErrorMessage] = useState<string | null>(null);

    const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        setStatus('loading');
        setErrorMessage(null);

        const apiUrl = 'https://api-w6yanm6o4q-uc.a.run.app/sendCustomEmail';
        const currentYear = new Date().getFullYear();

        // 1. HTML Email Template to Memberssistant Support
        const supportHtmlBody = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f8fafc; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
            <h2 style="color: #0f172a; border-bottom: 2px solid #3b82f6; padding-bottom: 10px;">New Support Ticket</h2>
            <p><strong>Name:</strong> ${formData.name}</p>
            <p><strong>Email:</strong> ${formData.email}</p>
            <p><strong>Account Type:</strong> ${formData.role}</p>
            <p><strong>Category:</strong> ${formData.category}</p>
            <p><strong>Subject:</strong> ${formData.subject}</p>
            <div style="background-color: #ffffff; padding: 15px; border: 1px solid #cbd5e1; border-radius: 6px; margin-top: 20px;">
                <h3 style="color: #475569; margin-top: 0;">Message:</h3>
                <p style="white-space: pre-wrap; color: #1e293b;">${formData.message}</p>
            </div>
        </div>
        `;

        // 2. HTML Email Template back to the User
        const userHtmlBody = `
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f8fafc; padding: 10px; border-radius: 12px; border: 1px solid #e2e8f0;">
            <div style="background-color: #0f172a; padding: 20px; border-radius: 10px 10px 0 0; text-align: center;">
                <img src="https://firebasestorage.googleapis.com/v0/b/membersisstant.firebasestorage.app/o/FCMImages%2Fmemberssistant_icon.png?alt=media&token=01c986f2-5504-497b-bd75-e271edb4abf7" alt="Logo" style="max-height: 55px; margin-bottom: 8px; border-radius: 4px;">
                <h1 style="color: #ffffff; margin: 0; font-size: 22px; font-weight: 800; letter-spacing: 1px;">Memberssistant</h1>
                <p style="color: #94a3b8; margin: 2px 0 0 0; font-size: 13px;">Support Team</p>
            </div>
            <div style="background-color: #ffffff; padding: 20px; border-radius: 0 0 10px 10px; color: #334155; line-height: 1.5; font-size: 15px; border: 1px solid #e2e8f0; border-top: none;">
                <h2 style="color: #0f172a; margin-top: 0;">Request Received</h2>
                <p>Hi ${formData.name},</p>
                <p>Thank you for reaching out to us. We have successfully received your support request regarding <strong>${formData.subject}</strong>.</p>
                <p>Our support team will review your ticket and get back to you at this email address as soon as possible.</p>
                <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
                <h3 style="color: #64748b; font-size: 14px; margin-bottom: 5px;">Your Message Copy:</h3>
                <p style="background-color: #f1f5f9; padding: 10px; border-radius: 6px; font-size: 14px; color: #475569; white-space: pre-wrap;">${formData.message}</p>
            </div>
            <div style="text-align: center; margin-top: 15px; color: #64748b; font-size: 12px;">
                <p style="margin: 3px 0;">&copy; ${currentYear} MK TECHCLOUD (Pty) Ltd. All rights reserved.</p>
                <p style="margin: 3px 0;">Please do not reply directly to this automated confirmation email.</p>
            </div>
        </div>
        `;

        try {
            // Send to Support Team
            const supportResponse = await fetch(apiUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    to: 'memberssistant@gmail.com',
                    subject: `[Support Ticket] ${formData.category}: ${formData.subject}`,
                    body: supportHtmlBody,
                    attachmentUrl: ""
                })
            });

            if (!supportResponse.ok) throw new Error('Failed to dispatch to support team.');

            // Send Confirmation to User
            const userResponse = await fetch(apiUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    to: formData.email,
                    subject: 'Support Request Received - Memberssistant',
                    body: userHtmlBody,
                    attachmentUrl: ""
                })
            });

            if (!userResponse.ok) throw new Error('Failed to send confirmation email.');

            setStatus('success');
            setFormData({ name: '', email: '', role: '', category: '', subject: '', message: '' });

        } catch (error: any) {
            setStatus('error');
            setErrorMessage(error.message || 'An error occurred. Please try again.');
        }
    };

    return (
        <div className="min-h-screen bg-[#020617] relative overflow-y-auto flex items-center justify-center p-4 sm:p-6 text-slate-100 font-sans">
            
            {/* Ambient Background Effects */}
            <div className="absolute top-[-10%] left-[-10%] w-[500px] h-[500px] rounded-full bg-blue-600/10 blur-[120px] pointer-events-none fixed"></div>
            <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full bg-blue-900/20 blur-[120px] pointer-events-none fixed"></div>

            <div className="z-10 w-full max-w-3xl my-8">
                <Link href="/" className="inline-flex items-center gap-2 text-slate-400 hover:text-white transition-colors mb-6 text-sm font-medium">
                    <ArrowLeft className="w-4 h-4" />
                    Back to Login
                </Link>

                <div className="rounded-[32px] bg-slate-900/40 backdrop-blur-xl border border-slate-800/60 shadow-2xl shadow-black/50 overflow-hidden relative">
                    
                    {/* Glowing Top Border */}
                    <div className="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-blue-500/50 to-transparent"></div>

                    <div className="p-8 sm:p-12">
                        <div className="flex flex-col sm:flex-row items-start sm:items-center gap-6 mb-10 border-b border-slate-800/60 pb-8">
                            <div className="p-4 rounded-2xl bg-blue-500/10 border border-blue-500/20 shadow-lg shadow-blue-500/10 shrink-0">
                                <HeadphonesIcon className="w-10 h-10 text-blue-400" strokeWidth={1.5} />
                            </div>
                            <div>
                                <h1 className="text-3xl font-bold tracking-tight text-white mb-2">Contact Support</h1>
                                <p className="text-slate-400 text-sm leading-relaxed">
                                    Experiencing technical difficulties, account access issues, or billing inquiries? Fill out the form below and our dedicated support team will assist you.
                                </p>
                            </div>
                        </div>

                        {status === 'success' ? (
                            <div className="py-16 flex flex-col items-center justify-center text-center animate-in fade-in zoom-in duration-500">
                                <div className="w-20 h-20 bg-emerald-500/10 border border-emerald-500/20 rounded-full flex items-center justify-center mb-6 shadow-lg shadow-emerald-500/10">
                                    <CheckCircle2 className="w-10 h-10 text-emerald-400" />
                                </div>
                                <h3 className="text-2xl font-bold text-white mb-3">Ticket Submitted Successfully</h3>
                                <p className="text-slate-400 max-w-md mx-auto mb-8">
                                    We have received your request and sent a confirmation to your email. Our team will review your inquiry and respond shortly.
                                </p>
                                <button 
                                    onClick={() => setStatus('idle')}
                                    className="px-6 py-3 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-xl text-white text-sm font-bold tracking-widest transition-colors"
                                >
                                    SUBMIT ANOTHER TICKET
                                </button>
                            </div>
                        ) : (
                            <form onSubmit={handleSubmit} className="space-y-6">
                                
                                {status === 'error' && (
                                    <div className="bg-rose-500/10 border border-rose-500/20 text-rose-400 px-5 py-4 rounded-xl text-sm font-medium flex items-center gap-3">
                                        <svg className="w-5 h-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                                        {errorMessage}
                                    </div>
                                )}

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                                    <div className="space-y-1.5">
                                        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Full Name</label>
                                        <input
                                            type="text"
                                            required
                                            name="name"
                                            value={formData.name}
                                            onChange={handleChange}
                                            className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                            placeholder="John Doe"
                                        />
                                    </div>
                                    <div className="space-y-1.5">
                                        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Email Address</label>
                                        <input
                                            type="email"
                                            required
                                            name="email"
                                            value={formData.email}
                                            onChange={handleChange}
                                            className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                            placeholder="john@example.com"
                                        />
                                    </div>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                                    <div className="space-y-1.5">
                                        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Account Type</label>
                                        <div className="relative">
                                            <select
                                                required
                                                name="role"
                                                value={formData.role}
                                                onChange={handleChange}
                                                className="w-full px-5 py-4 bg-slate-900/50 text-white border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm appearance-none cursor-pointer"
                                            >
                                                <option value="" disabled className="text-slate-500">Select Account Type</option>
                                                <option value="Student">Student / Resident</option>
                                                <option value="Landlord">Landlord / Property Manager</option>
                                                <option value="Security">Security / Attendant Staff</option>
                                                <option value="Applicant">New Applicant / Other</option>
                                            </select>
                                            <div className="absolute inset-y-0 right-4 flex items-center pointer-events-none text-slate-500">
                                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7"></path></svg>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="space-y-1.5">
                                        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Issue Category</label>
                                        <div className="relative">
                                            <select
                                                required
                                                name="category"
                                                value={formData.category}
                                                onChange={handleChange}
                                                className="w-full px-5 py-4 bg-slate-900/50 text-white border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm appearance-none cursor-pointer"
                                            >
                                                <option value="" disabled className="text-slate-500">Select Category</option>
                                                <option value="Login Issue">Login / Account Access</option>
                                                <option value="App Bug">App Bug / Technical Issue</option>
                                                <option value="Verification">Identity / Biometric Verification</option>
                                                <option value="Billing">Billing / Payment Issue</option>
                                                <option value="General Inquiry">General Inquiry</option>
                                            </select>
                                            <div className="absolute inset-y-0 right-4 flex items-center pointer-events-none text-slate-500">
                                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7"></path></svg>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Subject</label>
                                    <input
                                        type="text"
                                        required
                                        name="subject"
                                        value={formData.subject}
                                        onChange={handleChange}
                                        className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm"
                                        placeholder="Brief summary of the issue"
                                    />
                                </div>

                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pl-1">Detailed Message</label>
                                    <textarea
                                        required
                                        name="message"
                                        rows={5}
                                        value={formData.message}
                                        onChange={handleChange}
                                        className="w-full px-5 py-4 bg-slate-900/50 text-white placeholder-slate-600 border border-slate-800 rounded-xl outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all text-sm resize-none"
                                        placeholder="Please provide as much detail as possible to help us assist you faster..."
                                    ></textarea>
                                </div>

                                <div className="pt-4 border-t border-slate-800/60 mt-8">
                                    <button
                                        type="submit"
                                        disabled={status === 'loading'}
                                        className="w-full h-14 rounded-xl text-white font-bold tracking-[0.15em] text-xs transition-all disabled:opacity-70 flex items-center justify-center bg-blue-600 hover:bg-blue-500 shadow-lg shadow-blue-600/20 active:scale-[0.98]"
                                    >
                                        {status === 'loading' ? (
                                            <div className="flex items-center gap-3">
                                                <Loader2 className="animate-spin w-4 h-4 text-white" />
                                                <span>SUBMITTING TICKET...</span>
                                            </div>
                                        ) : (
                                            <div className="flex items-center gap-3">
                                                <Mail className="w-4 h-4" />
                                                <span>SEND SUPPORT REQUEST</span>
                                            </div>
                                        )}
                                    </button>
                                </div>
                            </form>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}