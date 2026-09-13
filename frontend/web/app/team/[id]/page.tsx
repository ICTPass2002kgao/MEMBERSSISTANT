"use client";

import React, { use } from 'react';
import Link from 'next/link';
import { notFound, useRouter } from 'next/navigation';
import { 
    ArrowLeft, 
    Mail, 
    Phone, 
    CheckCircle2,
    Briefcase,
    Building2,
    ShieldCheck,
    UserCircle
} from 'lucide-react';
import Navbar from '../../components/Navbar';
import Footer from '../../components/Footer';

const teamMembers = [
    {
        id: 'lwazi',
        name: 'Lwazi Nene',
        role: 'CEO',
        email: 'info@langalesedi.com',
        description: 'Responsible for the overarching strategic vision, executive leadership, and driving the long-term success and growth of the organization.',
        tasks: ['Executive Leadership', 'Strategic Planning', 'Company Vision & Direction'],
        image: '/596d6753-3852-4478-a514-aad2e404029f.JPG'
    },
    {
        id: 'moeketsi',
        name: 'Moeketsi Mofokeng',
        role: 'COO',
        email: 'info@langalesedi.com',
        description: 'Manages daily business operations, ensuring organizational efficiency and seamless implementation of company strategies.',
        tasks: ['Operational Management', 'Process Optimization', 'Resource Allocation'],
        image: '/596d6753-3852-4478-a514-aad2e404029f.JPG'
    },
    {
        id: 'neo',
        name: 'Neo Molotsi',
        role: 'Operations Manager',
        email: 'Neo.Molotsi@langalesedi.com',
        phone: '063 349 8461',
        description: 'Handles logistics and daily operational concerns to ensure a safe, efficient, and smooth living experience for all residents.',
        tasks: ["Transport operations (bus schedule, driver's behaviour)", 'Disciplinary hearing appeals'],
        image: '/b55331a2-b41d-40b8-9fc7-78db3f0dc0f8.JPG'
    },
    {
        id: 'zama',
        name: 'Zama Mnxeba',
        role: 'Administrations Officer',
        email: 'admin@studentheights.co.za',
        phone: '065 679 4509',
        description: 'Manages core administrative processes, ensuring proper documentation, clear communication, and smooth onboarding for students.',
        tasks: ['Enquiries', 'Lease Submission'],
        image: '/0005d872-50cf-4492-bedb-17e0c45cfd72.JPG'
    }, 
    {
        id: 'phemelo',
        name: 'Phemelo Machidza',
        role: 'Marketing & Stakeholder Relations',
        email: 'phemelo.matshidza@studentheights.co.za',
        phone: '081 009 6956',
        description: 'Drives brand awareness, coordinates engaging student events, and builds lasting relationships with sponsors and stakeholders.',
        tasks: ['Events', 'Public Relations (Merchandise & Branding)', 'Sponsorship'],
        image: '/b445b18e-628b-4ef0-b908-3e3565ebf022.JPG'
    },
    {
        id: 'nkosana',
        name: 'Nkosana Macatywe',
        role: 'Finance Administrator',
        email: 'Finance@studentheights.co.za',
        phone: '065 679 4509',
        description: 'Manages all financial queries, invoicing, account statements, and bursary-related transactions for our students.',
        tasks: ['Student Account-statement', 'Invoicing', 'Bursary Enquiries'],
        image: '/e77ebdda-fc0b-46b5-8e1d-0fa40c937768.JPG'
    },
    {
        id: 'sam',
        name: 'Sam Motloha',
        role: 'Maintenance Officer',
        email: 'sam.matloha@studentheights.co.za',
        phone: '081 765 7467',
        description: 'Keeps all residences in top condition by promptly addressing plumbing, electrical, network, and general facility issues.',
        tasks: ['Maintenance complaints (plumbing, electricity, wi-fi, cleaning)'],
        image: '/0bad6b0a-4103-4f23-8a37-813b20b3c7e8.JPG'
    }
];

