"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { 
    MapPin, 
    Loader2, 
    ChevronDown, 
    ShieldCheck, 
    Banknote, 
    ArrowRight,
    Home as HomeIcon,
    Star,
    Sparkles,
    Image as ImageIcon,
    Briefcase
} from 'lucide-react';
import { apiFetch } from './components/api';
import Footer from './components/Footer';
import Navbar from './components/Navbar';
import { AuroraBackground } from './components/ui/aurora-background';
import { Spotlight } from './components/ui/spotlight';
import { auth } from './firebase/config';
import { onAuthStateChanged, signInAnonymously } from 'firebase/auth';

interface Accommodation {
    id: string | number;
    name: string;
    address: string;
    gender_target: string;
    accommodation_logo_url?: string;
    images?: { id?: string | number; image_url: string; is_primary?: boolean }[];
}

interface TeamMember {
    id: string;
    name: string;
    role: string;
    email: string;
    phone?: string;
    description: string;
    tasks: string[];
    image?: string;
}

const teamMembers: TeamMember[] = [
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

export default function HomePage() {
    const [accommodations, setAccommodations] = useState<Accommodation[]>([]);
    const [isLoading, setIsLoading] = useState<boolean>(true);
    const [error, setError] = useState<string>('');

    useEffect(() => {
        let cancelled = false;
        let unsubscribe: (() => void) | undefined;
        let hasFetched = false; // 🛡️ prevents duplicate fetches

        const fetchAccommodations = async () => {
            if (hasFetched) return;
            hasFetched = true;

            try {
                const data = await apiFetch('/accommodations/', {
                    method: 'GET',
                    headers: { 'Content-Type': 'application/json' },
                });

                if (cancelled) return;

                if (data && data.results) {
                    setAccommodations(data.results);
                } else if (Array.isArray(data)) {
                    setAccommodations(data);
                } else {
                    setAccommodations([]);
                }
            } catch (err: any) {
                if (cancelled) return;
                console.error("Fetch Accommodations Error:", err);
                if (err?.name === 'AbortError') {
                    setError('Request timed out. Please check your connection and try again.');
                } else {
                    setError('Could not connect to the server. Please try again later.');
                }
            } finally {
                if (!cancelled) setIsLoading(false);
            }
        };

        // 🔐 Step 1: Wait for Firebase auth to resolve
        unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
            if (cancelled) return;

            // 🔐 Step 2: No user? Sign in anonymously ONCE, then let onAuthStateChanged re-fire
            if (!firebaseUser) {
                try {
                    await signInAnonymously(auth);
                } catch (err) {
                    console.error("Anonymous sign-in failed:", err);
                    // Fall through — try fetching anyway
                    fetchAccommodations();
                }
                return;
            }

            // 🔐 Step 3: We have a user (anonymous or real) → now safe to fetch
            fetchAccommodations();
        });

        return () => {
            cancelled = true;
            if (unsubscribe) unsubscribe();
        };
    }, []); // 👈 empty array — runs once

    const featuredAccommodations = accommodations.slice(0, 3);

    const getCardImage = (acc: Accommodation) => {
        if (acc.images && acc.images.length > 0) {
            const primary = acc.images.find(img => img.is_primary);
            return primary?.image_url || acc.images[0].image_url;
        }
        if (acc.accommodation_logo_url) {
            return acc.accommodation_logo_url;
        }
        return 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?q=80&w=1000&auto=format&fit=crop';
    };

    const getInitials = (name: string) => {
        return name.split(' ').map(n => n[0]).join('').substring(0, 2);
    };

    return (
        <div className="w-full bg-blue-50 relative overflow-hidden">

            <Navbar />

            {/* ============================================================
                CINEMATIC HERO with AURORA BACKGROUND + SPOTLIGHT
            ============================================================ */}
            <AuroraBackground className="pt-48 pb-20 px-6 min-h-[95vh] h-auto">
                <Spotlight
                    className="-top-40 left-0 md:left-60 md:-top-20"
                    fill="#b91c1c"
                />
                <Spotlight
                    className="-top-20 right-0 md:right-40 md:-top-10"
                    fill="#e11d48"
                />

                <div className="relative z-10 max-w-5xl mx-auto text-center space-y-8 animate-in slide-in-from-bottom-12 fade-in duration-1000 fill-mode-both">
                    
                    <div className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-white/40 backdrop-blur-xl border border-white/60 text-slate-800 text-xs font-bold uppercase tracking-widest shadow-sm hover:shadow-md transition-all cursor-default">
                        <Sparkles className="w-4 h-4 text-red-600" />
                        Accommodating you to greater heights
                    </div>
                    
                    <h1 className="text-6xl md:text-8xl font-black tracking-tighter text-slate-900 leading-[1.1]">
                        Elevating <span className="text-transparent bg-clip-text bg-gradient-to-br from-red-800 via-red-600 to-rose-500">Student Living.</span>
                    </h1>
                    
                    <p className="text-lg md:text-xl text-slate-600 max-w-2xl mx-auto leading-relaxed font-medium">
                        Discover premium, secure, and fully-managed student accommodations. Designed for academic success and unparalleled lifestyle convenience.
                    </p>
                    
                    <div className="pt-8 flex flex-col sm:flex-row items-center justify-center gap-5">
                        <Link href="/accommodations" className="w-full sm:w-auto px-10 py-4 rounded-2xl bg-gradient-to-r from-red-800 to-red-600 text-white text-sm font-black uppercase tracking-widest hover:from-red-900 hover:to-red-700 transition-all shadow-lg shadow-red-900/20 flex items-center justify-center gap-3 hover:-translate-y-1 hover:shadow-xl hover:shadow-red-900/30">
                            Explore Residences
                            <ArrowRight className="w-4 h-4" />
                        </Link>
                        <Link href="/about" className="w-full sm:w-auto px-10 py-4 rounded-2xl bg-white/40 backdrop-blur-xl border border-white/60 text-slate-800 text-sm font-black uppercase tracking-widest hover:bg-white/60 hover:text-red-700 hover:border-white transition-all shadow-sm flex items-center justify-center hover:-translate-y-1 hover:shadow-md">
                            Our Story
                        </Link>
                    </div>
                </div>

                <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-3 text-slate-500 animate-bounce cursor-default z-10">
                    <span className="text-[9px] uppercase tracking-[0.3em] font-bold">Discover</span>
                    <ChevronDown className="w-5 h-5 text-red-600" />
                </div>
            </AuroraBackground>

            {/* ============================================================
                BENTO-BOX STYLE ABOUT TEASER (with subtle premium glow bg)
            ============================================================ */}
            <section className="relative py-32 px-6 overflow-hidden">
                <div className="absolute top-1/3 left-1/2 -translate-x-1/2 w-[900px] h-[900px] bg-red-500/5 rounded-full blur-[140px] pointer-events-none -z-0" />
                <div className="absolute bottom-0 right-0 w-[600px] h-[600px] bg-rose-400/5 rounded-full blur-[100px] pointer-events-none -z-0" />

                <div className="relative max-w-7xl mx-auto grid lg:grid-cols-2 gap-12 lg:gap-20 items-center z-10">
                    
                    <div className="space-y-10">
                        <div>
                            <div className="flex items-center gap-2 mb-4">
                                <div className="h-[2px] w-8 bg-red-600 rounded-full"></div>
                                <p className="text-red-700 text-xs font-black uppercase tracking-widest">Why Choose Us</p>
                            </div>
                            <h2 className="text-4xl md:text-5xl font-black text-slate-900 leading-tight">
                                The new standard of <br/><span className="text-transparent bg-clip-text bg-gradient-to-r from-slate-800 to-slate-500">residence management.</span>
                            </h2>
                        </div>

                        <div className="grid gap-4">
                            <div className="group p-6 rounded-3xl bg-white/50 backdrop-blur-xl border border-white/60 shadow-sm hover:shadow-[0_8px_30px_rgb(185,28,28,0.08)] hover:bg-white/80 transition-all cursor-default">
                                <div className="flex items-start gap-5">
                                    <div className="w-14 h-14 rounded-2xl bg-white shadow-sm text-red-700 flex items-center justify-center shrink-0 group-hover:scale-110 group-hover:bg-red-600 group-hover:text-white transition-all duration-500">
                                        <HomeIcon className="w-6 h-6" />
                                    </div>
                                    <div>
                                        <h4 className="text-lg font-black text-slate-900 mb-1">Premium Accommodation</h4>
                                        <p className="text-slate-600 text-sm font-medium leading-relaxed">Curated residences that suit all your needs, safety requirements, and lifestyle perfectly.</p>
                                    </div>
                                </div>
                            </div>

                            <div className="group p-6 rounded-3xl bg-white/50 backdrop-blur-xl border border-white/60 shadow-sm hover:shadow-[0_8px_30px_rgb(185,28,28,0.08)] hover:bg-white/80 transition-all cursor-default">
                                <div className="flex items-start gap-5">
                                    <div className="w-14 h-14 rounded-2xl bg-white shadow-sm text-red-700 flex items-center justify-center shrink-0 group-hover:scale-110 group-hover:bg-red-600 group-hover:text-white transition-all duration-500">
                                        <ShieldCheck className="w-6 h-6" />
                                    </div>
                                    <div>
                                        <h4 className="text-lg font-black text-slate-900 mb-1">Zero Downpayment</h4>
                                        <p className="text-slate-600 text-sm font-medium leading-relaxed">Strictly no downpayments required for NSFAS funded students. Seamless move-in process.</p>
                                    </div>
                                </div>
                            </div>

                            <div className="group p-6 rounded-3xl bg-white/50 backdrop-blur-xl border border-white/60 shadow-sm hover:shadow-[0_8px_30px_rgb(185,28,28,0.08)] hover:bg-white/80 transition-all cursor-default">
                                <div className="flex items-start gap-5">
                                    <div className="w-14 h-14 rounded-2xl bg-white shadow-sm text-red-700 flex items-center justify-center shrink-0 group-hover:scale-110 group-hover:bg-red-600 group-hover:text-white transition-all duration-500">
                                        <Banknote className="w-6 h-6" />
                                    </div>
                                    <div>
                                        <h4 className="text-lg font-black text-slate-900 mb-1">Competitive Pricing</h4>
                                        <p className="text-slate-600 text-sm font-medium leading-relaxed">Find accommodation that perfectly suits your pocket without ever compromising on quality.</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="relative h-full min-h-[500px] lg:min-h-[600px] w-full flex items-center justify-center">
                        <div className="absolute inset-0 bg-gradient-to-br from-red-100 to-rose-50 rounded-[40px] transform rotate-3 scale-105 opacity-50 border border-white"></div>
                        
                        <div className="relative z-10 h-[90%] w-[90%] rounded-[2.5rem] overflow-hidden shadow-[0_20px_50px_rgb(0,0,0,0.1)] border-4 border-white">
                            <img 
                                src="https://images.unsplash.com/photo-1523240795612-9a054b0db644?q=80&w=2070&auto=format&fit=crop" 
                                alt="Students studying" 
                                className="w-full h-full object-cover hover:scale-105 transition-transform duration-1000"
                            />
                            <div className="absolute inset-0 bg-gradient-to-t from-slate-900/60 via-transparent to-transparent"></div>
                        </div>

                        <div className="absolute bottom-10 -left-6 z-20 bg-white/70 backdrop-blur-2xl p-5 rounded-3xl border border-white/60 shadow-[0_10px_30px_rgb(0,0,0,0.08)] flex items-center gap-4 animate-float-fast">
                            <div className="flex -space-x-3">
                                <div className="w-12 h-12 rounded-full border-2 border-white bg-slate-200 overflow-hidden"><img src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop" alt="User" /></div>
                                <div className="w-12 h-12 rounded-full border-2 border-white bg-slate-300 overflow-hidden"><img src="https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&auto=format&fit=crop" alt="User" /></div>
                                <div className="w-12 h-12 rounded-full border-2 border-white bg-red-600 flex items-center justify-center text-white text-[10px] font-black tracking-tighter">+500</div>
                            </div>
                            <div>
                                <p className="text-xs font-black text-slate-900 uppercase tracking-widest">Happy Students</p>
                                <div className="flex gap-1 text-yellow-500 mt-1">
                                    <Star className="w-3 h-3 fill-current" /><Star className="w-3 h-3 fill-current" /><Star className="w-3 h-3 fill-current" /><Star className="w-3 h-3 fill-current" /><Star className="w-3 h-3 fill-current" />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* ============================================================
                FEATURED ACCOMMODATIONS (with subtle grid overlay)
            ============================================================ */}
            <section className="relative py-20 px-6 overflow-hidden">
                <div
                    className="absolute inset-0 -z-0 opacity-[0.025] pointer-events-none"
                    style={{
                        backgroundImage: `linear-gradient(#000 1px, transparent 1px), linear-gradient(90deg, #000 1px, transparent 1px)`,
                        backgroundSize: '60px 60px',
                    }}
                />

                <div className="relative max-w-7xl mx-auto z-10">
                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-16">
                        <div>
                            <div className="flex items-center gap-2 mb-4">
                                <div className="h-[2px] w-8 bg-red-600 rounded-full"></div>
                                <p className="text-red-700 text-xs font-black uppercase tracking-widest">Our Portfolio</p>
                            </div>
                            <h2 className="text-4xl md:text-5xl font-black text-slate-900 leading-tight">Exclusive Residences</h2>
                        </div>
                        <Link href="/accommodations" className="group px-7 py-3.5 rounded-2xl bg-white/60 backdrop-blur-xl border border-white/80 text-slate-900 text-xs font-black uppercase tracking-widest hover:bg-slate-900 hover:text-white hover:border-slate-900 transition-all shadow-sm flex items-center gap-3">
                            View Collection <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                        </Link>
                    </div>

                    {isLoading ? (
                        <div className="flex flex-col items-center justify-center py-32 gap-5">
                            <div className="relative">
                                <div className="absolute inset-0 border-4 border-red-200 rounded-full animate-ping opacity-20"></div>
                                <Loader2 className="w-12 h-12 text-red-600 animate-spin relative z-10" />
                            </div>
                            <p className="text-slate-500 text-xs font-black tracking-[0.2em] uppercase">Syncing Properties...</p>
                        </div>
                    ) : error ? (
                        <div className="w-full bg-white/60 backdrop-blur-xl border border-rose-200 text-rose-700 px-6 py-8 rounded-3xl text-sm font-bold text-center shadow-sm">
                            {error}
                        </div>
                    ) : featuredAccommodations.length === 0 ? (
                        <div className="w-full bg-white/40 backdrop-blur-xl border border-dashed border-slate-300 text-slate-500 px-6 py-20 rounded-[32px] text-center font-bold flex flex-col items-center shadow-sm">
                            <MapPin className="w-12 h-12 text-slate-300 mb-4" />
                            <p className="text-lg">No accommodations available right now.</p>
                        </div>
                    ) : (
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                            {featuredAccommodations.map((acc, index) => {
                                const imageUrl = getCardImage(acc);
                                const imageCount = acc.images?.length || 0;
                                
                                return (
                                    <Link 
                                        href={`/accommodations-details/${acc.id}`} 
                                        key={acc.id || index} 
                                        className="group relative h-[480px] rounded-[2.5rem] overflow-hidden border border-white/60 shadow-[0_8px_30px_rgb(0,0,0,0.06)] hover:shadow-[0_20px_40px_rgba(185,28,28,0.15)] cursor-pointer transition-all duration-500 hover:-translate-y-2 bg-white block"
                                    >
                                        <img 
                                            src={imageUrl}
                                            alt={acc.name}
                                            className="absolute inset-0 w-full h-full object-cover transition-transform duration-1000 group-hover:scale-110"
                                        />
                                        <div className="absolute inset-0 bg-gradient-to-t from-slate-900/90 via-slate-900/20 to-transparent transition-opacity duration-500 group-hover:opacity-90"></div>
                                        
                                        <div className="absolute top-6 right-6 flex gap-2">
                                            <span className="px-4 py-2 rounded-xl bg-white/80 backdrop-blur-xl border border-white/40 text-slate-900 text-[10px] font-black uppercase tracking-widest shadow-lg shadow-black/10">
                                                {acc.gender_target || 'MIXED'}
                                            </span>
                                            {imageCount > 0 && (
                                                <span className="px-3 py-2 rounded-xl bg-slate-900/60 backdrop-blur-xl border border-white/20 text-white text-[10px] font-black uppercase tracking-widest shadow-lg shadow-black/10 flex items-center gap-1">
                                                    <ImageIcon className="w-3 h-3" /> {imageCount}
                                                </span>
                                            )}
                                        </div>

                                        <div className="absolute bottom-4 left-4 right-4 translate-y-4 group-hover:translate-y-0 transition-transform duration-500">
                                            <div className="p-6 rounded-[2rem] bg-white/20 backdrop-blur-2xl border border-white/30 flex flex-col gap-4 shadow-2xl relative overflow-hidden">
                                                <div className="absolute inset-0 bg-gradient-to-br from-white/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
                                                
                                                <div className="relative z-10">
                                                    <h3 className="text-white text-2xl font-black leading-tight line-clamp-1 mb-2">
                                                        {acc.name || 'Premium Residence'}
                                                    </h3>
                                                    
                                                    <div className="flex items-start gap-2 text-slate-200 font-medium">
                                                        <MapPin className="w-4 h-4 text-red-400 shrink-0 mt-0.5" />
                                                        <p className="text-xs line-clamp-2 leading-relaxed">
                                                            {acc.address || 'Address unlisted'}
                                                        </p>
                                                    </div>
                                                </div>

                                                <div className="relative z-10 pt-4 mt-2 border-t border-white/20 flex items-center justify-between opacity-0 group-hover:opacity-100 transition-opacity duration-500 delay-100">
                                                    <span className="text-white text-xs font-bold uppercase tracking-widest">View Property</span>
                                                    <div className="w-8 h-8 rounded-full bg-red-600 flex items-center justify-center">
                                                        <ArrowRight className="w-4 h-4 text-white" />
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </Link>
                                );
                            })}
                        </div>
                    )}
                </div>
            </section>

            {/* ============================================================
                MEET OUR TEAM (with soft premium glow)
            ============================================================ */}
            <section className="relative py-24 px-6 bg-white/40 border-t border-white/60 overflow-hidden">
                <div className="absolute top-1/2 left-1/4 w-[700px] h-[700px] bg-red-500/5 rounded-full blur-[140px] pointer-events-none" />
                <div className="absolute bottom-0 right-1/4 w-[500px] h-[500px] bg-rose-400/5 rounded-full blur-[120px] pointer-events-none" />

                <div className="relative max-w-7xl mx-auto z-10">
                    <div className="text-center mb-20 space-y-4">
                        <div className="flex items-center justify-center gap-2 mb-4">
                            <div className="h-[2px] w-8 bg-red-600 rounded-full"></div>
                            <p className="text-red-700 text-xs font-black uppercase tracking-widest">The Faces Behind</p>
                            <div className="h-[2px] w-8 bg-red-600 rounded-full"></div>
                        </div>
                        <h2 className="text-4xl md:text-5xl font-black text-slate-900 leading-tight">Meet Our Team</h2>
                        <p className="text-slate-600 max-w-2xl mx-auto font-medium">
                            Dedicated professionals working around the clock to accommodate you to greater heights. Click on a team member to view their full profile.
                        </p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
                        {teamMembers.map((member, idx) => (
                            <Link href={`/team/${member.id}`} key={idx} className="block h-full">
                                <div className="h-full p-6 rounded-[2.5rem] bg-slate-50 border border-slate-100 shadow-sm hover:shadow-[0_20px_40px_rgba(185,28,28,0.08)] flex flex-col group transition-all duration-500 hover:-translate-y-2 animate-in fade-in slide-in-from-bottom-8 fill-mode-both cursor-pointer overflow-hidden">
                                    
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
                                    
                                    <div className="flex-1 flex flex-col">
                                        <h4 className="text-slate-900 text-xl font-black mb-2">{member.name}</h4>
                                        <span className="inline-block px-3 py-1 rounded-lg bg-red-50 text-red-700 text-[10px] uppercase font-black tracking-widest mb-4 border border-red-100 w-fit">
                                            {member.role}
                                        </span>
                                        
                                        <p className="text-slate-500 text-sm font-medium leading-relaxed mb-4 line-clamp-3">
                                            {member.description}
                                        </p>
                                        
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

            <Footer />
        </div>
    );
}