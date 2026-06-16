"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { 
  LayoutDashboard, ShieldAlert, Users, 
  LogOut, Bell, Search, Menu, X, UserCog,
  HeartPulse, Activity // NEW ICONS FOR MEDICAL
} from 'lucide-react';
import { apiFetch } from '../components/api'; 

export default function AdminLayout({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const [adminName, setAdminName] = useState('System Administrator');
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    
    const [badges, setBadges] = useState({
        pendingLandlords: 0,
        activeEmergencies: 0, // NEW BADGE
    });

    useEffect(() => {
        setIsMobileMenuOpen(false);
    }, [pathname]);

    useEffect(() => {
        const storedUserData = localStorage.getItem('user_data');
        if (storedUserData) {
            try {
                const parsed = JSON.parse(storedUserData);
                if (parsed.name) setAdminName(`${parsed.name} ${parsed.surname || ''}`);
            } catch (e) { console.error("Could not parse user data"); }
        }

        fetchBadgeCounts();
        const interval = setInterval(fetchBadgeCounts, 15000); // Check faster for emergencies
        return () => clearInterval(interval);
    }, []);

    const fetchBadgeCounts = async () => {
        try {
            const [landlordsData, emergenciesData] = await Promise.all([
                apiFetch('/landlords/').catch(() => []),
                apiFetch('/emergencies/').catch(() => [])
            ]);
            
            const pendingLandlords = (landlordsData.results || landlordsData || [])
                .filter((l: any) => l.manual_verification_status === true || l.is_verified === false).length;

            const activeAlerts = (emergenciesData.results || emergenciesData || [])
                .filter((e: any) => e.status === 'PENDING' || e.status === 'RESPONDING').length;

            setBadges({
                pendingLandlords,
                activeEmergencies: activeAlerts,
            });
        } catch (e) {
            console.error("Badge fetch failed", e);
        }
    };

    const handleLogout = () => {
        localStorage.clear();
        window.location.href = '/';
    };

    const getPageTitle = () => {
        if (pathname === '/admin') return 'System Dashboard';
        const path = pathname.split('/').pop() || 'dashboard';
        return path.replace('-', ' ');
    };

    const SidebarItem = ({ icon: Icon, label, href, badgeCount, isCritical = false }: { icon: any, label: string, href: string, badgeCount?: number, isCritical?: boolean }) => {
        const isActive = pathname === href; 
        
        // Use a deeper red for critical emergency tabs to make them stand out
        const activeBg = isCritical ? 'bg-red-600 shadow-red-600/20' : 'bg-rose-600 shadow-rose-600/20';
        const hoverText = isCritical ? 'hover:text-red-600 hover:bg-red-50' : 'hover:text-rose-600 hover:bg-rose-50';
        
        return (
            <Link href={href} className={`w-full flex items-center justify-between gap-3 px-5 py-3.5 rounded-xl transition-all duration-200 group ${
                isActive 
                    ? `${activeBg} text-white shadow-md` 
                    : `text-slate-500 ${hoverText}`
            }`}>
                <div className="flex items-center gap-3">
                    <Icon size={18} className={isActive ? 'text-white' : 'text-slate-400 group-hover:text-current'} />
                    <span className="text-[11px] font-bold tracking-tight uppercase">{label}</span>
                </div>
                
                {badgeCount && badgeCount > 0 ? (
                    <span className={`flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-lg text-[10px] font-black animate-in zoom-in duration-300 ${
                        isActive 
                        ? 'bg-white text-current' 
                        : 'bg-red-500 text-white shadow-sm shadow-red-500/30'
                    }`}>
                        {badgeCount > 99 ? '99+' : badgeCount}
                    </span>
                ) : null}
            </Link>
        );
    };

    return (
        <div className="min-h-screen bg-slate-50 text-slate-900 font-sans flex overflow-hidden">
            {isMobileMenuOpen && (
                <div 
                    className="fixed inset-0 bg-slate-900/30 backdrop-blur-sm z-40 lg:hidden animate-in fade-in duration-300"
                    onClick={() => setIsMobileMenuOpen(false)}
                />
            )}

            <aside className={`fixed inset-y-0 left-0 w-72 h-full flex flex-col border-r border-slate-200 bg-white z-50 shrink-0 shadow-[4px_0_24px_rgba(226,232,240,0.5)] transform transition-transform duration-300 ease-in-out lg:static lg:translate-x-0 ${
                isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full'
            }`}>
                <div className="p-6 lg:p-8 flex items-center justify-between">
                    <div className="flex items-center gap-3 px-2">
                        <div className="w-8 h-8 bg-slate-900 rounded-xl flex items-center justify-center font-black text-white shadow-lg shadow-slate-500/30">SA</div>
                        <div>
                            <h1 className="text-sm font-black tracking-tight text-slate-900 uppercase">SYS ADMIN</h1>
                            <p className="text-[10px] text-rose-500 font-bold tracking-widest uppercase mt-0.5">Control Panel</p>
                        </div>
                    </div>
                    <button 
                        onClick={() => setIsMobileMenuOpen(false)} 
                        className="lg:hidden p-2 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-all"
                    >
                        <X size={20} />
                    </button>
                </div>

                <nav className="flex-1 px-4 space-y-1.5 overflow-y-auto custom-scrollbar pb-6">
                    <SidebarItem icon={LayoutDashboard} label="Dashboard" href="/admin" />
                    
                    {/* NEW EMERGENCY WING */}
                    <div className="pt-4 pb-1 px-5">
                        <p className="text-[9px] font-black text-slate-400 tracking-widest uppercase">Emergency & Medical</p>
                    </div>
                    <SidebarItem 
                        icon={HeartPulse} 
                        label="Medical Responders" 
                        href="/admin/medical-responders" 
                        isCritical={true}
                    />
                    <SidebarItem 
                        icon={Activity} 
                        label="Emergency Logs" 
                        href="/admin/emergency-logs" 
                        badgeCount={badges.activeEmergencies}
                        isCritical={true}
                    />
                    {/* ------------------ */}

                    <div className="pt-4 pb-1 px-5">
                        <p className="text-[9px] font-black text-slate-400 tracking-widest uppercase">System Config</p>
                    </div>
                    <SidebarItem 
                        icon={ShieldAlert} 
                        label="Landlord Verification" 
                        href="/admin/manage-landlords" 
                        badgeCount={badges.pendingLandlords} 
                    />
                    <SidebarItem icon={Users} label="System Users" href="/admin/users" />
                    <SidebarItem icon={UserCog} label="My Profile" href="/admin/profile" />
                </nav>

                <div className="p-4 border-t border-slate-100 bg-white">
                    <button onClick={handleLogout} className="w-full flex items-center gap-3 px-4 py-3 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-all text-xs font-bold">
                        <LogOut size={16} /> TERMINATE SESSION
                    </button>
                </div>
            </aside>

            <main className="flex-1 h-screen overflow-y-auto bg-slate-50 relative w-full min-w-0">
                <header className="sticky top-0 z-30 flex justify-between items-center px-6 lg:px-8 py-4 lg:py-6 backdrop-blur-xl bg-white/80 border-b border-slate-200/50 supports-[backdrop-filter]:bg-white/60">
                    <div className="flex items-center gap-4">
                        <button 
                            onClick={() => setIsMobileMenuOpen(true)}
                            className="lg:hidden p-2.5 bg-white border border-slate-200 rounded-xl text-slate-600 shadow-sm hover:bg-slate-50 transition-all"
                        >
                            <Menu size={20} />
                        </button>

                        <div>
                            <h2 className="text-xl lg:text-2xl font-black tracking-tight text-slate-900 capitalize truncate max-w-[150px] sm:max-w-xs">{getPageTitle()}</h2>
                            <p className="hidden sm:flex text-slate-400 text-[10px] font-bold uppercase tracking-[0.2em] mt-1 items-center gap-2">
                                <span className="w-1.5 h-1.5 rounded-full bg-rose-500 animate-pulse"></span>
                                Root Access: <span className="text-slate-600 truncate max-w-[120px]">{adminName}</span>
                            </p>
                        </div>
                    </div>
                    
                    <div className="flex items-center gap-3 lg:gap-4">
                        <div className="hidden md:block relative group">
                            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300" size={16} />
                            <input 
                                type="text" 
                                placeholder="Global System Search..." 
                                className="bg-slate-100/50 border border-slate-200 pl-11 pr-4 py-2.5 rounded-xl outline-none w-64 lg:w-80 text-sm focus:bg-white focus:border-rose-400 transition-all placeholder-slate-400 font-medium shadow-inner shadow-slate-100/50"
                            />
                        </div>
                        
                        <button className="md:hidden p-2.5 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-slate-600 transition-all shadow-sm">
                            <Search size={18} />
                        </button>

                        <button className="relative p-2.5 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-slate-600 transition-all shadow-sm">
                            <Bell size={18} />
                        </button>
                    </div>
                </header>

                <div className="p-4 sm:p-6 lg:p-10 max-w-7xl mx-auto">
                    {children}
                </div>
            </main>
        </div>
    );
}