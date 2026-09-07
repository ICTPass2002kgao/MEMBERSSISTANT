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
    Image as ImageIcon
} from 'lucide-react';
import { apiFetch } from './components/api';
import Footer from './components/Footer';
import Navbar from './components/Navbar';

interface Accommodation {
    id: string | number;
    name: string;
    address: string;
    gender_target: string;
    accommodation_logo_url?: string;
    images?: { id?: string | number; image_url: string; is_primary?: boolean }[];
}

export default function HomePage() {
    const [accommodations, setAccommodations] = useState<Accommodation[]>([]);
    const [isLoading, setIsLoading] = useState<boolean>(true);
    const [error, setError] = useState<string>('');

    useEffect(() => { 

        const fetchAccommodations = async () => {
            try {
                const data = await apiFetch('/accommodations/', {
                    method: 'GET',
                    headers: { 'Content-Type': 'application/json' }, 
                });
                
                if (data && data.results) {
                    setAccommodations(data.results);
                } else if (Array.isArray(data)) {
                    setAccommodations(data);
                } else {
                    setAccommodations([]);
                }
            } catch (err: any) {
                console.error("Fetch Accommodations Error:", err);
                if (err.name === 'AbortError') {
                    setError('Request timed out. Please check your connection and try again.');
                } else {
                    setError('Could not connect to the server. Please try again later.');
                }
            } finally { 
                setIsLoading(false);
            }
        };

        fetchAccommodations();
 
    }, []);

    const featuredAccommodations = accommodations.slice(0, 3);

    // Helper to get the best image for a card
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

    return (
        <div className="w-full bg-blue-50">

            <Navbar />
            {/* Cinematic Hero Section */}
            <section className="relative pt-48 pb-20 px-6 min-h-[95vh] flex flex-col items-center justify-center">
                <div className="max-w-5xl mx-auto text-center space-y-8 animate-in slide-in-from-bottom-12 fade-in duration-1000 fill-mode-both">
                    
                    {/* Glassmorphism Badge */}
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
                        {/* Glassmorphism Button */}
                        <Link href="/about" className="w-full sm:w-auto px-10 py-4 rounded-2xl bg-white/40 backdrop-blur-xl border border-white/60 text-slate-800 text-sm font-black uppercase tracking-widest hover:bg-white/60 hover:text-red-700 hover:border-white transition-all shadow-sm flex items-center justify-center hover:-translate-y-1 hover:shadow-md">
                            Our Story
                        </Link>
                    </div>
                </div>

                <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-3 text-slate-500 animate-bounce cursor-default">
                    <span className="text-[9px] uppercase tracking-[0.3em] font-bold">Discover</span>
                    <ChevronDown className="w-5 h-5 text-red-600" />
                </div>
            </section>

            {/* Bento-Box Style About Teaser */}
            <section className="py-32 px-6">
                <div className="max-w-7xl mx-auto grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
                    
                    {/* Left: Interactive Features */}
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
                            {/* Glassmorphism Feature Cards */}
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

                    {/* Right: Floating Hero Graphic */}
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

                        {/* Floating Glass Stat Card */}
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

            {/* Featured Accommodations */}
            <section className="py-32 px-6">
                <div className="max-w-7xl mx-auto">
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
                                        
                                        {/* Floating Gender Badge */}
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

                                        {/* Glassmorphism Content Card */}
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

            <Footer />
        </div>
    );
}