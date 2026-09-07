"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { auth } from '../firebase/config';
import { getIdToken, onAuthStateChanged, signOut } from 'firebase/auth';
import { apiFetch, BASE_URL } from './api';
import { 
    LogOut, 
    User,
    ChevronDown,
    Loader2,
    Menu,
    X,
    Home,
    Building2,
    Info,
    Headphones
} from 'lucide-react';

export default function Navbar() {
    const router = useRouter();
    const [user, setUser] = useState<any>(null);
    const [profile, setProfile] = useState<any>(null);
    const [role, setRole] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);
    const [menuOpen, setMenuOpen] = useState(false);
    const [mobileOpen, setMobileOpen] = useState(false);
    const [faceImage, setFaceImage] = useState<string | null>(null);
    const [profileFetched, setProfileFetched] = useState(false); // prevents repeated attempts

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
            if (firebaseUser && !firebaseUser.isAnonymous) {
                setUser(firebaseUser);
                if (!profileFetched) {
                    try {
                        const token = await getIdToken(firebaseUser, true); // force refresh
                        const profileData = await fetchUserProfile(token);
                        if (profileData) {
                            setProfile(profileData);
                            if (role === 'student' && profileData?.id) {
                                fetchFaceImage(profileData.id, token);
                            }
                        }
                    } catch (error) {
                        console.debug("Profile fetch skipped:", error);
                    } finally {
                        setProfileFetched(true);
                    }
                }
            } else {
                setUser(null);
                setProfile(null);
                setFaceImage(null);
                setProfileFetched(false);
            }
            setLoading(false);
        });

        return () => unsubscribe();
    }, [role, profileFetched]);

    const fetchUserProfile = async (token: string) => {
        const endpoints = [
            { url: '/students/me/', role: 'student' },
            { url: '/landlords/me/', role: 'landlord' },
            { url: '/attendants/me/', role: 'attendant' },
            { url: '/admin-profile/me/', role: 'admin' }
        ];

        for (const endpoint of endpoints) {
            try {
                const res = await apiFetch(endpoint.url, {
                    method: 'GET',
                    headers: {
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json',
                    }
                });
                if (res && res.id) {
                    setRole(endpoint.role);
                    return res;
                }
            } catch (err) {
                // 403 = wrong role; just continue
                continue;
            }
        }
        return null;
    };

    const fetchFaceImage = async (studentId: string, token: string) => {
        try {
            const response = await fetch(`${BASE_URL}/students/${studentId}/decrypted-face/`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                }
            });
            if (response.ok) {
                const data = await response.json();
                if (data.face_base64) {
                    setFaceImage(`data:image/jpeg;base64,${data.face_base64}`);
                }
            }
        } catch (e) {
            console.debug("Face fetch skipped:", e);
        }
    };

    const handleLogout = async () => {
        try {
            await signOut(auth);
            router.push('/');
        } catch (error) {
            console.error("Logout failed:", error);
        }
    };

    const fullName = profile ? `${profile.name} ${profile.surname}` : '';
    const initials = profile ? `${profile.name?.charAt(0) || ''}${profile.surname?.charAt(0) || ''}`.toUpperCase() : '';

    const navLinks = [
        { href: '/', label: 'Home', icon: Home },
        { href: '/accommodations', label: 'Accommodations', icon: Building2 },
        { href: '/about', label: 'About', icon: Info },
        { href: '/contact-support', label: 'Contact Support', icon: Headphones },
    ];

    return (
        <nav className="fixed top-0 left-0 w-full z-[100] bg-white/80 backdrop-blur-xl border-b border-slate-200/50 shadow-sm">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 py-4 flex justify-between items-center">
                {/* Logo */}
                <Link href="/" className="flex items-center gap-2">
                    <img 
                        src="https://res.cloudinary.com/dajihjqkc/image/upload/v1788813673/sh_logo_bpds8p.png" 
                        alt="Student Heights" 
                        className="h-10 w-auto"
                    />
                    <span className="text-xl font-black text-slate-900 hidden md:block">Student Heights</span>
                </Link>

                {/* Desktop Navigation */}
                <div className="hidden md:flex items-center gap-6">
                    {navLinks.map((link) => (
                        <Link 
                            key={link.href} 
                            href={link.href} 
                            className="text-sm font-bold text-slate-600 hover:text-red-700 transition-colors flex items-center gap-1"
                        >
                            <link.icon className="w-4 h-4" />
                            {link.label}
                        </Link>
                    ))}
                </div>

                {/* Auth Section (Desktop) */}
                <div className="hidden md:flex items-center gap-4">
                    {loading ? (
                        <Loader2 className="w-5 h-5 animate-spin text-slate-400" />
                    ) : user && profile ? (
                        <div className="relative">
                            <button 
                                onClick={() => setMenuOpen(!menuOpen)}
                                className="flex items-center gap-2 px-3 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 transition-colors"
                            >
                                <div className="w-8 h-8 rounded-full bg-red-600 text-white flex items-center justify-center font-black text-sm overflow-hidden">
                                    {faceImage ? (
                                        <img src={faceImage} alt="Profile" className="w-full h-full object-cover" />
                                    ) : (
                                        initials
                                    )}
                                </div>
                                <span className="text-sm font-bold text-slate-700">{fullName}</span>
                                <ChevronDown className="w-4 h-4 text-slate-500" />
                            </button>

                            {menuOpen && (
                                <div className="absolute right-0 mt-2 w-48 bg-white rounded-xl shadow-lg border border-slate-200 py-2 animate-in fade-in zoom-in-95 duration-200">
                                    <Link 
                                        href="/profile" 
                                        className="block px-4 py-2 text-sm text-slate-700 hover:bg-slate-50"
                                        onClick={() => setMenuOpen(false)}
                                    >
                                        My Profile
                                    </Link>
                                    <button 
                                        onClick={handleLogout}
                                        className="w-full text-left px-4 py-2 text-sm text-rose-600 hover:bg-rose-50 flex items-center gap-2"
                                    >
                                        <LogOut className="w-4 h-4" />
                                        Logout
                                    </button>
                                </div>
                            )}
                        </div>
                    ) : (
                        <Link 
                            href="/login" 
                            className="px-5 py-2.5 bg-red-600 text-white rounded-xl text-sm font-bold shadow-lg shadow-red-900/20 hover:bg-red-700 transition-all"
                        >
                            Login
                        </Link>
                    )}
                </div>

                {/* Mobile Menu Button */}
                <button
                    onClick={() => setMobileOpen(!mobileOpen)}
                    className="md:hidden p-2 rounded-xl hover:bg-slate-100 transition"
                >
                    {mobileOpen ? <X className="w-6 h-6 text-slate-700" /> : <Menu className="w-6 h-6 text-slate-700" />}
                </button>
            </div>

            {/* Mobile Menu */}
            {mobileOpen && (
                <div className="md:hidden border-t border-slate-200 bg-white/95 backdrop-blur-xl animate-in slide-in-from-top-2 fade-in duration-200">
                    <div className="px-6 py-4 space-y-4">
                        {navLinks.map((link) => (
                            <Link 
                                key={link.href} 
                                href={link.href} 
                                className="flex items-center gap-3 text-sm font-bold text-slate-600 hover:text-red-700 transition-colors"
                                onClick={() => setMobileOpen(false)}
                            >
                                <link.icon className="w-5 h-5" />
                                {link.label}
                            </Link>
                        ))}

                        <div className="border-t border-slate-200 pt-4">
                            {loading ? (
                                <Loader2 className="w-5 h-5 animate-spin text-slate-400 mx-auto" />
                            ) : user && profile ? (
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center gap-3">
                                        <div className="w-10 h-10 rounded-full bg-red-600 text-white flex items-center justify-center font-black text-sm overflow-hidden">
                                            {faceImage ? (
                                                <img src={faceImage} alt="Profile" className="w-full h-full object-cover" />
                                            ) : (
                                                initials
                                            )}
                                        </div>
                                        <div>
                                            <p className="text-sm font-black text-slate-800">{fullName}</p>
                                            <button 
                                                onClick={() => { handleLogout(); setMobileOpen(false); }}
                                                className="text-xs text-rose-600 hover:text-rose-700 font-bold flex items-center gap-1"
                                            >
                                                <LogOut className="w-3 h-3" />
                                                Logout
                                            </button>
                                        </div>
                                    </div>
                                    <Link 
                                        href="/profile" 
                                        className="text-xs font-bold text-slate-500 hover:text-slate-700"
                                        onClick={() => setMobileOpen(false)}
                                    >
                                        Profile
                                    </Link>
                                </div>
                            ) : (
                                <Link 
                                    href="/login" 
                                    className="block text-center py-3 bg-red-600 text-white rounded-xl text-sm font-bold"
                                    onClick={() => setMobileOpen(false)}
                                >
                                    Login
                                </Link>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </nav>
    );
}