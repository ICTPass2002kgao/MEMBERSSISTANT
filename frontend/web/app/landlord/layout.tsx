"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { 
  LayoutDashboard, Building2, Users, User, Wrench, 
  CreditCard, LogOut, Bell, Search, UserCog, 
  MessageCircleIcon, Fingerprint, ClipboardCheck, SparkleIcon, QrCode,
  Menu, X, HeartPulse, Activity, MapIcon, AlertTriangle, Printer, ShieldAlert, Loader2,
  ChevronLeft, ChevronRight 
} from 'lucide-react';
import { apiFetch } from '../components/api'; 

export default function LandlordLayout({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const router = useRouter();
    const [landlordName, setLandlordName] = useState('Administrator');
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
    const [isVerified, setIsVerified] = useState<boolean | null>(null);
    const [isPaymentDue, setIsPaymentDue] = useState<boolean>(false);
    const [invoiceData, setInvoiceData] = useState<{items: {name: string, count: number}[], totalStudents: number, amountDue: number, issueDate: string, dueDate: string}>({ items: [], totalStudents: 0, amountDue: 0, issueDate: '', dueDate: '' });
    const RATE_PER_STUDENT = 28.00; 
    const [badges, setBadges] = useState({ maintenance: 0, permits: 0, applications: 0, notifications: 0 });
    
    useEffect(() => { setIsMobileMenuOpen(false); }, [pathname]);
 
    useEffect(() => {
        const checkAccessAndBilling = async () => {
            const storedUserData = localStorage.getItem('user_data');
            if (storedUserData) {
                try {
                    const parsedRaw = JSON.parse(storedUserData);
                    const parsed = parsedRaw.user_data ? parsedRaw.user_data : parsedRaw;
                    if (parsed.name) setLandlordName(`${parsed.name} ${parsed.surname || ''}`);
                    if (parsed.is_verified !== undefined) setIsVerified(Boolean(parsed.is_verified));
                } catch (e) {}
            }

            try {
                const profile = await apiFetch('/landlords/me/');
                if (profile && (profile.id || profile.email)) {
                    localStorage.setItem('user_data', JSON.stringify(profile));
                    if (profile.name) setLandlordName(`${profile.name} ${profile.surname || ''}`);
                    
                    const verifiedStatus = profile.is_verified === true;
                    setIsVerified(verifiedStatus);
                    
                    let trialExpired = false;
                    if (profile.subscription_valid_until) {
                        trialExpired = Date.now() > new Date(profile.subscription_valid_until).getTime();
                    } else if (verifiedStatus) {
                        const trialStart = new Date(profile.trial_start_date || Date.now());
                        trialExpired = Math.floor((Date.now() - trialStart.getTime()) / (1000 * 60 * 60 * 24)) > 30;
                    }

                    if (verifiedStatus && trialExpired) {
                        setIsPaymentDue(true);
                        try {
                            const studentsData = await apiFetch('/students/');
                            const students = studentsData.results || studentsData || [];
                            
                            const grouped = students.reduce((acc: any, student: any) => {
                                const accName = student.accommodation_name || 'Unassigned Accommodation';
                                if (!acc[accName]) acc[accName] = 0;
                                acc[accName]++; return acc;
                            }, {});
                            
                            const items = Object.keys(grouped).map(name => ({ name, count: grouped[name] }));
                            const totalStudents = students.length;
                            const today = new Date();
                            const due = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);
                            
                            setInvoiceData({ items, totalStudents, amountDue: totalStudents * RATE_PER_STUDENT, issueDate: today.toLocaleDateString('en-ZA'), dueDate: due.toLocaleDateString('en-ZA') });
                        } catch (e) {}
                    }
                }
            } catch (err) {
                // If it fails with 403 because it's the wrong role, redirect to login
                if (err instanceof Error && err.message.includes('403')) {
                    localStorage.clear();
                    window.location.href = '/';
                }
            }
        };

        checkAccessAndBilling();
    }, [pathname]);

    useEffect(() => {
        fetchBadgeCounts();
        const interval = setInterval(fetchBadgeCounts, 30000); 
        return () => clearInterval(interval);
    }, []);

    const fetchBadgeCounts = async () => {
        try {
            const [issuesData, permitsData, studentsData, notificationsData] = await Promise.all([
                apiFetch('/issues/').catch(() => []), apiFetch('/leave-permits/').catch(() => []),
                apiFetch('/students/').catch(() => []), apiFetch('/notifications/').catch(() => [])
            ]);

            setBadges({
                maintenance: (issuesData.results || issuesData || []).filter((i: any) => i.status === 'PENDING').length,
                permits: (permitsData.results || permitsData || []).filter((p: any) => p.status === 'REQUESTED').length,
                applications: (studentsData.results || studentsData || []).filter((s: any) => s.room === null && !s.verification_status && s.applied_accommodation_name != null).length,
                notifications: (notificationsData.results || notificationsData || []).filter((n: any) => n.is_read === false).length
            });
        } catch (e) {}
    };

    const handleLogout = () => { localStorage.clear(); window.location.href = '/'; };
    const getPageTitle = () => { return (pathname.split('/').pop() || 'dashboard').replace('-', ' '); };
    const handlePrintInvoice = () => { window.print(); };

    const SidebarItem = ({ icon: Icon, label, href, badgeCount, isCritical = false }: { icon: any, label: string, href: string, badgeCount?: number, isCritical?: boolean }) => {
        const isActive = pathname === href; 
        return (
            <Link href={href} title={isSidebarCollapsed ? label : undefined} className={`relative w-full flex items-center ${isSidebarCollapsed ? 'justify-center p-3.5' : 'justify-between px-5 py-3.5'} rounded-xl transition-all duration-200 group ${isActive ? 'bg-blue-600 text-white shadow-md shadow-blue-600/20' : 'text-slate-500 hover:text-blue-600 hover:bg-blue-50'}`}>
                <div className="flex items-center gap-3">
                    <Icon size={18} className={isActive ? 'text-white' : 'text-slate-400 group-hover:text-blue-500'} />
                    {!isSidebarCollapsed && <span className="text-[11px] font-bold tracking-tight uppercase truncate">{label}</span>}
                </div>
                {badgeCount !== undefined && badgeCount > 0 ? (
                    isSidebarCollapsed ? (<span className="absolute top-2 right-2 w-2 h-2 bg-rose-500 rounded-full shadow-sm shadow-rose-500/50 animate-pulse"></span>) 
                    : (<span className={`flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-lg text-[10px] font-black animate-in zoom-in duration-300 ${isActive ? 'bg-white text-blue-600' : 'bg-rose-500 text-white shadow-sm shadow-rose-500/30'}`}>{badgeCount > 99 ? '99+' : badgeCount}</span>)
                ) : null}
            </Link>
        );
    };

    if (isVerified === false && pathname !== '/landlord/profile') {
        return (
            <div className="min-h-screen bg-slate-50 flex items-center justify-center p-6">
                <div className="max-w-md w-full bg-white rounded-[32px] p-8 shadow-2xl shadow-rose-900/10 text-center border border-rose-100 animate-in fade-in zoom-in duration-500">
                    <div className="w-20 h-20 bg-rose-50 text-rose-600 rounded-full flex items-center justify-center mx-auto mb-6 shadow-inner shadow-rose-200/50"><ShieldAlert size={40} /></div>
                    <h1 className="text-2xl font-black text-slate-900 tracking-tight mb-3">Verification Required</h1>
                    <p className="text-sm text-slate-500 leading-relaxed font-medium mb-8">You are currently unverified. You have <strong className="text-rose-600">no authority</strong> to access the dashboard, manage students, or perform any administrative duties until your identity has been strictly verified.</p>
                    <Link href="/landlord/profile" className="inline-flex items-center justify-center gap-2 bg-blue-600 text-white px-6 py-3.5 rounded-xl text-xs font-black tracking-widest uppercase hover:bg-blue-700 transition-all shadow-lg shadow-blue-500/30 w-full"><UserCog size={16} /> Click here to verify</Link>
                </div>
            </div>
        );
    }

    if (isVerified === true && isPaymentDue && pathname !== '/landlord/profile') {
        return (
            <div className="min-h-screen bg-slate-100 flex py-10 px-4 sm:px-6 lg:px-8 print:bg-white print:py-0 print:px-0">
                <div className="max-w-4xl w-full mx-auto bg-white rounded-3xl shadow-2xl overflow-hidden border border-slate-200 print:shadow-none print:border-none print:rounded-none">
                    <div className="bg-slate-900 p-8 text-white flex flex-col sm:flex-row justify-between items-center gap-6 print:bg-white print:text-black print:border-b print:border-slate-300">
                        <div className="flex items-center gap-4"><img src="/mktechcloud.png" alt="MK Techcloud Logo" className="h-16 object-contain bg-white rounded-lg p-1" /></div>
                        <div className="text-center sm:text-right">
                            <img src="/memberssistant_icon.png" alt="Memberssistant Logo" className="h-12 object-contain mx-auto sm:ml-auto sm:mr-0 mb-2" />
                            <h1 className="text-2xl font-black tracking-widest uppercase">System Invoice</h1>
                            <p className="text-slate-400 print:text-slate-500 text-xs font-bold tracking-widest mt-1">ACCOUNT SUSPENDED - PAYMENT DUE</p>
                        </div>
                    </div>

                    <div className="p-8 sm:p-12">
                        <div className="print:hidden mb-8 p-5 bg-rose-50 border border-rose-200 rounded-2xl flex items-start gap-4 text-rose-800">
                            <AlertTriangle size={24} className="shrink-0 mt-0.5" />
                            <div>
                                <h3 className="font-black text-sm tracking-tight mb-1">Your 1-Month Free Trial Has Expired</h3>
                                <p className="text-xs font-medium leading-relaxed">Your system access is currently locked due to an outstanding balance. Please settle the invoice below to instantly restore full access to your accommodations and resident management dashboard.</p>
                            </div>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-10 mb-10">
                            <div>
                                <p className="text-[10px] font-black tracking-widest text-slate-400 uppercase mb-2">Billed To</p>
                                <h3 className="font-black text-blue-950 text-lg">{landlordName}</h3>
                                <p className="text-sm font-medium text-slate-500 mt-1">Registered Landlord / Administrator</p>
                            </div>
                            <div className="sm:text-right">
                                <p className="text-[10px] font-black tracking-widest text-slate-400 uppercase mb-2">Invoice Details</p>
                                <p className="text-sm font-bold text-slate-700">Issue Date: <span className="font-medium text-slate-500 ml-2">{invoiceData.issueDate}</span></p>
                                <p className="text-sm font-bold text-slate-700 mt-1">Due Date: <span className="font-medium text-rose-600 ml-2">{invoiceData.dueDate}</span></p>
                                <p className="text-sm font-bold text-slate-700 mt-1">Platform Fee: <span className="font-medium text-slate-500 ml-2">R {RATE_PER_STUDENT.toFixed(2)} / Student</span></p>
                            </div>
                        </div>

                        <div className="overflow-x-auto rounded-xl border border-slate-200 mb-10">
                            <table className="w-full text-left">
                                <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 text-[10px] font-black uppercase tracking-widest">
                                    <tr><th className="p-4">Accommodation Name</th><th className="p-4 text-center">Total Students</th><th className="p-4 text-right">Subtotal</th></tr>
                                </thead>
                                <tbody className="divide-y divide-slate-100">
                                    {invoiceData.items.length === 0 ? (
                                        <tr><td colSpan={3} className="p-6 text-center text-sm font-medium text-slate-400">No students registered yet.</td></tr>
                                    ) : (
                                        invoiceData.items.map((item, idx) => (
                                            <tr key={idx} className="text-sm">
                                                <td className="p-4 font-bold text-slate-800">{item.name}</td>
                                                <td className="p-4 text-center font-medium text-slate-600">{item.count}</td>
                                                <td className="p-4 text-right font-black text-blue-900">R {(item.count * RATE_PER_STUDENT).toFixed(2)}</td>
                                            </tr>
                                        ))
                                    )}
                                </tbody>
                                <tfoot>
                                    <tr className="bg-blue-50/50">
                                        <td className="p-4 font-black text-blue-950 text-right uppercase tracking-wider text-xs" colSpan={2}>Total Amount Due</td>
                                        <td className="p-4 text-right font-black text-blue-700 text-lg">R {invoiceData.amountDue.toFixed(2)}</td>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>

                        <div className="bg-slate-50 rounded-2xl border border-slate-200 p-6 sm:p-8">
                            <h3 className="text-xs font-black tracking-widest text-slate-800 uppercase mb-4 flex items-center gap-2"><CreditCard size={16} className="text-blue-500" /> Banking Details for Payment</h3>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-y-4 gap-x-8 text-sm">
                                <div className="flex justify-between border-b border-slate-200 pb-2"><span className="font-bold text-slate-500">Account Name</span><span className="font-black text-slate-800 text-right">MK TECHCLOUD (Pty) Ltd</span></div>
                                <div className="flex justify-between border-b border-slate-200 pb-2"><span className="font-bold text-slate-500">Bank</span><span className="font-black text-slate-800 text-right">FNB</span></div>
                                <div className="flex justify-between border-b border-slate-200 pb-2"><span className="font-bold text-slate-500">Account Type</span><span className="font-black text-slate-800 text-right">FIRST BUSINESS ZERO ACCOUNT</span></div>
                                <div className="flex justify-between border-b border-slate-200 pb-2"><span className="font-bold text-slate-500">Account Number</span><span className="font-black text-slate-800 text-right">63216882472</span></div>
                                <div className="flex justify-between border-b border-slate-200 pb-2"><span className="font-bold text-slate-500">Branch Name</span><span className="font-black text-slate-800 text-right">PRESIDENT SQUARE VAAL</span></div>
                                <div className="flex justify-between border-b border-slate-200 pb-2"><span className="font-bold text-slate-500">Branch Code</span><span className="font-black text-slate-800 text-right">252049</span></div>
                                <div className="flex justify-between border-b border-slate-200 pb-2"><span className="font-bold text-slate-500">Swift Code</span><span className="font-black text-slate-800 text-right">FIRNZAJJ</span></div>
                                <div className="flex justify-between border-b border-slate-200 pb-2"><span className="font-bold text-slate-500">Reference</span><span className="font-black text-rose-600 text-right">{landlordName}</span></div>
                            </div>
                            <p className="text-[10px] text-slate-400 mt-4 text-center uppercase tracking-widest font-bold">Please send proof of payment to billing@memberssistant.com to lift the suspension.</p>
                        </div>

                        <div className="print:hidden mt-8 flex flex-col sm:flex-row gap-4 justify-end">
                            <button onClick={handleLogout} className="px-6 py-3 rounded-xl font-bold text-sm text-slate-500 bg-slate-100 hover:bg-slate-200 transition-colors uppercase tracking-wider">Log Out</button>
                            <button onClick={handlePrintInvoice} className="flex items-center justify-center gap-2 px-6 py-3 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 transition-all shadow-lg shadow-blue-500/30 uppercase tracking-widest"><Printer size={18} /> Download / Print Invoice</button>
                        </div>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-blue-50 text-blue-950 font-sans flex overflow-hidden">
            
            {isMobileMenuOpen && (
                <div className="fixed inset-0 bg-blue-950/30 backdrop-blur-sm z-40 lg:hidden animate-in fade-in duration-300" onClick={() => setIsMobileMenuOpen(false)} />
            )}

            <aside className={`relative fixed inset-y-0 left-0 h-full flex flex-col border-r border-blue-100 bg-white z-50 shrink-0 shadow-[4px_0_24px_rgba(239,246,255,0.5)] transform transition-all duration-300 ease-in-out lg:static lg:translate-x-0 ${isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full'} ${isSidebarCollapsed ? 'w-72 lg:w-24' : 'w-72'}`}>
                
                <button onClick={() => setIsSidebarCollapsed(!isSidebarCollapsed)} className="hidden lg:flex absolute -right-3.5 top-8 w-7 h-7 bg-white border border-blue-100 rounded-full items-center justify-center text-slate-400 hover:text-blue-600 shadow-md z-50 transition-all hover:scale-110">
                    {isSidebarCollapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
                </button>

                <div className={`p-6 lg:p-8 flex items-center ${isSidebarCollapsed ? 'justify-center px-0' : 'justify-between'}`}>
                    <div className={`flex items-center gap-3 ${isSidebarCollapsed ? 'justify-center' : 'px-2'}`}>
                        <div className="w-8 h-8 bg-blue-600 rounded-xl flex items-center justify-center font-black text-white shadow-lg shadow-blue-500/30 shrink-0">TRC</div>
                        {!isSidebarCollapsed && (
                            <div className="whitespace-nowrap overflow-hidden">
                                <h1 className="text-sm font-black tracking-tight text-blue-950 uppercase">Memberssistant</h1>
                                <p className="text-[10px] text-blue-400 font-bold tracking-widest uppercase mt-0.5">Landlord Portal</p>
                            </div>
                        )}
                    </div>
                    <button onClick={() => setIsMobileMenuOpen(false)} className="lg:hidden p-2 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-all"><X size={20} /></button>
                </div>

                <nav className={`flex-1 ${isSidebarCollapsed ? 'px-3' : 'px-4'} space-y-1.5 overflow-y-auto custom-scrollbar pb-6`}>
                    <SidebarItem icon={LayoutDashboard} label="Overview" href="/landlord/dashboard" />
                    <SidebarItem icon={Bell} label="Notifications" href="/landlord/notifications" badgeCount={badges.notifications} />
                    <SidebarItem icon={Building2} label="Accommodations" href="/landlord/accommodations" />
                    <SidebarItem icon={SparkleIcon} label="Applications" href="/landlord/applications" badgeCount={badges.applications} />
                    
                    {!isSidebarCollapsed ? (
                        <div className="pt-4 pb-1 px-5"><p className="text-[9px] font-black text-slate-400 tracking-widest uppercase">Emergency & Medical</p></div>
                    ) : (<div className="pt-4 pb-1 w-full flex justify-center"><div className="w-4 h-[1px] bg-blue-100"></div></div>)}

                    <SidebarItem icon={HeartPulse} label="Medical Responders" href="/landlord/medical-responders" isCritical={true} />
                    <SidebarItem icon={Activity} label="Emergency Logs" href="/landlord/emergency-logs" isCritical={true} />
                    <SidebarItem icon={MapIcon} label="Res Map" href="/landlord/res-buildings-map" />
                    <SidebarItem icon={Users} label="Students" href="/landlord/students" />
                    <SidebarItem icon={UserCog} label="Attendants" href="/landlord/attendants" />
                    <SidebarItem icon={Fingerprint} label="Students Verification" href="/landlord/students-verification" />
                    <SidebarItem icon={Wrench} label="Maintenance" href="/landlord/maintenance" badgeCount={badges.maintenance} />
                    <SidebarItem icon={QrCode} label="Gate Passes" href="/landlord/gate-passes" />
                    <SidebarItem icon={ClipboardCheck} label="Exit Permits" href="/landlord/permits" badgeCount={badges.permits} />
                    <SidebarItem icon={CreditCard} label="Finance" href="/landlord/finance" /> 
                    <SidebarItem icon={MessageCircleIcon} label="Communication" href="/landlord/communication" />
                    <SidebarItem icon={User} label="My Profile" href="/landlord/profile" />
                </nav>

                <div className="p-4 border-t border-blue-50 bg-white">
                    <button onClick={handleLogout} className={`w-full flex items-center ${isSidebarCollapsed ? 'justify-center' : 'gap-3 px-4'} py-3 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-all text-xs font-bold`}>
                        <LogOut size={16} /> {!isSidebarCollapsed && <span>TERMINATE SESSION</span>}
                    </button>
                </div>
            </aside>

            <main className="flex-1 h-screen overflow-y-auto bg-white relative w-full min-w-0 transition-all duration-300">
                <header className="sticky top-0 z-30 flex justify-between items-center px-6 lg:px-8 py-4 lg:py-6 backdrop-blur-xl bg-white/80 border-b border-blue-100/50 supports-[backdrop-filter]:bg-white/60">
                    <div className="flex items-center gap-4">
                        <button onClick={() => setIsMobileMenuOpen(true)} className="lg:hidden p-2.5 bg-white border border-blue-100 rounded-xl text-blue-600 shadow-sm hover:bg-blue-50 transition-all"><Menu size={20} /></button>
                        <div>
                            <h2 className="text-xl lg:text-2xl font-black tracking-tight text-blue-950 capitalize truncate max-w-[150px] sm:max-w-xs">{getPageTitle()}</h2>
                            <p className="hidden sm:flex text-slate-400 text-[10px] font-bold uppercase tracking-[0.2em] mt-1 items-center gap-2">
                                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                                System Online: <span className="text-blue-600 truncate max-w-[120px]">{landlordName}</span>
                            </p>
                        </div>
                    </div>
                    
                    <div className="flex items-center gap-3 lg:gap-4">
                        <div className="hidden md:block relative group">
                            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300" size={16} />
                            <input type="text" placeholder="Global System Search..." className="bg-blue-50/50 border border-blue-100 pl-11 pr-4 py-2.5 rounded-xl outline-none w-64 lg:w-80 text-sm focus:bg-white focus:border-blue-400 transition-all placeholder-blue-300 font-medium shadow-inner shadow-blue-50/50" />
                        </div>
                        <button className="md:hidden p-2.5 bg-white border border-blue-100 rounded-xl text-blue-400 hover:text-blue-600 transition-all shadow-sm"><Search size={18} /></button>
                        <Link href="/landlord/notifications" className="relative p-2.5 bg-white border border-blue-100 rounded-xl text-blue-400 hover:text-blue-600 transition-all shadow-sm block">
                            <Bell size={18} />
                            {badges.notifications > 0 && <span className="absolute top-2 right-2.5 w-2.5 h-2.5 bg-rose-500 rounded-full border-2 border-white animate-pulse"></span>}
                        </Link>
                    </div>
                </header>
                <div className="p-4 sm:p-6 lg:p-10 max-w-7xl mx-auto">{children}</div>
            </main>
        </div>
    );
}