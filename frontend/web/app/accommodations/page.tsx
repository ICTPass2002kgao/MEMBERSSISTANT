"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { 
    MapPin, 
    Loader2, 
    Search,
    ArrowRight,
    Image as ImageIcon
} from 'lucide-react';
import { apiFetch } from '../components/api';
import Navbar from '../components/Navbar';
import Footer from '../components/Footer';

interface Accommodation {
    id: string | number;
    name: string;
    address: string;
    gender_target: string;
    accommodation_logo_url?: string;
    images?: { id?: string | number; image_url: string; is_primary?: boolean }[];
}

export default function AccommodationsPage() {
    const [accommodations, setAccommodations] = useState<Accommodation[]>([]);
    const [isLoading, setIsLoading] = useState<boolean>(true);
    const [error, setError] = useState<string>('');
    const [searchQuery, setSearchQuery] = useState('');

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
                setError('Could not connect to the server. Please try again later.');
            } finally {
                setIsLoading(false);
            }
        };

        fetchAccommodations();
    }, []);

    const filteredAccommodations = accommodations.filter(acc => 
        acc.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
        acc.address.toLowerCase().includes(searchQuery.toLowerCase())
    );

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
        <div className="w-full bg-blue-50 text-slate-900">
            <Navbar/> 

            <section className="pt-48 pb-32 px-6 w-full bg-blue-50 text-slate-900">
                <div className="max-w-7xl mx-auto">
                    
                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-8 mb-16 animate-in slide-in-from-bottom-8 fade-in duration-700">
                        <div>
                            <div className="flex items-center gap-2 mb-4">
                                <div className="h-[2px] w-8 bg-red-600 rounded-full"></div>
                                <p className="text-red-700 text-xs font-black uppercase tracking-widest">Our Portfolio</p>
                            </div>
                            <h1 className="text-4xl md:text-6xl font-black text-slate-900 tracking-tighter">All Residences</h1>
                        </div>

                        <div className="relative w-full md:w-96">
                            <div className="absolute inset-y-0 left-0 pl-5 flex items-center pointer-events-none">
                                <Search className="h-5 w-5 text-slate-400" />
                            </div>
                            <input
                                type="text"
                                placeholder="Search by name or address..."
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                                className="w-full pl-12 pr-5 py-4 bg-white/80 backdrop-blur-xl border border-slate-200/60 rounded-2xl outline-none focus:border-red-500 focus:ring-2 focus:ring-red-500/20 transition-all shadow-[0_8px_30px_rgb(0,0,0,0.04)] text-sm font-medium text-slate-900 placeholder:text-slate-400"
                            />
                        </div>
                    </div>

                    {isLoading ? (
                        <div className="flex flex-col items-center justify-center py-40 gap-5">
                            <div className="relative">
                                <div className="absolute inset-0 border-4 border-red-200 rounded-full animate-ping opacity-20"></div>
                                <Loader2 className="w-12 h-12 text-red-600 animate-spin relative z-10" />
                            </div>
                            <p className="text-slate-400 text-xs font-black tracking-[0.2em] uppercase">Fetching Properties...</p>
                        </div>
                    ) : error ? (
                        <div className="w-full bg-rose-50 border border-rose-200 text-rose-700 px-6 py-8 rounded-3xl text-sm font-bold text-center shadow-sm">
                            {error}
                        </div>
                    ) : filteredAccommodations.length === 0 ? (
                        <div className="w-full bg-white/60 backdrop-blur-2xl border border-dashed border-slate-300 text-slate-500 px-6 py-32 rounded-[3rem] text-center shadow-sm font-bold flex flex-col items-center">
                            <MapPin className="w-16 h-16 text-slate-300 mb-6" />
                            <p className="text-xl text-slate-600 mb-2">No properties found</p>
                            <p className="text-sm font-medium text-slate-400">Try adjusting your search criteria</p>
                        </div>
                    ) : (
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-10 animate-in slide-in-from-bottom-12 fade-in duration-1000">
                            {filteredAccommodations.map((acc, index) => {
                                const imageUrl = getCardImage(acc);
                                const imageCount = acc.images?.length || 0;
                                
                                return (
                                    <Link 
                                        href={`/accommodations-details/${acc.id}`} 
                                        key={acc.id || index} 
                                        className="group relative h-[480px] rounded-[2.5rem] overflow-hidden border border-slate-200 shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_20px_40px_rgba(185,28,28,0.15)] cursor-pointer transition-all duration-500 hover:-translate-y-2 bg-slate-100 block"
                                    >
                                        <img 
                                            src={imageUrl}
                                            alt={acc.name}
                                            className="absolute inset-0 w-full h-full object-cover transition-transform duration-1000 group-hover:scale-110"
                                        />
                                        <div className="absolute inset-0 bg-gradient-to-t from-slate-900/90 via-slate-900/20 to-transparent transition-opacity duration-500 group-hover:opacity-90"></div>
                                        
                                        <div className="absolute top-6 right-6 flex gap-2">
                                            <span className="px-4 py-2 rounded-xl bg-white/90 backdrop-blur-md text-slate-900 text-[10px] font-black uppercase tracking-widest shadow-lg shadow-black/10">
                                                {acc.gender_target || 'MIXED'}
                                            </span>
                                            {imageCount > 0 && (
                                                <span className="px-3 py-2 rounded-xl bg-slate-900/60 backdrop-blur-md text-white text-[10px] font-black uppercase tracking-widest shadow-lg shadow-black/10 flex items-center gap-1">
                                                    <ImageIcon className="w-3 h-3" /> {imageCount}
                                                </span>
                                            )}
                                        </div>

                                        <div className="absolute bottom-4 left-4 right-4 translate-y-4 group-hover:translate-y-0 transition-transform duration-500">
                                            <div className="p-6 rounded-[2rem] bg-white/10 backdrop-blur-2xl border border-white/20 flex flex-col gap-4 shadow-2xl relative overflow-hidden">
                                                <div className="absolute inset-0 bg-gradient-to-br from-white/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
                                                
                                                <div className="relative z-10">
                                                    <h3 className="text-white text-2xl font-black leading-tight line-clamp-1 mb-2">
                                                        {acc.name || 'Premium Residence'}
                                                    </h3>
                                                    
                                                    <div className="flex items-start gap-2 text-slate-300 font-medium">
                                                        <MapPin className="w-4 h-4 text-red-400 shrink-0 mt-0.5" />
                                                        <p className="text-xs line-clamp-2 leading-relaxed">
                                                            {acc.address || 'Address unlisted'}
                                                        </p>
                                                    </div>
                                                </div>

                                                <div className="relative z-10 pt-4 mt-2 border-t border-white/10 flex items-center justify-between opacity-0 group-hover:opacity-100 transition-opacity duration-500 delay-100">
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
            <Footer/>
        </div>
    );
}