export default function TeamMemberPage({ params }: { params: Promise<{ id: string }> }) {
    const { id } = use(params);
    const router = useRouter();
    const member = teamMembers.find(m => m.id === id);

    if (!member) {
        notFound();
    }

    const getInitials = (name: string) => {
        return name.split(' ').map(n => n[0]).join('').substring(0, 2);
    };

    return (
        <div className="w-full pb-24 bg-blue-50">
            
            <nav className="fixed w-full z-[60] top-0 p-6 flex justify-between items-center mix-blend-difference text-white pointer-events-none">
                <button 
                    onClick={() => router.push('/')} 
                    className="w-12 h-12 rounded-full bg-slate-900/50 backdrop-blur-md border border-white/20 flex items-center justify-center hover:bg-slate-900/80 transition-colors pointer-events-auto shadow-lg"
                >
                    <ArrowLeft className="w-5 h-5" />
                </button>
            </nav>
 
            {/* FIXED HERO SECTION */}
            <section className="relative w-full min-h-[80vh] md:min-h-[90vh] z-10 bg-slate-900 flex flex-col items-center justify-center pt-24 pb-16 overflow-hidden">
                {/* Blurred background */}
                {member.image && (
                    <div 
                        className="absolute inset-0 bg-cover bg-center blur-3xl opacity-30 scale-110" 
                        style={{ backgroundImage: `url(${member.image})` }}
                    ></div>
                )}
                
                {/* Main Poster Image */}
                <div className="relative z-10 w-full max-w-5xl px-4 flex justify-center">
                    {member.image ? (
                        <img 
                            src={member.image} 
                            alt={`${member.name} - Poster`}
                            className="max-h-[60vh] md:max-h-[75vh] w-auto object-contain drop-shadow-2xl rounded-2xl border border-white/10"
                        />
                    ) : (
                        <UserCircle className="w-32 h-32 text-slate-700" />
                    )}
                </div>

                {/* Gradient overlay to blend into the page */}
                <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-blue-50 to-transparent z-20 pointer-events-none"></div>

                {/* Overlapping Profile Picture Logo Box */}
                <div className="absolute bottom-0 left-0 w-full px-6 translate-y-1/2 z-40">
                    <div className="max-w-6xl mx-auto flex items-end justify-between">
                        <div className="w-32 h-32 md:w-48 md:h-48 rounded-[2.5rem] bg-white p-2 md:p-3 shadow-[0_8px_30px_rgb(0,0,0,0.12)] border border-slate-100 flex items-center justify-center overflow-hidden">
                            {member.image ? (
                                <img src={member.image} alt={member.name} className="w-full h-full object-cover object-top rounded-[1.8rem]" />
                            ) : (
                                <div className="w-full h-full bg-slate-100 rounded-[1.8rem] flex items-center justify-center text-slate-400 font-black text-4xl uppercase">
                                    {getInitials(member.name)}
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            </section>

            <section className="relative z-10 pt-28 md:pt-40 px-6">
                <div className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-12">
                    
                    {/* Main Content Area */}
                    <div className="lg:col-span-2 space-y-12">
                        <div className="space-y-5">
                            <div className="flex items-center gap-3">
                                <span className="px-4 py-1.5 bg-red-100 text-red-800 text-[10px] font-black uppercase tracking-widest rounded-lg border border-red-200">
                                    {member.role}
                                </span>
                            </div>
                            <h1 className="text-4xl md:text-6xl font-black text-slate-900 leading-tight tracking-tight uppercase">
                                {member.name.split(' ')[0]} <span className="text-slate-500">{member.name.split(' ').slice(1).join(' ')}</span>
                            </h1>
                            <div className="flex items-start gap-3 text-slate-500 font-medium bg-white/60 p-4 rounded-2xl border border-slate-200 backdrop-blur-md shadow-sm w-fit">
                                <Briefcase className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
                                <p className="text-lg leading-relaxed">Student Heights Management Team</p>
                            </div>
                        </div>

                        <div className="space-y-4">
                            <h3 className="text-2xl font-black text-slate-900">About {member.name.split(' ')[0]}</h3>
                            <p className="text-slate-600 text-lg leading-relaxed font-medium">
                                {member.description}
                            </p>
                        </div>

                        {/* Responsibilities Grid */}
                        <div className="bg-white/80 backdrop-blur-xl p-10 rounded-[2.5rem] border border-slate-100 shadow-[0_8px_30px_rgb(0,0,0,0.04)]">
                            <h3 className="text-2xl font-black text-slate-900 mb-8">Core Responsibilities</h3>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-8">
                                {member.tasks.map((task, idx) => (
                                    <div key={idx} className="flex items-start gap-5">
                                        <div className="w-14 h-14 shrink-0 rounded-2xl bg-red-50 border border-red-100 text-red-700 flex items-center justify-center mt-1">
                                            <CheckCircle2 className="w-6 h-6" />
                                        </div>
                                        <div>
                                            <p className="text-base font-black text-slate-900 leading-tight">{task}</p>
                                            <p className="text-[10px] uppercase font-bold text-slate-400 mt-1">Key Focus Area</p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>

                    {/* Sticky Sidebar */}
                    <div className="lg:col-span-1">
                        <div className="sticky top-28 bg-white/90 backdrop-blur-2xl p-8 rounded-[2.5rem] border border-slate-100 shadow-[0_20px_50px_rgb(0,0,0,0.06)] flex flex-col gap-6 z-20">
                            
                            <div className="text-center pb-6 border-b border-slate-100">
                                <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Contact Information</p>
                                <div className="inline-flex items-center gap-2 px-4 py-2 bg-emerald-50 text-emerald-700 rounded-xl border border-emerald-200">
                                    <span className="relative flex h-2 w-2">
                                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                                      <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                                    </span>
                                    <span className="text-[11px] font-black uppercase tracking-wider">Available for Support</span>
                                </div>
                            </div>

                            <ul className="space-y-6">
                                {member.phone && (
                                    <li className="flex items-center gap-4">
                                        <div className="w-12 h-12 rounded-full bg-red-50 text-red-600 flex items-center justify-center shrink-0">
                                            <Phone className="w-5 h-5" />
                                        </div>
                                        <div>
                                            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Direct Line</p>
                                            <a href={`tel:${member.phone.replace(/\s+/g, '')}`} className="text-sm font-bold text-slate-800 hover:text-red-600 transition-colors">
                                                {member.phone}
                                            </a>
                                        </div>
                                    </li>
                                )}
                                <li className="flex items-center gap-4">
                                    <div className="w-12 h-12 rounded-full bg-red-50 text-red-600 flex items-center justify-center shrink-0">
                                        <Mail className="w-5 h-5" />
                                    </div>
                                    <div className="overflow-hidden">
                                        <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Email Address</p>
                                        <a href={`mailto:${member.email}`} className="text-sm font-bold text-slate-800 hover:text-red-600 transition-colors truncate block">
                                            {member.email}
                                        </a>
                                    </div>
                                </li>
                            </ul>

                            <a 
                                href={`mailto:${member.email}`}
                                className="w-full mt-4 py-4 rounded-xl bg-gradient-to-r from-red-800 to-red-700 text-white text-sm font-black uppercase tracking-wider hover:from-red-900 hover:to-red-800 transition-all shadow-lg shadow-red-900/20 hover:-translate-y-0.5 flex items-center justify-center gap-2"
                            >
                                GET IN TOUCH
                            </a>
                            
                            <p className="text-center text-[9px] font-black text-slate-400 uppercase tracking-widest mt-2">
                                Powered by Student Heights
                            </p>
                        </div>
                    </div>
                </div>
            </section>

            <Footer />
        </div>
    );
}