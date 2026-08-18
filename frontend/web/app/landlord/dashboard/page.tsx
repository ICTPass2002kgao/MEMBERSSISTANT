"use client";

import React, { useState, useEffect, useCallback } from 'react';
import { Loader2, Building2, Users, Wrench, UserCog, Activity, AlertCircle, CheckCircle2, Clock, Siren, UserCheck, HeartPulse } from 'lucide-react';
import { apiFetch } from '../../components/api';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

export default function DashboardOverview() {
    const [initialLoading, setInitialLoading] = useState(true);
    const [stats, setStats] = useState({ blocksCount: 0, issuesCount: 0, studentsCount: 0, attendantsCount: 0, respondersCount: 0 });
    const [issueStatusData, setIssueStatusData] = useState<any[]>([]);
    const [studentTrendData, setStudentTrendData] = useState<any[]>([]);
    
    const [recentActivities, setRecentActivities] = useState<any[]>([]);
    const [recentEmergencies, setRecentEmergencies] = useState<any[]>([]);
    const [recentVisitors, setRecentVisitors] = useState<any[]>([]);

    const fetchDashboardData = useCallback(async (isSilent = false) => {
        if (!isSilent) setInitialLoading(true);
        
        try {
            // Updated visitors endpoint to /visitor-audit-logs/
            const [blocksRes, issuesRes, studentsRes, attendantsRes, emergenciesRes, visitorsRes, respondersRes] = await Promise.all([
                apiFetch('/blocks/').catch(() => []),
                apiFetch('/issues/').catch(() => []),
                apiFetch('/students/').catch(() => []),
                apiFetch('/attendants/').catch(() => []),
                apiFetch('/emergencies/').catch(() => []),
                apiFetch('/visitor-audit-logs/').catch(() => []),
                apiFetch('/medical-responders/').catch(() => []) 
            ]);

            const blocksList = blocksRes.results || blocksRes || [];
            const issuesList = issuesRes.results || issuesRes || [];
            const allStudentsList = studentsRes.results || studentsRes || [];
            const attendantsList = attendantsRes.results || attendantsRes || [];
            const emergenciesList = emergenciesRes.results || emergenciesRes || [];
            const visitorsList = visitorsRes.results || visitorsRes || [];
            const respondersList = respondersRes.results || respondersRes || [];

            const verifiedResidentsList = allStudentsList.filter((s: any) => s.room !== null);

            // Update Counts with respondersCount
            setStats({
                blocksCount: blocksList.length,
                issuesCount: issuesList.length,
                studentsCount: verifiedResidentsList.length, 
                attendantsCount: attendantsList.length,
                respondersCount: respondersList.length
            });

            // Process Pie Chart & Statuses
            let pending = 0, attending = 0, resolved = 0;
            issuesList.forEach((issue: any) => {
                if (issue.status === 'RESOLVED') resolved++;
                else if (issue.status === 'ATTENDING') attending++;
                else pending++;
            });

            const dynamicIssueData = [
                { name: 'Open / Pending', value: pending, color: '#f43f5e' },
                { name: 'Attending', value: attending, color: '#6366f1' },
                { name: 'Resolved', value: resolved, color: '#10b981' },
            ].filter(item => item.value > 0);

            if (dynamicIssueData.length === 0) {
                dynamicIssueData.push({ name: 'No Issues', value: 1, color: '#f8fafc' });
            }
            setIssueStatusData(dynamicIssueData);

            const sortedActivities = [...issuesList]
                .sort((a, b) => new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime())
                .slice(0, 4);
            setRecentActivities(sortedActivities);

            const sortedEmergencies = [...emergenciesList]
                .sort((a, b) => new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime())
                .slice(0, 4);
            setRecentEmergencies(sortedEmergencies);

            const sortedVisitors = [...visitorsList]
                .sort((a, b) => new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime())
                .slice(0, 4);
            setRecentVisitors(sortedVisitors);

            const trends = [];
            const today = new Date();
            for (let i = 5; i >= 0; i--) {
                const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
                const monthName = d.toLocaleString('default', { month: 'short' });
                const endOfMonth = new Date(today.getFullYear(), today.getMonth() - i + 1, 0);
                
                const residentsUntilMonth = verifiedResidentsList.filter((s: any) => 
                    !s.created_at || new Date(s.created_at) <= endOfMonth
                ).length;

                const newThisMonth = verifiedResidentsList.filter((s: any) => {
                    if (!s.created_at) return false;
                    const sDate = new Date(s.created_at);
                    return sDate.getFullYear() === d.getFullYear() && sDate.getMonth() === d.getMonth();
                }).length;

                trends.push({ month: monthName, residents: residentsUntilMonth, new_joins: newThisMonth });
            }
            setStudentTrendData(trends);

        } catch (err) {
            console.error("Failed to sync real-time data", err);
        } finally {
            setInitialLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchDashboardData();
        const intervalId = setInterval(() => {
            fetchDashboardData(true);
        }, 15000); 
        return () => clearInterval(intervalId);
    }, [fetchDashboardData]);

    if (initialLoading) {
        return (
            <div className="flex flex-col items-center justify-center min-h-[60vh] animate-pulse">
                <Loader2 className="animate-spin text-indigo-600 mb-6" size={54} strokeWidth={1.5} />
                <p className="text-slate-400 font-bold uppercase tracking-[0.3em] text-xs">Establishing Secure Connection...</p>
            </div>
        );
    }

    const activeIssuesCount = issueStatusData
        .filter(d => d.name === 'Open / Pending' || d.name === 'Attending')
        .reduce((sum, current) => sum + current.value, 0);

    return (
        <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-12">
            
         

            {/* Premium Stat Cards with uniquely distinct matching colors */}
            <div className="grid grid-cols-1 md:grid-cols-3 xl:grid-cols-5 gap-6">
                <StatCard title="Blocks Managed" value={stats.blocksCount} label="Active Properties" icon={Building2} accentColor="bg-indigo-500" accentBg="bg-indigo-50" iconColor="text-indigo-600" />
                <StatCard title="Total Students" value={stats.studentsCount} label="Active Directory" icon={Users} accentColor="bg-blue-500" accentBg="bg-blue-50" iconColor="text-blue-600" />
                <StatCard title="Staff Members" value={stats.attendantsCount} label="Attendants On Duty" icon={UserCog} accentColor="bg-emerald-500" accentBg="bg-emerald-50" iconColor="text-emerald-600" />
                <StatCard title="Active Issues" value={activeIssuesCount} label="Requires Attention" icon={Wrench} accentColor="bg-rose-500" accentBg="bg-rose-50" iconColor="text-rose-600" />
                <StatCard title="Medical Responders" value={stats.respondersCount} label="Active Dispatch" icon={HeartPulse} accentColor="bg-red-500" accentBg="bg-red-50" iconColor="text-red-600" />
            </div>

            {/* Main Analytical Grid */}
            <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
                
                {/* Chart Section */}
                <div className="xl:col-span-2 bg-white p-6 rounded-3xl border border-slate-200/60 shadow-[0_8px_40px_rgb(0,0,0,0.03)] transition-all hover:shadow-[0_8px_40px_rgb(0,0,0,0.06)] relative overflow-hidden">
                    <div className="flex justify-between items-end mb-6">
                        <div>
                            <SectionSubHeader title="Operational Trends" color="text-indigo-600" />
                            <h3 className="font-extrabold text-slate-900 text-lg tracking-tight mt-1">Residency Growth Analytics</h3>
                        </div>
                        <div className="px-4 py-1.5 rounded-full bg-slate-50 border border-slate-100 text-[10px] font-bold text-slate-500 tracking-wide">6 Months</div>
                    </div>
                    
                    <div className="h-[220px] w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <AreaChart data={studentTrendData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                                <defs>
                                    <linearGradient id="colorResidents" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor="#4f46e5" stopOpacity={0.15}/><stop offset="95%" stopColor="#4f46e5" stopOpacity={0}/></linearGradient>
                                    <linearGradient id="colorNew" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor="#10b981" stopOpacity={0.15}/><stop offset="95%" stopColor="#10b981" stopOpacity={0}/></linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="4 4" stroke="#f1f5f9" vertical={false} />
                                <XAxis dataKey="month" axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#64748b', fontWeight: '500' }} dy={10} />
                                <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#64748b', fontWeight: '500' }} />
                                <Tooltip cursor={{ stroke: '#e2e8f0', strokeWidth: 2, strokeDasharray: '4 4' }} contentStyle={{ borderRadius: '12px', border: '1px solid #f1f5f9', boxShadow: '0 20px 40px rgba(0,0,0,0.08)', padding: '10px 14px', fontWeight: '600', fontSize: '12px', backgroundColor: '#ffffff', color: '#0f172a' }} />
                                <Area type="monotone" dataKey="residents" stroke="#4f46e5" fill="url(#colorResidents)" strokeWidth={3} name="Total Residents" activeDot={{ r: 5, strokeWidth: 0, fill: '#4f46e5' }} />
                                <Area type="monotone" dataKey="new_joins" stroke="#10b981" fill="url(#colorNew)" strokeWidth={3} name="New Registrations" activeDot={{ r: 5, strokeWidth: 0, fill: '#10b981' }} />
                            </AreaChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                {/* Status & Ticketing Analytics */}
                <div className="bg-white p-6 rounded-3xl border border-slate-200/60 shadow-[0_8px_40px_rgb(0,0,0,0.03)] flex flex-col relative overflow-hidden transition-all hover:shadow-[0_8px_40px_rgb(0,0,0,0.06)]">
                    <div className="absolute top-0 left-0 w-full h-1.5 bg-gradient-to-r from-rose-500 via-indigo-500 to-emerald-500"></div>
                    <div>
                        <SectionSubHeader title="Ticketing Analytics" color="text-indigo-600" />
                        <h3 className="font-extrabold text-slate-900 text-lg tracking-tight mt-1">Issue Resolution</h3>
                    </div>
                    
                    <div className="flex-1 w-full flex items-center justify-center relative min-h-[160px] mt-4">
                        <div className="absolute flex flex-col items-center justify-center">
                            <span className="text-4xl font-black text-slate-900 tracking-tighter">{stats.issuesCount}</span>
                            <span className="text-[9px] text-slate-400 uppercase tracking-[0.2em] font-bold mt-1">Total Tickets</span>
                        </div>
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie data={issueStatusData} innerRadius={60} outerRadius={80} paddingAngle={8} dataKey="value" cornerRadius={12} stroke="none">
                                    {issueStatusData.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={entry.color} />
                                    ))}
                                </Pie>
                            </PieChart>
                        </ResponsiveContainer>
                    </div>
                    
                    <div className="mt-6 flex flex-col gap-2.5">
                        {issueStatusData.map(entry => entry.name !== 'No Issues' && (
                            <div key={entry.name} className="flex items-center justify-between p-3 rounded-xl bg-slate-50/80 border border-slate-100 transition-colors hover:bg-slate-100/80">
                                <div className="flex items-center gap-2.5">
                                    <div className="w-3 h-3 rounded-full shadow-sm" style={{ backgroundColor: entry.color }}></div>
                                    <span className="text-xs font-bold text-slate-700">{entry.name}</span>
                                </div>
                                <span className="text-sm font-black text-slate-900">{entry.value}</span>
                            </div>
                        ))}
                    </div>
                </div>
            </div>

            {/* Segmented Small Cards Section (3 Columns) */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                
                {/* Recent Emergencies */}
                <div className="bg-white rounded-3xl border border-slate-200/60 shadow-[0_8px_40px_rgb(0,0,0,0.02)] overflow-hidden flex flex-col">
                    <div className="p-6 border-b border-slate-100 flex items-center gap-3">
                        <div className="p-2 bg-red-50 text-red-600 rounded-lg">
                            <Siren size={18} strokeWidth={2.5} />
                        </div>
                        <h3 className="font-bold text-slate-900 text-sm tracking-tight">Recent Emergencies</h3>
                    </div>
                    <div className="flex-1 p-2">
                        {recentEmergencies.length > 0 ? (
                            recentEmergencies.map((emergency, idx) => (
                                <div key={idx} className="p-4 hover:bg-slate-50/50 rounded-xl transition-colors flex items-center justify-between gap-3">
                                    <div className="flex items-center gap-3 overflow-hidden">
                                        <div className="w-2 h-2 rounded-full bg-red-500 flex-shrink-0"></div>
                                        <div className="truncate">
                                            <p className="text-sm font-semibold text-slate-800 truncate">{emergency.type || emergency.title || 'Emergency Alert'}</p>
                                            <p className="text-xs text-slate-500 font-medium truncate">{emergency.description || 'Action required.'}</p>
                                        </div>
                                    </div>
                                    <span className="text-[10px] font-bold text-slate-400 bg-slate-100 px-2 py-1 rounded-md flex-shrink-0">
                                        {formatTimeAgo(emergency.created_at)}
                                    </span>
                                </div>
                            ))
                        ) : (
                            <EmptyState icon={Siren} message="No recent emergencies" />
                        )}
                    </div>
                    <div className="p-4 border-t border-slate-100 text-center">
                        <button className="text-xs font-bold text-indigo-600 hover:text-indigo-700 transition-colors">View all alerts &rarr;</button>
                    </div>
                </div>

                {/* Ticket Updates */}
                <div className="bg-white rounded-3xl border border-slate-200/60 shadow-[0_8px_40px_rgb(0,0,0,0.02)] overflow-hidden flex flex-col">
                    <div className="p-6 border-b border-slate-100 flex items-center gap-3">
                        <div className="p-2 bg-indigo-50 text-indigo-600 rounded-lg">
                            <Activity size={18} strokeWidth={2.5} />
                        </div>
                        <h3 className="font-bold text-slate-900 text-sm tracking-tight">Ticket Updates</h3>
                    </div>
                    <div className="flex-1 p-2">
                        {recentActivities.length > 0 ? (
                            recentActivities.map((activity, idx) => {
                                const isResolved = activity.status === 'RESOLVED';
                                const isAttending = activity.status === 'ATTENDING';
                                
                                return (
                                    <div key={idx} className="p-4 hover:bg-slate-50/50 rounded-xl transition-colors flex items-center justify-between gap-3">
                                        <div className="flex items-center gap-3 overflow-hidden">
                                            <div className={`p-1.5 rounded-full border ${isResolved ? 'bg-emerald-50 border-emerald-100 text-emerald-600' : isAttending ? 'bg-indigo-50 border-indigo-100 text-indigo-600' : 'bg-rose-50 border-rose-100 text-rose-600'}`}>
                                                {isResolved ? <CheckCircle2 size={14} /> : isAttending ? <Clock size={14} /> : <AlertCircle size={14} />}
                                            </div>
                                            <div className="truncate">
                                                <p className="text-sm font-semibold text-slate-800 truncate">{activity.title || 'Maintenance Request'}</p>
                                                <p className="text-xs text-slate-500 font-medium truncate">{activity.status || 'PENDING'}</p>
                                            </div>
                                        </div>
                                        <span className="text-[10px] font-bold text-slate-400 bg-slate-100 px-2 py-1 rounded-md flex-shrink-0">
                                            {formatTimeAgo(activity.created_at)}
                                        </span>
                                    </div>
                                );
                            })
                        ) : (
                            <EmptyState icon={Activity} message="No recent tickets" />
                        )}
                    </div>
                    <div className="p-4 border-t border-slate-100 text-center">
                        <button className="text-xs font-bold text-indigo-600 hover:text-indigo-700 transition-colors">View all activity &rarr;</button>
                    </div>
                </div>

                {/* Recent Visitors */}
                <div className="bg-white rounded-3xl border border-slate-200/60 shadow-[0_8px_40px_rgb(0,0,0,0.02)] overflow-hidden flex flex-col">
                    <div className="p-6 border-b border-slate-100 flex items-center gap-3">
                        <div className="p-2 bg-emerald-50 text-emerald-600 rounded-lg">
                            <UserCheck size={18} strokeWidth={2.5} />
                        </div>
                        <h3 className="font-bold text-slate-900 text-sm tracking-tight">Visitor Log</h3>
                    </div>
                    <div className="flex-1 p-2">
                        {recentVisitors.length > 0 ? (
                            recentVisitors.map((visitor, idx) => (
                                <div key={idx} className="p-4 hover:bg-slate-50/50 rounded-xl transition-colors flex items-center justify-between gap-3">
                                    <div className="flex items-center gap-3 overflow-hidden">
                                        <div className="w-8 h-8 rounded-full bg-slate-100 border border-slate-200 flex items-center justify-center flex-shrink-0">
                                            <span className="text-xs font-bold text-slate-500">{(visitor.name || 'V')[0].toUpperCase()}</span>
                                        </div>
                                        <div className="truncate">
                                            <p className="text-sm font-semibold text-slate-800 truncate">{visitor.name || 'Unknown Visitor'}</p>
                                            <p className="text-xs text-slate-500 font-medium truncate">Checked In</p>
                                        </div>
                                    </div>
                                    <span className="text-[10px] font-bold text-slate-400 bg-slate-100 px-2 py-1 rounded-md flex-shrink-0">
                                        {formatTimeAgo(visitor.created_at)}
                                    </span>
                                </div>
                            ))
                        ) : (
                            <EmptyState icon={UserCheck} message="No recent visitors" />
                        )}
                    </div>
                    <div className="p-4 border-t border-slate-100 text-center">
                        <button className="text-xs font-bold text-indigo-600 hover:text-indigo-700 transition-colors">View all logs &rarr;</button>
                    </div>
                </div>

            </div>

        </div>
    );
}

