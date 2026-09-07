"use client";

import React from 'react';
import Link from 'next/link';
import { 
    ShieldCheck, 
    Home as HomeIcon,
    ArrowRight,
    Sparkles,
    CheckCircle2
} from 'lucide-react';
import Footer from '../components/Footer';
import Navbar from '../components/Navbar';

export default function AboutPage() {
    const teamMembers = [
        { name: "Lwazi Nene", role: "Founder & CEO", delay: "delay-[100ms]" },
        { name: "Moeketsi Mofokeng", role: "Founder & COO", delay: "delay-[200ms]" },
        { name: "Neo Molotsi", role: "Operations Manager", delay: "delay-[300ms]" },
        { name: "Sam Matloha", role: "Maintenance Officer", delay: "delay-[400ms]" },
        { name: "Neliswa Miya", role: "Senior Administrator", delay: "delay-[500ms]" },
        { name: "Phemelo Machidza", role: "Marketing & Stakeholder", delay: "delay-[600ms]" },
        { name: "Palesa Maleka", role: "Finance Administrator", delay: "delay-[700ms]" },
        { name: "Mary Sithole", role: "Legal & Compliance", delay: "delay-[800ms]" },
    ];

    return (
        <div className="w-full bg-blue-50 text-slate-900">
            <Navbar/>
            {/* Cinematic Hero */}
            <section className="relative pt-48 pb-20 px-6">
                <div className="max-w-5xl mx-auto text-center space-y-6 animate-in slide-in-from-bottom-12 fade-in duration-1000 fill-mode-both">
                    <div className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-white/60 backdrop-blur-md border border-slate-200/60 text-slate-800 text-xs font-bold uppercase tracking-widest shadow-sm cursor-default">
                        <Sparkles className="w-4 h-4 text-red-600" />
                        Our Story
                    </div>
                    
                    <h1 className="text-5xl md:text-7xl font-black tracking-tighter text-slate-900 leading-[1.1]">
                        Redefining the <br/><span className="text-transparent bg-clip-text bg-gradient-to-br from-red-800 via-red-600 to-rose-500">student experience.</span>
                    </h1>
                    
                    <p className="text-lg md:text-xl text-slate-500 max-w-3xl mx-auto leading-relaxed font-medium pt-4">
                        Student Heights is a premium platform dedicated to assisting students in finding the highest quality accommodation. We bridge the gap between residents and landlords with end-to-end management services.
                    </p>
                </div>
            </section>

            {/* Value Proposition Bento Box */}
            <section className="py-20 px-6">
                <div className="max-w-7xl mx-auto grid lg:grid-cols-3 gap-6">
                    <div className="lg:col-span-2 group p-10 rounded-[2.5rem] bg-white border border-slate-100 shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_20px_40px_rgb(185,28,28,0.06)] hover:border-red-100 transition-all duration-500 flex flex-col justify-center relative overflow-hidden">
                        <div className="absolute top-0 right-0 w-64 h-64 bg-red-50 rounded-full blur-[80px] -mr-20 -mt-20 transition-all group-hover:bg-red-100"></div>
                        <div className="w-16 h-16 rounded-2xl bg-red-50 text-red-700 flex items-center justify-center mb-6 relative z-10">
                            <HomeIcon className="w-8 h-8" />
                        </div>
                        <h3 className="text-3xl font-black text-slate-900 mb-4 relative z-10">Premium Matchmaking</h3>
                        <p className="text-slate-500 text-lg font-medium leading-relaxed max-w-xl relative z-10">
                            We don't just find you a room. We match you with a residence that perfectly aligns with your academic needs, safety requirements, and lifestyle preferences. Quality is our baseline.
                        </p>
                    </div>

                    <div className="group p-10 rounded-[2.5rem] bg-gradient-to-br from-slate-900 to-slate-800 text-white shadow-[0_8px_30px_rgb(0,0,0,0.08)] hover:shadow-[0_20px_40px_rgb(185,28,28,0.15)] transition-all duration-500 relative overflow-hidden">
                        <div className="absolute inset-0 bg-[url('https://images.unsplash.com/photo-1523240795612-9a054b0db644?q=80&w=2070&auto=format&fit=crop')] opacity-10 bg-cover bg-center mix-blend-overlay group-hover:scale-110 transition-transform duration-1000"></div>
                        <div className="w-16 h-16 rounded-2xl bg-white/10 backdrop-blur-md flex items-center justify-center mb-6 relative z-10 border border-white/20">
                            <ShieldCheck className="w-8 h-8 text-white" />
                        </div>
                        <h3 className="text-2xl font-black mb-4 relative z-10">Zero Friction</h3>
                        <ul className="space-y-3 relative z-10">
                            <li className="flex items-center gap-3 text-sm font-medium text-slate-300"><CheckCircle2 className="w-5 h-5 text-emerald-400" /> No Downpayments (NSFAS)</li>
                            <li className="flex items-center gap-3 text-sm font-medium text-slate-300"><CheckCircle2 className="w-5 h-5 text-emerald-400" /> Pre-verified Landlords</li>
                            <li className="flex items-center gap-3 text-sm font-medium text-slate-300"><CheckCircle2 className="w-5 h-5 text-emerald-400" /> Secure Application</li>
                        </ul>
                    </div>
                </div>
            </section>

            {/* Management Team */}
            <section className="py-24 px-6 bg-white border-y border-slate-100">
                <div className="max-w-7xl mx-auto">
                    <div className="text-center mb-20 space-y-4">
                        <div className="flex items-center justify-center gap-2 mb-4">
                            <div className="h-[2px] w-8 bg-red-600 rounded-full"></div>
                            <p className="text-red-700 text-xs font-black uppercase tracking-widest">Leadership</p>
                            <div className="h-[2px] w-8 bg-red-600 rounded-full"></div>
                        </div>
                        <h2 className="text-4xl md:text-5xl font-black text-slate-900">Meet the Team</h2>
                        <p className="text-slate-500 font-medium max-w-2xl mx-auto text-lg">The dedicated professionals ensuring your stay is secure, comfortable, and managed flawlessly.</p>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
                        {teamMembers.map((member, idx) => (
                            <div key={idx} className={`p-8 rounded-[2.5rem] bg-slate-50 border border-slate-100 shadow-sm hover:shadow-[0_20px_40px_rgba(185,28,28,0.08)] flex flex-col items-center text-center group transition-all duration-500 hover:-translate-y-2 animate-in fade-in slide-in-from-bottom-8 fill-mode-both ${member.delay}`}>
                                <div className="w-24 h-24 rounded-3xl bg-white mb-6 border border-slate-200 flex items-center justify-center overflow-hidden shadow-sm group-hover:scale-110 group-hover:border-red-200 transition-all duration-500">
                                    <div className="w-full h-full bg-gradient-to-br from-red-50 to-white flex items-center justify-center text-3xl font-black text-red-700">
                                        {member.name.charAt(0)}
                                    </div>
                                </div>
                                <h4 className="text-slate-900 text-lg font-black mb-2">{member.name}</h4>
                                <span className="px-4 py-1.5 rounded-lg bg-white border border-slate-200 text-slate-500 text-[10px] uppercase font-bold tracking-widest shadow-sm">
                                    {member.role}
                                </span>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* IT Partner Showcase */}
            <section className="py-24 px-6 bg-slate-950 text-white overflow-hidden rounded-b-[0px] shadow-2xl relative z-20">
                <div className="absolute inset-0 bg-[url('https://images.unsplash.com/photo-1550751827-4bd374c3f58b?q=80&w=2070&auto=format&fit=crop')] opacity-10 bg-cover bg-center"></div>
                <div className="max-w-4xl mx-auto text-center relative z-10">
                    <p className="text-red-500 text-xs font-black uppercase tracking-widest mb-4">Technology Partner</p>
                    <h2 className="text-3xl md:text-5xl font-black mb-8">Powered by Enterprise Tech</h2>
                    
                    <div className="inline-flex flex-col items-center p-10 md:p-14 rounded-[3rem] bg-white/5 backdrop-blur-xl border border-white/10 shadow-[0_20px_50px_rgba(0,0,0,0.5)] transition-all hover:scale-105 duration-500 hover:border-red-500/50">
                        <div className="w-20 h-20 rounded-2xl bg-gradient-to-br from-red-600 to-rose-600 flex items-center justify-center mb-6 shadow-lg shadow-red-600/30">
                            <ShieldCheck className="w-10 h-10 text-white" />
                        </div>
                        <h4 className="text-3xl font-black mb-2">MKTECHCLOUD <span className="text-red-500">(Pty) Ltd</span></h4>
                        <p className="text-slate-400 text-sm font-bold uppercase tracking-[0.2em]">Software Development Architecture</p>
                    </div>
                </div>
            </section>
            <Footer/>
        </div>
    );
}