"use client";

import React, { useState, useEffect } from 'react';
import { Loader2, Building2, Users, Wrench, ShieldAlert, CheckCircle2, Ban } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, ResponsiveContainer, PieChart, Pie, Cell, BarChart, Bar } from 'recharts';

// Added custom API and SharedUI imports
import { apiFetch } from '../components/api';
import { SectionHeader } from '../components/SharedUI';

export default function SystemAdminDashboard() {
    const [loading, setLoading] = useState(true);
    
    const [stats, setStats] = useState({ 
        totalLandlords: 0, 
        totalStudents: 0,
        totalProperties: 0, 
        activeIssues: 0 
    });
    
    const [landlordStatusData, setLandlordStatusData] = useState<any[]>([]);
    const [userDemographics, setUserDemographics] = useState<any[]>([]);
    const [recentLandlords, setRecentLandlords] = useState<any[]>([]);

    useEffect(() => {
        const fetchSystemData = async () => {
            try {
                // Utilizing apiFetch and catching individual failures
                const [landlordsRes, studentsRes, propertiesRes, issuesRes, staffRes] = await Promise.all([
                    apiFetch('/landlords/').catch(() => []),
                    apiFetch('/students/').catch(() => []),
                    apiFetch('/accommodations/').catch(() => []),
                    apiFetch('/issues/').catch(() => []),
                    apiFetch('/attendants/').catch(() => []),
                ]);

                // Handle Django REST Framework pagination (.results)
                const landlordsList = landlordsRes.results || landlordsRes || [];
                const studentsList = studentsRes.results || studentsRes || [];
                const propertiesList = propertiesRes.results || propertiesRes || [];
                const issuesList = issuesRes.results || issuesRes || [];
                const staffList = staffRes.results || staffRes || [];

                // 1. Process Base Stats
                const pendingIssues = issuesList.filter((i: any) => i.status !== 'RESOLVED').length;
                
                setStats({
                    totalLandlords: landlordsList.length,
                    totalStudents: studentsList.length,
                    totalProperties: propertiesList.length,
                    activeIssues: pendingIssues
                });

                // Get latest 5 landlords for the quick roster
                setRecentLandlords(landlordsList.slice(0, 5));

                // 2. Process Landlord Verification Status
                let approved = 0, manualReview = 0, unverified = 0;
                landlordsList.forEach((l: any) => {
                    if (l.is_verified) approved++;
                    else if (l.manual_verification_status) manualReview++;
                    else unverified++;
                });

                setLandlordStatusData([
                    { name: 'Verified', value: approved, color: '#10b981' }, // Emerald
                    { name: 'Manual Review', value: manualReview, color: '#f59e0b' }, // Amber
                    { name: 'Unverified', value: unverified, color: '#94a3b8' }, // Slate
                ].filter(item => item.value > 0));

                // 3. User Demographics
                setUserDemographics([
                    { name: 'Students', count: studentsList.length, fill: '#3b82f6' },
                    { name: 'Landlords', count: landlordsList.length, fill: '#0f172a' },
                    { name: 'Staff', count: staffList.length, fill: '#8b5cf6' },
                ]);

            } catch (err) {
                console.error("System Dashboard Load Error", err);
            } finally {
                setLoading(false);
            }
        };
        fetchSystemData();
    }, []);

    if (loading) return <div className="flex justify-center py-32"><Loader2 className="animate-spin text-blue-500" size={48} /></div>;

    return (
        <div className="space-y-6 animate-in slide-in-from-right-4 duration-300">
            
            <div className="flex justify-between items-center mb-2">
                <SectionHeader title="System Overview" />
            </div>

            {/* Top Row Stat Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
                <StatCard 
                    title="Total Landlords" value={stats.totalLandlords} label="Registered Entities" 
                    icon={ShieldAlert} accentColor="bg-slate-800" accentBg="bg-slate-100" iconColor="text-slate-800"
                />
                <StatCard 
                    title="Total Students" value={stats.totalStudents} label="Platform Residents" 
                    icon={Users} accentColor="bg-blue-500" accentBg="bg-blue-50" iconColor="text-blue-600"
                />
                <StatCard 
                    title="Global Inventory" value={stats.totalProperties} label="Managed Estates" 
                    icon={Building2} accentColor="bg-indigo-500" accentBg="bg-indigo-50" iconColor="text-indigo-600"
                />
                <StatCard 
                    title="Active Tickets" value={stats.activeIssues} label="Pending Maintenance" 
                    icon={Wrench} accentColor="bg-rose-500" accentBg="bg-rose-50" iconColor="text-rose-600"
                />
            </div>

            {/* Data Visualization Section */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                
                {/* User Demographics Bar Chart */}
                <div className="lg:col-span-2 bg-white p-8 rounded-[32px] border border-blue-50 shadow-sm hover:shadow-md transition-all">
                    <div className="mb-8">
                        <span className="text-[10px] font-black tracking-[0.2em] text-slate-400 uppercase">Demographics</span>
                        <h3 className="font-black text-blue-950 text-xl tracking-tight mt-1">Platform User Distribution</h3>
                    </div>
                    <div className="h-72 w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={userDemographics} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                                <CartesianGrid strokeDasharray="3 3" stroke="#f8fafc" vertical={false} />
                                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#94a3b8', fontWeight: 'bold' }} dy={10} />
                                <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#94a3b8', fontWeight: 'bold' }} />
                                <RechartsTooltip cursor={{fill: '#f8fafc'}} contentStyle={{ borderRadius: '12px', border: '1px solid #eff6ff', boxShadow: '0 4px 20px rgba(0,0,0,0.05)' }} />
                                <Bar dataKey="count" radius={[8, 8, 0, 0]} barSize={60} />
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                {/* Landlord Security Status (Pie) */}
                <div className="bg-white p-8 rounded-[32px] border border-blue-50 shadow-sm hover:shadow-md transition-all flex flex-col relative overflow-hidden">
                    <div className="mb-6">
                        <span className="text-[10px] font-black tracking-[0.2em] text-slate-400 uppercase">System Integrity</span>
                        <h3 className="font-black text-blue-950 text-xl tracking-tight mt-1">Verification Status</h3>
                    </div>
                    <div className="flex-1 w-full flex items-center justify-center min-h-[220px] relative">
                        <div className="absolute flex flex-col items-center">
                            <span className="text-4xl font-black text-blue-950">{stats.totalLandlords}</span>
                            <span className="text-[9px] text-slate-400 uppercase font-black tracking-widest">Landlords</span>
                        </div>
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie 
                                    data={landlordStatusData} innerRadius={70} outerRadius={95} paddingAngle={5} 
                                    dataKey="value" stroke="none"
                                >
                                    {landlordStatusData.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={entry.color} />
                                    ))}
                                </Pie>
                                <RechartsTooltip contentStyle={{ borderRadius: '12px', border: '1px solid #eff6ff', boxShadow: '0 4px 20px rgba(0,0,0,0.05)' }} />
                            </PieChart>
                        </ResponsiveContainer>
                    </div>
                    
                    <div className="mt-4 space-y-2">
                        {landlordStatusData.length === 0 ? <p className="text-xs text-center text-slate-400">No data available.</p> : 
                        landlordStatusData.map(entry => (
                            <div key={entry.name} className="flex items-center justify-between p-3 rounded-xl bg-slate-50 border border-slate-100">
                                <div className="flex items-center gap-3">
                                    <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: entry.color }}></div>
                                    <span className="text-[11px] font-black text-slate-700 uppercase tracking-wider">{entry.name}</span>
                                </div>
                                <span className="text-sm font-black text-blue-950">{entry.value}</span>
                            </div>
                        ))}
                    </div>
                </div>
            </div>

            {/* Quick Landlord Roster */}
            <div className="bg-white rounded-[32px] border border-blue-50 shadow-sm overflow-hidden hover:shadow-md transition-all">
                <div className="p-8 border-b border-blue-50 flex items-center justify-between">
                    <div>
                        <span className="text-[10px] font-black tracking-[0.2em] text-slate-400 uppercase">Directory</span>
                        <h3 className="font-black text-blue-950 text-xl tracking-tight mt-1">Recent Landlords</h3>
                    </div>
                </div>
                <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse">
                        <thead>
                            <tr className="bg-slate-50/50">
                                <th className="px-8 py-4 text-[10px] font-black tracking-widest text-slate-400 uppercase border-b border-blue-50">Profile</th>
                                <th className="px-8 py-4 text-[10px] font-black tracking-widest text-slate-400 uppercase border-b border-blue-50">Contact</th>
                                <th className="px-8 py-4 text-[10px] font-black tracking-widest text-slate-400 uppercase border-b border-blue-50">Status</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-blue-50/50">
                            {recentLandlords.length === 0 ? (
                                <tr>
                                    <td colSpan={3} className="px-8 py-8 text-center text-slate-400 text-sm font-medium">No landlords found.</td>
                                </tr>
                            ) : (
                                recentLandlords.map((landlord: any) => (
                                    <tr key={landlord.id} className="hover:bg-blue-50/30 transition-colors">
                                        <td className="px-8 py-4">
                                            <div className="flex items-center gap-3">
                                                <div className="w-8 h-8 rounded-xl bg-blue-100 flex items-center justify-center text-blue-600 font-black shadow-sm">
                                                    {landlord.name ? landlord.name.charAt(0) : 'L'}
                                                </div>
                                                <div>
                                                    <p className="text-sm font-bold text-blue-950">{landlord.name || 'Pending'} {landlord.surname || ''}</p>
                                                    <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wider mt-0.5">UID: {landlord.firebase_uid?.slice(0, 8)}</p>
                                                </div>
                                            </div>
                                        </td>
                                        <td className="px-8 py-4">
                                            <p className="text-xs text-slate-500 font-medium">{landlord.email || 'N/A'}</p>
                                        </td>
                                        <td className="px-8 py-4">
                                            {landlord.is_verified ? (
                                                <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-emerald-50 text-emerald-600 text-[10px] font-bold border border-emerald-100 uppercase tracking-wider shadow-sm">
                                                    <CheckCircle2 size={12} /> Verified
                                                </span>
                                            ) : landlord.manual_verification_status ? (
                                                <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-amber-50 text-amber-600 text-[10px] font-bold border border-amber-100 uppercase tracking-wider shadow-sm">
                                                    <ShieldAlert size={12} /> Under Review
                                                </span>
                                            ) : (
                                                <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-50 text-slate-500 text-[10px] font-bold border border-slate-200 uppercase tracking-wider shadow-sm">
                                                    <Ban size={12} /> Unverified
                                                </span>
                                            )}
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}

function StatCard({ title, value, label, accentColor, accentBg, iconColor, icon: Icon }: any) {
    return (
        <div className="relative p-6 bg-white border border-blue-50 rounded-[28px] shadow-sm hover:shadow-md transition-all duration-300 flex flex-row items-center gap-5 overflow-hidden group">
            <div className={`absolute left-0 top-0 bottom-0 w-1.5 ${accentColor} transition-all duration-300 group-hover:w-2.5`}></div>
            <div className={`ml-2 p-4 rounded-2xl ${accentBg} ${iconColor} flex-shrink-0 shadow-sm`}>
                <Icon size={24} strokeWidth={2.5} />
            </div>
            <div className="flex flex-col">
                <p className="text-slate-400 text-[9px] font-black uppercase tracking-[0.2em] mb-1">{title}</p>
                <h3 className="text-3xl font-black text-blue-950 tracking-tighter leading-none mb-1.5">{value}</h3>
                <p className="text-slate-500 text-[10px] font-bold">{label}</p>
            </div>
        </div>
    );
}