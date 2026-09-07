import React from 'react';
import Link from 'next/link';
import { Phone, Mail } from 'lucide-react';

const FacebookIcon = ({ className }: { className?: string }) => (
  <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"/></svg>
);
const LinkedinIcon = ({ className }: { className?: string }) => (
  <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/><rect x="2" y="9" width="4" height="12"/><circle cx="4" cy="4" r="2"/></svg>
);
const InstagramIcon = ({ className }: { className?: string }) => (
  <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="2" width="20" height="20" rx="5" ry="5"/><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/><line x1="17.5" y1="6.5" x2="17.51" y2="6.5"/></svg>
);

export default function Footer() {
    return (
        <footer className="bg-slate-950 pt-24 pb-10 px-6 relative z-10 border-t-4 border-red-600 text-slate-300">
            <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-12 mb-16">
                <div className="md:col-span-2 space-y-6">
                    <div className="flex items-center gap-3 mb-6 bg-white p-2 rounded-2xl inline-flex">
                        <img src="https://res.cloudinary.com/dajihjqkc/image/upload/v1788813673/sh_logo_bpds8p.png" alt="Student Heights Logo" className="h-12 w-auto object-contain" />
                    </div>
                    <p className="text-slate-400 text-sm leading-relaxed max-w-sm font-medium">
                        Revolutionizing student accommodation. We provide a secure, seamless, and premium living experience tailored for academic excellence.
                    </p>
                </div>
                <div className="space-y-6">
                    <h4 className="text-white font-black tracking-widest uppercase text-xs">Contact</h4>
                    <div className="space-y-4 text-slate-400 text-sm font-medium">
                        <a href="mailto:info@studentheights.co.za" className="flex items-center gap-3 hover:text-white transition-colors group">
                            <div className="p-2 rounded-lg bg-slate-900 group-hover:bg-red-600 transition-colors"><Mail className="w-4 h-4" /></div>
                            info@studentheights.co.za
                        </a>
                        <div className="flex items-center gap-3 group cursor-default">
                            <div className="p-2 rounded-lg bg-slate-900"><Phone className="w-4 h-4" /></div>
                            +27 81 009 6965
                        </div>
                    </div>
                </div>
                <div className="space-y-6">
                    <h4 className="text-white font-black tracking-widest uppercase text-xs">Navigation</h4>
                    <div className="flex flex-col gap-3 text-sm font-medium text-slate-400">
                        <Link href="/accommodations" className="hover:text-white hover:translate-x-1 transition-all w-fit">Residences</Link>
                        <Link href="/about" className="hover:text-white hover:translate-x-1 transition-all w-fit">About Us</Link>
                        <Link href="/login" className="hover:text-white hover:translate-x-1 transition-all w-fit">Portal Login</Link>
                    </div>
                    <div className="pt-4 space-y-4">
                        <h4 className="text-white font-black tracking-widest uppercase text-xs">Social</h4>
                        <div className="flex gap-3">
                            <a href="#" className="w-10 h-10 rounded-xl bg-slate-900 border border-slate-800 flex items-center justify-center hover:bg-blue-600 hover:border-blue-500 hover:text-white transition-all shadow-sm"><FacebookIcon className="w-4 h-4" /></a>
                            <a href="#" className="w-10 h-10 rounded-xl bg-slate-900 border border-slate-800 flex items-center justify-center hover:bg-blue-500 hover:border-blue-400 hover:text-white transition-all shadow-sm"><LinkedinIcon className="w-4 h-4" /></a>
                            <a href="#" className="w-10 h-10 rounded-xl bg-slate-900 border border-slate-800 flex items-center justify-center hover:bg-pink-600 hover:border-pink-500 hover:text-white transition-all shadow-sm"><InstagramIcon className="w-4 h-4" /></a>
                        </div>
                    </div>
                </div>
            </div>
            <div className="max-w-7xl mx-auto pt-8 border-t border-slate-800 flex flex-col md:flex-row items-center justify-between gap-4 text-[10px] font-black text-slate-500 uppercase tracking-widest">
                <p>Copyright © {new Date().getFullYear()} All rights reserved | Developed by MKTECHCLOUD (Pty) Ltd</p>
                <div className="flex gap-6">
                    <Link href="/terms-and-conditions" className="hover:text-white transition-colors">Terms of Use</Link>
                    <Link href="/privacy-policy" className="hover:text-white transition-colors">Privacy Policy</Link>
                </div>
            </div>
        </footer>
    );
}