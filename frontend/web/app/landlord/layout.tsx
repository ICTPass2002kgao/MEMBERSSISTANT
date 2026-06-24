"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { 
  LayoutDashboard, Building2, Users, User, Wrench, 
  CreditCard, LogOut, Bell, Search, UserCog, 
  MessageCircleIcon, Fingerprint, ClipboardCheck, SparkleIcon,QrCode,
  Menu, X,
  HeartPulse,
  Activity,
  MapIcon
} from 'lucide-react';
import { apiFetch } from '../components/api'; // Adjust path if needed

export default function LandlordLayout({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const router = useRouter();
    const [landlordName, setLandlordName] = useState('Administrator');
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    
    const [badges, setBadges] = useState({
        maintenance: 0,
        permits: 0,
        applications: 0,
        notifications: 0,
    });
    
    useEffect(() => {
        setIsMobileMenuOpen(false);
    }, [pathname]);
 
    useEffect(() => {
        const storedUserData = localStorage.getItem('user_data');
        if (storedUserData) {
            try {
                const parsed = JSON.parse(storedUserData);
                
                // Assuming your payload uses either `is_verified` or `verification_status`
                const isVerified = parsed.is_verified === true || parsed.verification_status === 'VERIFIED';
                
                if (!isVerified && pathname !== '/landlord/profile') {
                    router.push('/landlord/profile');
                }
            } catch (e) { 
                console.error("Could not parse user data for verification check"); 
            }
        }
    }, [pathname, router]);

    useEffect(() => {
        const storedUserData = localStorage.getItem('user_data');
        if (storedUserData) {
            try {
                const parsed = JSON.parse(storedUserData);
                if (parsed.name) setLandlordName(`${parsed.name} ${parsed.surname || ''}`);
            } catch (e) { console.error("Could not parse user data"); }
        }

        fetchBadgeCounts();
        const interval = setInterval(fetchBadgeCounts, 30000); 
        return () => clearInterval(interval);
    }, []);

    const fetchBadgeCounts = async () => {
        try {
            // Fetch notifications along with other badge data (Removed /emergencies/ fetch)
            const [issuesData, permitsData, studentsData, notificationsData] = await Promise.all([
                apiFetch('/issues/').catch(() => []),
                apiFetch('/leave-permits/').catch(() => []),
                apiFetch('/students/').catch(() => []),
                apiFetch('/notifications/').catch(() => [])
            ]);

            const pendingIssues = (issuesData.results || issuesData || [])
                .filter((i: any) => i.status === 'PENDING').length;

            const pendingPermits = (permitsData.results || permitsData || [])
                .filter((p: any) => p.status === 'REQUESTED').length;

            const pendingApplications = (studentsData.results || studentsData || [])
                .filter((s: any) => s.room === null && !s.verification_status && s.applied_accommodation_name != null).length;

            // Filter unread notifications
            const unreadNotifications = (notificationsData.results || notificationsData || [])
                .filter((n: any) => n.is_read === false).length;

            setBadges({
                maintenance: pendingIssues,
                permits: pendingPermits,
                applications: pendingApplications,
                notifications: unreadNotifications
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
        const path = pathname.split('/').pop() || 'dashboard';
        return path.replace('-', ' ');
    };

    const SidebarItem = ({ icon: Icon, label, href, badgeCount,isCritical = false  }: { icon: any, label: string, href: string, badgeCount?: number,isCritical?: boolean }) => {
        const isActive = pathname === href; 
        
        const activeBg = isCritical ? 'bg-red-600 shadow-red-600/20' : 'bg-rose-600 shadow-rose-600/20';
        const hoverText = isCritical ? 'hover:text-red-600 hover:bg-red-50' : 'hover:text-rose-600 hover:bg-rose-50';
        
        return (
            <Link href={href} className={`w-full flex items-center justify-between gap-3 px-5 py-3.5 rounded-xl transition-all duration-200 group ${
                isActive 
                    ? 'bg-blue-600 text-white shadow-md shadow-blue-600/20' 
                    : 'text-slate-500 hover:text-blue-600 hover:bg-blue-50'
            }`}>
                <div className="flex items-center gap-3">
                    <Icon size={18} className={isActive ? 'text-white' : 'text-slate-400 group-hover:text-blue-500'} />
                    <span className="text-[11px] font-bold tracking-tight uppercase">{label}</span>
                </div>
                
                {badgeCount !== undefined && badgeCount > 0 ? (
                    <span className={`flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-lg text-[10px] font-black animate-in zoom-in duration-300 ${
                        isActive 
                        ? 'bg-white text-blue-600' 
                        : 'bg-rose-500 text-white shadow-sm shadow-rose-500/30'
                    }`}>
                        {badgeCount > 99 ? '99+' : badgeCount}
                    </span>
                ) : null}
            </Link>
        );
    };

    return (
        <div className="min-h-screen bg-blue-50 text-blue-950 font-sans flex overflow-hidden">
            
            {/* --- MOBILE OVERLAY --- */}
            {isMobileMenuOpen && (
                <div 
                    className="fixed inset-0 bg-blue-950/30 backdrop-blur-sm z-40 lg:hidden animate-in fade-in duration-300"
                    onClick={() => setIsMobileMenuOpen(false)}
                />
            )}

            {/* --- SIDEBAR --- */}
            <aside className={`fixed inset-y-0 left-0 w-72 h-full flex flex-col border-r border-blue-100 bg-white z-50 shrink-0 shadow-[4px_0_24px_rgba(239,246,255,0.5)] transform transition-transform duration-300 ease-in-out lg:static lg:translate-x-0 ${
                isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full'
            }`}>
                <div className="p-6 lg:p-8 flex items-center justify-between">
                    <div className="flex items-center gap-3 px-2">
                        <div className="w-8 h-8 bg-blue-600 rounded-xl flex items-center justify-center font-black text-white shadow-lg shadow-blue-500/30">TRC</div>
                        <div>
                            <h1 className="text-sm font-black tracking-tight text-blue-950 uppercase">Memberssistant</h1>
                            <p className="text-[10px] text-blue-400 font-bold tracking-widest uppercase mt-0.5">Landlord Portal</p>
                        </div>
                    </div>
                    {/* Mobile Close Button */}
                    <button 
                        onClick={() => setIsMobileMenuOpen(false)} 
                        className="lg:hidden p-2 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-all"
                    >
                        <X size={20} />
                    </button>
                </div>

                <nav className="flex-1 px-4 space-y-1.5 overflow-y-auto custom-scrollbar pb-6">
                    <SidebarItem icon={LayoutDashboard} label="Overview" href="/landlord/dashboard" />
                    
                    {/* Added Notifications Tab Here */}
                    <SidebarItem 
                        icon={Bell} 
                        label="Notifications" 
                        href="/landlord/notifications" 
                        badgeCount={badges.notifications} 
                    />

                    <SidebarItem icon={Building2} label="Accommodations" href="/landlord/accommodations" />
                    
                    <SidebarItem 
                        icon={SparkleIcon} 
                        label="Applications" 
                        href="/landlord/applications" 
                        badgeCount={badges.applications} 
                    />
                     <div className="pt-4 pb-1 px-5">
                        <p className="text-[9px] font-black text-slate-400 tracking-widest uppercase">Emergency & Medical</p>
                    </div>
                    <SidebarItem 
                        icon={HeartPulse} 
                        label="Medical Responders" 
                        href="/landlord/medical-responders" 
                        isCritical={true}
                    />
                    <SidebarItem 
                        icon={Activity} 
                        label="Emergency Logs" 
                        href="/landlord/emergency-logs" 
                        isCritical={true}
                    />
                    <SidebarItem 
                        icon={MapIcon} 
                        label="Res Map" 
                        href="/landlord/res-buildings-map"   
                    />
                    <SidebarItem icon={Users} label="Students" href="/landlord/students" />
                    <SidebarItem icon={UserCog} label="Attendants" href="/landlord/attendants" />
                    <SidebarItem icon={Fingerprint} label="Students Verification" href="/landlord/students-verification" />
                    
                    <SidebarItem 
                        icon={Wrench} 
                        label="Maintenance" 
                        href="/landlord/maintenance" 
                        badgeCount={badges.maintenance} 
                    />
                    <SidebarItem 
                        icon={QrCode} 
                        label="Gate Passes" 
                        href="/landlord/gate-passes" 
                    />
                    <SidebarItem 
                        icon={ClipboardCheck} 
                        label="Exit Permits" 
                        href="/landlord/permits" 
                        badgeCount={badges.permits} 
                    />
                    
                    <SidebarItem icon={CreditCard} label="Finance" href="/landlord/finance" />
                    <SidebarItem icon={MessageCircleIcon} label="Communication" href="/landlord/communication" />
                    <SidebarItem icon={User} label="My Profile" href="/landlord/profile" />
                </nav>

                <div className="p-4 border-t border-blue-50 bg-white">
                    <button onClick={handleLogout} className="w-full flex items-center gap-3 px-4 py-3 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-all text-xs font-bold">
                        <LogOut size={16} /> TERMINATE SESSION
                    </button>
                </div>
            </aside>

            {/* --- MAIN CONTENT AREA --- */}
            <main className="flex-1 h-screen overflow-y-auto bg-white relative w-full min-w-0">
                <header className="sticky top-0 z-30 flex justify-between items-center px-6 lg:px-8 py-4 lg:py-6 backdrop-blur-xl bg-white/80 border-b border-blue-100/50 supports-[backdrop-filter]:bg-white/60">
                    <div className="flex items-center gap-4">
                        {/* Hamburger Menu (Mobile) */}
                        <button 
                            onClick={() => setIsMobileMenuOpen(true)}
                            className="lg:hidden p-2.5 bg-white border border-blue-100 rounded-xl text-blue-600 shadow-sm hover:bg-blue-50 transition-all"
                        >
                            <Menu size={20} />
                        </button>

                        <div>
                            <h2 className="text-xl lg:text-2xl font-black tracking-tight text-blue-950 capitalize truncate max-w-[150px] sm:max-w-xs">{getPageTitle()}</h2>
                            <p className="hidden sm:flex text-slate-400 text-[10px] font-bold uppercase tracking-[0.2em] mt-1 items-center gap-2">
                                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                                System Online: <span className="text-blue-600 truncate max-w-[120px]">{landlordName}</span>
                            </p>
                        </div>
                    </div>
                    
                    <div className="flex items-center gap-3 lg:gap-4">
                        {/* Search Bar */}
                        <div className="hidden md:block relative group">
                            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300" size={16} />
                            <input 
                                type="text" 
                                placeholder="Global System Search..." 
                                className="bg-blue-50/50 border border-blue-100 pl-11 pr-4 py-2.5 rounded-xl outline-none w-64 lg:w-80 text-sm focus:bg-white focus:border-blue-400 transition-all placeholder-blue-300 font-medium shadow-inner shadow-blue-50/50"
                            />
                        </div>
                        
                        <button className="md:hidden p-2.5 bg-white border border-blue-100 rounded-xl text-blue-400 hover:text-blue-600 transition-all shadow-sm">
                            <Search size={18} />
                        </button>

                        {/* Top Header Notification Bell */}
                        <Link href="/landlord/notifications" className="relative p-2.5 bg-white border border-blue-100 rounded-xl text-blue-400 hover:text-blue-600 transition-all shadow-sm block">
                            <Bell size={18} />
                            {badges.notifications > 0 && (
                                <span className="absolute top-2 right-2.5 w-2.5 h-2.5 bg-rose-500 rounded-full border-2 border-white animate-pulse"></span>
                            )}
                        </Link>
                    </div>
                </header>

                <div className="p-4 sm:p-6 lg:p-10 max-w-7xl mx-auto">
                    {children}
                </div>
            </main>
        </div>
    );
}