// --- Helper Components ---
function StatCard({ title, value, label, accentColor, accentBg, iconColor, icon: Icon }: any) {
    return (
        <div className="relative p-6 bg-white border border-slate-200/60 rounded-[24px] shadow-[0_8px_30px_rgb(0,0,0,0.02)] transition-all hover:shadow-[0_8px_30px_rgb(0,0,0,0.06)] hover:-translate-y-1 group overflow-hidden flex flex-col justify-between min-h-[160px]">
            {/* Top Border Accent */}
            <div className={`absolute left-0 top-0 w-full h-1 opacity-0 group-hover:opacity-100 transition-opacity ${accentColor}`}></div>
            
            {/* Top Row: Icon & Live Badge */}
            <div className="flex justify-between items-start mb-4">
                <div className={`p-2.5 rounded-xl ${accentBg} ${iconColor} shadow-sm ring-1 ring-white/60`}>
                    <Icon size={20} strokeWidth={2.5} />
                </div>
                <div className="flex items-center gap-1 bg-slate-50 px-2 py-0.5 rounded-md border border-slate-100">
                    {/* Dot matching the exact icon/accent color dynamically */}
                    <span className={`w-1.5 h-1.5 rounded-full animate-pulse ${accentColor}`}></span>
                    <span className="text-[9px] font-bold text-slate-500 uppercase tracking-wider">Live</span>
                </div>
            </div>
            
            {/* Bottom Row: Text on Left, Number on Right */}
            <div className="flex justify-between items-end mt-auto pt-2">
                <div className="flex flex-col">
                    <p className="text-slate-800 text-sm font-bold">{title}</p>
                    <p className="text-slate-400 text-xs font-medium">{label}</p>
                </div>
                <h3 className="text-5xl font-black text-slate-900 tracking-tighter leading-none">
                    {value}
                </h3>
            </div>
        </div>
    );
}

function SectionSubHeader({ title, color = "text-blue-600" }: { title: string, color?: string }) {
    return <h4 className={`text-[10px] font-black tracking-[0.25em] ${color} uppercase`}>{title}</h4>;
}

function EmptyState({ icon: Icon, message }: { icon: any, message: string }) {
    return (
        <div className="py-10 flex flex-col items-center justify-center">
            <div className="p-3 bg-slate-50 rounded-full mb-2 text-slate-300">
                <Icon size={24} />
            </div>
            <p className="text-xs font-bold text-slate-400">{message}</p>
        </div>
    );
}

function formatTimeAgo(dateString: string) {
    if (!dateString) return 'Just now';
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 60) return `${Math.max(1, diffMins)}m ago`;
    
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    
    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays}d ago`;
}