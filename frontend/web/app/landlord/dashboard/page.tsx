"use client";

import React, { useState, useEffect, useCallback } from 'react';
import { Loader2, Building2, Users, Wrench, UserCog } from 'lucide-react';
import { apiFetch } from '../../components/api';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend } from 'recharts';

export default function DashboardOverview() {
    const [initialLoading, setInitialLoading] = useState(true);
    const [stats, setStats] = useState({ blocksCount: 0, issuesCount: 0, studentsCount: 0, attendantsCount: 0 });
    const [issueStatusData, setIssueStatusData] = useState<any[]>([]);
    const [studentTrendData, setStudentTrendData] = useState<any[]>([]);

    // 1. Wrap data fetching in useCallback so it can be reused safely
    const fetchDashboardData = useCallback(async (isSilent = false) => {
        if (!isSilent) setInitialLoading(true);
        
        try {
            const [blocksRes, issuesRes, studentsRes, attendantsRes] = await Promise.all([
                apiFetch('/blocks/').catch(() => []),
                apiFetch('/issues/').catch(() => []),
                apiFetch('/students/').catch(() => []),
                apiFetch('/attendants/').catch(() => [])
            ]);

            const blocksList = blocksRes.results || blocksRes || [];
            const issuesList = issuesRes.results || issuesRes || [];
            const allStudentsList = studentsRes.results || studentsRes || [];
            const attendantsList = attendantsRes.results || attendantsRes || [];

            // STRICT FILTER: Only count students who are officially placed in a room
            const verifiedResidentsList = allStudentsList.filter((s: any) => s.room !== null);

            // Update Counts
            setStats({
                blocksCount: blocksList.length,
                issuesCount: issuesList.length,
                studentsCount: verifiedResidentsList.length, // Uses filtered list
                attendantsCount: attendantsList.length
            });

            // Process Pie Chart
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

            // Process Trend Data (Using ONLY verified residents)
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

    // 2. Setup the Polling Interval
    useEffect(() => {
        // Initial Fetch
        fetchDashboardData();

        // Background sync every 15 seconds
        const intervalId = setInterval(() => {
            fetchDashboardData(true); // Pass 'true' for silent update
        }, 15000); 

        // Cleanup: Stop the timer when the user leaves the page
        return () => clearInterval(intervalId);
    }, [fetchDashboardData]);

    if (initialLoading) {
        return (
            <div className="flex flex-col items-center justify-center py-40 animate-pulse">
                <Loader2 className="animate-spin text-indigo-500 mb-4" size={48} />
                <p className="text-slate-400 font-bold uppercase tracking-widest text-xs">Connecting to Live Feed...</p>
            </div>
        );
    }

    const activeIssuesCount = issueStatusData
        .filter(d => d.name === 'Open / Pending' || d.name === 'Attending')
        .reduce((sum, current) => sum + current.value, 0);

    return (
        <div className="space-y-10 animate-in fade-in slide-in-from-bottom-2 duration-700">
            {/* Stat Cards */}
            <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-4 gap-6">
                <StatCard title="Blocks Managed" value={stats.blocksCount} label="Active Properties" icon={Building2} accentColor="bg-indigo-500" accentBg="bg-indigo-50" iconColor="text-indigo-600" />
                <StatCard title="Total Students" value={stats.studentsCount} label="Active Directory" icon={Users} accentColor="bg-blue-500" accentBg="bg-blue-50" iconColor="text-blue-600" />
                <StatCard title="Staff Members" value={stats.attendantsCount} label="Attendants On Duty" icon={UserCog} accentColor="bg-emerald-500" accentBg="bg-emerald-50" iconColor="text-emerald-600" />
                <StatCard title="Active Issues" value={activeIssuesCount} label="Open & Attending" icon={Wrench} accentColor="bg-rose-500" accentBg="bg-rose-50" iconColor="text-rose-600" />
            </div>

            {/* Graphs */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <div className="lg:col-span-2 bg-white p-8 rounded-[32px] border border-slate-100 shadow-[0_8px_30px_rgb(0,0,0,0.04)]">
                    <SectionSubHeader title="Operational Trends" color="text-indigo-600" />
                    <h3 className="font-bold text-slate-900 text-lg tracking-tight mt-1">Resident Residency Trends (6 Months)</h3>
                    <div className="h-80 w-full mt-6">
                        <ResponsiveContainer width="100%" height="100%">
                            <AreaChart data={studentTrendData}>
                                <defs>
                                    <linearGradient id="colorResidents" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor="#6366f1" stopOpacity={0.2}/><stop offset="95%" stopColor="#6366f1" stopOpacity={0}/></linearGradient>
                                    <linearGradient id="colorNew" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor="#10b981" stopOpacity={0.2}/><stop offset="95%" stopColor="#10b981" stopOpacity={0}/></linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="3 3" stroke="#f8fafc" vertical={false} />
                                <XAxis dataKey="month" axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#94a3b8', fontWeight: '600' }} />
                                <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#94a3b8', fontWeight: '600' }} />
                                <Tooltip contentStyle={{ borderRadius: '16px', border: 'none', boxShadow: '0 10px 40px rgba(0,0,0,0.08)' }} />
                                <Area type="monotone" dataKey="residents" stroke="#6366f1" fill="url(#colorResidents)" strokeWidth={3} name="Total Residents" />
                                <Area type="monotone" dataKey="new_joins" stroke="#10b981" fill="url(#colorNew)" strokeWidth={3} name="New Registrations" />
                            </AreaChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                <div className="bg-white p-8 rounded-[32px] border border-slate-100 shadow-[0_8px_30px_rgb(0,0,0,0.04)] flex flex-col relative overflow-hidden">
                    <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-rose-400 via-indigo-400 to-emerald-400"></div>
                    <SectionSubHeader title="Ticketing Analytics" color="text-indigo-600" />
                    <h3 className="font-bold text-slate-900 text-lg tracking-tight mt-1">Issue Status</h3>
                    <div className="flex-1 w-full flex items-center justify-center relative min-h-[250px]">
                        <div className="absolute flex flex-col items-center justify-center">
                            <span className="text-5xl font-black text-slate-900 tracking-tighter">{stats.issuesCount}</span>
                            <span className="text-[9px] text-slate-400 uppercase tracking-[0.2em] font-black mt-1">Tickets</span>
                        </div>
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie data={issueStatusData} innerRadius={80} outerRadius={105} paddingAngle={6} dataKey="value" cornerRadius={12} stroke="none">
                                    {issueStatusData.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={entry.color} />
                                    ))}
                                </Pie>
                            </PieChart>
                        </ResponsiveContainer>
                    </div>
                    <div className="mt-6 flex flex-col gap-3 border-t border-slate-50 pt-6">
                        {issueStatusData.map(entry => entry.name !== 'No Issues' && (
                            <div key={entry.name} className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-100">
                                <div className="flex items-center gap-3">
                                    <div className="w-3 h-3 rounded-full" style={{ backgroundColor: entry.color }}></div>
                                    <span className="text-xs font-bold text-slate-700">{entry.name}</span>
                                </div>
                                <span className="text-sm font-black text-slate-900">{entry.value}</span>
                            </div>
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
}

// --- Helper Components ---
function StatCard({ title, value, label, accentColor, accentBg, iconColor, icon: Icon }: any) {
    return (
        <div className="relative p-6 bg-white border border-slate-100 rounded-[28px] shadow-[0_4px_20px_rgb(0,0,0,0.03)] flex flex-row items-center gap-5 overflow-hidden group">
            <div className={`absolute left-0 top-0 bottom-0 w-1.5 ${accentColor}`}></div>
            <div className={`ml-2 p-4 rounded-2xl ${accentBg} ${iconColor} border border-white/50 shadow-sm flex-shrink-0`}>
                <Icon size={28} strokeWidth={2.5} />
            </div>
            <div className="flex flex-col py-1">
                <p className="text-slate-400 text-[10px] font-black uppercase tracking-[0.15em] mb-1">{title}</p>
                <h3 className="text-3xl font-black text-slate-900 tracking-tighter leading-none mb-1.5">{value}</h3>
                <p className="text-slate-500 text-[11px] font-semibold">{label}</p>
            </div>
        </div>
    );
}

function SectionSubHeader({ title, color = "text-blue-600" }: { title: string, color?: string }) {
    return <h4 className={`text-[10px] font-black tracking-[0.25em] ${color} uppercase`}>{title}</h4>;
}