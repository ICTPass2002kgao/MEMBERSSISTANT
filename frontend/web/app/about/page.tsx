"use client";

import React from 'react';
import Link from 'next/link';
import { 
    ShieldCheck, 
    Home as HomeIcon,
    ArrowRight,
    Sparkles,
    CheckCircle2,
    Briefcase,
    UserCircle
} from 'lucide-react';
import Footer from '../components/Footer';
import Navbar from '../components/Navbar';

export default function AboutPage() {
    // FIX: Full profiles integrated directly into the About page
    const teamMembers = [
        {
            id: 'lwazi',
            name: 'Lwazi Nene',
            role: 'CEO',
            email: 'info@langalesedi.com',
            description: 'Responsible for the overarching strategic vision, executive leadership, and driving the long-term success and growth of the organization.',
            tasks: ['Executive Leadership', 'Strategic Planning', 'Company Vision & Direction'],
            image: '/596d6753-3852-4478-a514-aad2e404029f.JPG',
            delay: "delay-[100ms]"
        },
        {
            id: 'moeketsi',
            name: 'Moeketsi Mofokeng',
            role: 'COO',
            email: 'info@langalesedi.com',
            description: 'Manages daily business operations, ensuring organizational efficiency and seamless implementation of company strategies.',
            tasks: ['Operational Management', 'Process Optimization', 'Resource Allocation'],
            image: '/596d6753-3852-4478-a514-aad2e404029f.JPG',
            delay: "delay-[200ms]"
        },
        {
            id: 'neo',
            name: 'Neo Molotsi',
            role: 'Operations Manager',
            email: 'Neo.Molotsi@langalesedi.com',
            phone: '063 349 8461',
            description: 'Handles logistics and daily operational concerns to ensure a safe, efficient, and smooth living experience for all residents.',
            tasks: ["Transport operations (bus schedule, driver's behaviour)", 'Disciplinary hearing appeals'],
            image: '/b55331a2-b41d-40b8-9fc7-78db3f0dc0f8.JPG',
            delay: "delay-[300ms]"
        },
        {
            id: 'zama',
            name: 'Zama Mnxeba',
            role: 'Senior Administrations Officer',
            email: 'admin@studentheights.co.za',
            phone: '065 679 4509',
            description: 'Manages core administrative processes, ensuring proper documentation, clear communication, and smooth onboarding for students.',
            tasks: ['Enquiries', 'Lease Submission'],
            image: '/0005d872-50cf-4492-bedb-17e0c45cfd72.JPG',
            delay: "delay-[400ms]"
        }, 
        {
            id: 'phemelo',
            name: 'Phemelo Machidza',
            role: 'Marketing & Stakeholder Relations',
            email: 'phemelo.matshidza@studentheights.co.za',
            phone: '081 009 6956',
            description: 'Drives brand awareness, coordinates engaging student events, and builds lasting relationships with sponsors and stakeholders.',
            tasks: ['Events', 'Public Relations (Merchandise & Branding)', 'Sponsorship'],
            image: '/b445b18e-628b-4ef0-b908-3e3565ebf022.JPG',
            delay: "delay-[600ms]"
        },
        {
            id: 'nkosana',
            name: 'Nkosana Macatywe',
            role: 'Finance Administrator',
            email: 'Finance@studentheights.co.za',
            phone: '065 679 4509',
            description: 'Manages all financial queries, invoicing, account statements, and bursary-related transactions for our students.',
            tasks: ['Student Account-statement', 'Invoicing', 'Bursary Enquiries'],
            image: '/e77ebdda-fc0b-46b5-8e1d-0fa40c937768.JPG',
            delay: "delay-[700ms]"
        },
        {
            id: 'sam',
            name: 'Sam Motloha',
            role: 'Maintenance Officer',
            email: 'sam.matloha@studentheights.co.za',
            phone: '081 765 7467',
            description: 'Keeps all residences in top condition by promptly addressing plumbing, electrical, network, and general facility issues.',
            tasks: ['Maintenance complaints (plumbing, electricity, wi-fi, cleaning)'],
            image: '/0bad6b0a-4103-4f23-8a37-813b20b3c7e8.JPG',
            delay: "delay-[800ms]"
        }
    ];

    const getInitials = (name: string) => {
        return name.split(' ').map(n => n[0]).join('').substring(0, 2);
    };

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

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
                        {teamMembers.map((member, idx) => (
                            <Link href={`/team/${member.id}`} key={idx} className={`block h-full ${member.delay}`}>
                                <div className="h-full p-6 rounded-[2.5rem] bg-slate-50 border border-slate-100 shadow-sm hover:shadow-[0_20px_40px_rgba(185,28,28,0.08)] flex flex-col group transition-all duration-500 hover:-translate-y-2 animate-in fade-in slide-in-from-bottom-8 fill-mode-both cursor-pointer overflow-hidden">
                                    
                                    {/* Profile Image */}
                                    <div className="w-full h-56 rounded-[2rem] bg-white mb-6 border border-slate-200 flex items-center justify-center overflow-hidden shadow-sm group-hover:border-red-200 transition-all duration-500 relative">
                                        {member.image ? (
                                            <img 
                                                src={member.image} 
                                                alt={member.name} 
                                                className="w-full h-full object-cover object-top group-hover:scale-110 transition-transform duration-700" 
                                            />
                                        ) : (
                                            <div className="w-full h-full bg-gradient-to-br from-red-50 to-white flex items-center justify-center text-4xl font-black text-red-700">
                                                {getInitials(member.name)}
                                            </div>
                                        )}
                                        <div className="absolute inset-0 bg-gradient-to-t from-slate-900/60 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
                                    </div>
                                    
                                    {/* Profile Details */}
                                    <div className="flex-1 flex flex-col">
                                        <h4 className="text-slate-900 text-xl font-black mb-2">{member.name}</h4>
                                        <span className="inline-block px-3 py-1 rounded-lg bg-red-50 text-red-700 text-[10px] uppercase font-black tracking-widest mb-4 border border-red-100 w-fit">
                                            {member.role}
                                        </span>
                                        
                                        <p className="text-slate-500 text-sm font-medium leading-relaxed mb-4 line-clamp-3">
                                            {member.description}
                                        </p>
                                        
                                        {/* Core Responsibilities Preview */}
                                        <div className="mt-auto pt-4 border-t border-slate-200">
                                            <div className="flex items-center gap-2 mb-3">
                                                <Briefcase className="w-3 h-3 text-slate-400" />
                                                <span className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Key Focus</span>
                                            </div>
                                            <div className="flex flex-wrap gap-1.5">
                                                {member.tasks.slice(0, 2).map((task, tIdx) => (
                                                    <span key={tIdx} className="px-2 py-1 bg-white border border-slate-200 text-slate-600 rounded-md text-[9px] font-bold tracking-tight truncate max-w-full">
                                                        {task.length > 25 ? task.substring(0, 25) + '...' : task}
                                                    </span>
                                                ))}
                                            </div>
                                        </div>

                                        {/* View Profile CTA */}
                                        <div className="flex items-center gap-1 text-[10px] font-black text-red-600 uppercase tracking-widest opacity-0 group-hover:opacity-100 transition-opacity duration-300 mt-4 pt-2">
                                            View Full Profile <ArrowRight className="w-3 h-3" />
                                        </div>
                                    </div>
                                </div>
                            </Link>
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