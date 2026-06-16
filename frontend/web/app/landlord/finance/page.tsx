"use client";

import React, { useState, useEffect } from 'react';
import { Loader2, CreditCard, Receipt, TrendingUp, CheckCircle2 } from 'lucide-react';
import { apiFetch } from '../../components/api'; 
import { SectionHeader } from '../../components/SharedUI';

export default function FinancePage() {
    const [charges, setCharges] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [stats, setStats] = useState({ totalRevenue: 0, pendingBalance: 0 });

    const fetchCharges = async () => {
        setLoading(true);
        try {
            const data = await apiFetch('/charges/');
            const chargeList = data.results || data || [];
             
            chargeList.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
            
            setCharges(chargeList);
 
            let revenue = 0;
            let pending = 0;
            chargeList.forEach((c: any) => {
                if (c.is_paid) revenue += parseFloat(c.amount);
                else pending += parseFloat(c.amount);
            });
            setStats({ totalRevenue: revenue, pendingBalance: pending });

        } catch (error) { 
            console.error(error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { 
        fetchCharges(); 
    }, []);

    const markAsPaid = async (id: string, issueId: string | null) => {
        try { 
            await apiFetch(`/charges/${id}/`, { 
                method: 'PATCH', 
                body: JSON.stringify({ is_paid: true }) 
            }); 
            if (issueId) {
                await apiFetch(`/issues/${issueId}/`, {
                    method: 'PATCH',
                    body: JSON.stringify({ status: 'READY_FOR_COLLECTION' })
                });
            }

            fetchCharges(); 
        } catch (error) { 
            console.error("Failed to process payment"); 
        }
    };

    return (
        <div className="space-y-8 animate-in fade-in slide-in-from-bottom-2 duration-500">
            
            {/* Premium Financial Overview Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                
                {/* Revenue Card */}
                <div className="relative p-8 bg-white border border-slate-100 rounded-[28px] shadow-[0_4px_20px_rgb(0,0,0,0.03)] hover:shadow-[0_8px_30px_rgb(0,0,0,0.06)] transition-all duration-300 flex items-center justify-between overflow-hidden group">
                    <div className="absolute left-0 top-0 bottom-0 w-1.5 bg-emerald-500 transition-all duration-300 group-hover:w-2"></div>
                    <div className="pl-3">
                        <p className="text-slate-400 text-[10px] font-black uppercase tracking-[0.2em] mb-2">Total Collected (ZAR)</p>
                        <h3 className="text-4xl font-black tracking-tighter text-emerald-600 leading-none">R {stats.totalRevenue.toFixed(2)}</h3>
                    </div>
                    <div className="p-4 bg-emerald-50 border border-emerald-100 rounded-2xl shadow-sm transition-transform duration-300 group-hover:scale-105">
                        <TrendingUp size={32} className="text-emerald-600" strokeWidth={2.5} />
                    </div>
                </div>
                
                {/* Outstanding Balances Card */}
                <div className="relative p-8 bg-white border border-slate-100 rounded-[28px] shadow-[0_4px_20px_rgb(0,0,0,0.03)] hover:shadow-[0_8px_30px_rgb(0,0,0,0.06)] transition-all duration-300 flex items-center justify-between overflow-hidden group">
                    <div className="absolute left-0 top-0 bottom-0 w-1.5 bg-rose-500 transition-all duration-300 group-hover:w-2"></div>
                    <div className="pl-3">
                        <p className="text-slate-400 text-[10px] font-black uppercase tracking-[0.2em] mb-2">Outstanding Balances</p>
                        <h3 className="text-4xl font-black tracking-tighter text-rose-600 leading-none">R {stats.pendingBalance.toFixed(2)}</h3>
                    </div>
                    <div className="p-4 bg-rose-50 border border-rose-100 rounded-2xl shadow-sm transition-transform duration-300 group-hover:scale-105">
                        <Receipt size={32} className="text-rose-600" strokeWidth={2.5} />
                    </div>
                </div>

            </div>

            {/* Ledger Table */}
            <div className="space-y-4">
                <SectionHeader title="Financial Ledger" />
                
                <div className="bg-white border border-blue-100 rounded-[24px] overflow-hidden shadow-sm">
                    <table className="w-full text-left">
                        <thead className="bg-blue-50/50 border-b border-blue-100">
                            <tr className="text-slate-500 text-[10px] uppercase tracking-widest">
                                <th className="py-5 px-6 font-bold w-1/3">Resident & Location</th>
                                <th className="py-5 px-6 font-bold">Charge Description</th>
                                <th className="py-5 px-4 font-bold">Amount</th>
                                <th className="py-5 px-4 font-bold">Status</th>
                                <th className="py-5 px-6 text-right font-bold">Action</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {loading && (
                                <tr>
                                    <td colSpan={5} className="py-12 text-center">
                                        <Loader2 className="animate-spin mx-auto text-blue-500" />
                                    </td>
                                </tr>
                            )}
                            {!loading && charges.length === 0 && (
                                <tr>
                                    <td colSpan={5} className="py-16 text-center text-slate-500 text-xs italic">
                                        No financial records found.
                                    </td>
                                </tr>
                            )}
                            {!loading && charges.map((charge: any) => (
                                <tr key={charge.id} className="hover:bg-blue-50/30 transition-colors">
                                    
                                    {/* Resident & Location */}
                                    <td className="py-5 px-6 align-top">
                                        <p className="text-sm font-black text-blue-950">
                                            {charge.student_name} {charge.student_surname}
                                        </p>
                                        <p className="text-[10px] font-bold text-slate-500 mt-1">
                                            ID: {charge.student_number}
                                        </p>
                                        <div className="flex flex-wrap gap-1.5 mt-2">
                                            <span className="px-2 py-1 bg-slate-100 text-slate-600 text-[9px] rounded font-bold uppercase tracking-wider border border-slate-200">
                                                {charge.block_name || 'No Block'}
                                            </span>
                                            <span className="px-2 py-1 bg-blue-50 text-blue-600 text-[9px] rounded font-bold uppercase tracking-wider border border-blue-100">
                                                Room {charge.room_number || 'N/A'}
                                            </span>
                                        </div>
                                    </td>

                                    {/* Charge Description */}
                                    <td className="py-5 px-6 align-top">
                                        <p className="text-sm font-bold text-blue-950">{charge.description}</p>
                                        <p className="text-[9px] text-slate-400 font-bold uppercase tracking-widest mt-2">
                                            Ref: {charge.paystack_reference || charge.id.split('-')[0]}
                                        </p>
                                        <p className="text-[9px] text-slate-400 font-bold tracking-widest uppercase mt-1">
                                            Date: {new Date(charge.created_at).toLocaleDateString()}
                                        </p>
                                    </td>

                                    {/* Amount */}
                                    <td className="py-5 px-4 text-sm font-mono font-bold text-slate-700 align-top">
                                        R {parseFloat(charge.amount).toFixed(2)}
                                    </td>

                                    {/* Status */}
                                    <td className="py-5 px-4 align-top">
                                        <span className={`flex w-fit items-center gap-1.5 text-[10px] font-black tracking-widest px-2.5 py-1.5 rounded-md border shadow-sm ${
                                            charge.is_paid 
                                                ? 'bg-emerald-50 text-emerald-600 border-emerald-200' 
                                                : 'bg-rose-50 text-rose-600 border-rose-200'
                                        }`}>
                                            {charge.is_paid ? <CheckCircle2 size={12}/> : <Receipt size={12}/>}
                                            {charge.is_paid ? 'PAID' : 'PENDING'}
                                        </span>
                                    </td>

                                    {/* Action */}
                                    <td className="py-5 px-6 text-right align-top">
                                        {!charge.is_paid ? (
                                            <div className="flex flex-col items-end gap-2">
                                                <button 
                                                    onClick={() => markAsPaid(charge.id, charge.issue)} 
                                                    className="text-[10px] font-bold tracking-widest text-blue-600 bg-blue-50 border border-blue-100 hover:bg-blue-100 hover:border-blue-200 hover:text-blue-800 transition-all px-4 py-2 rounded-lg shadow-sm flex items-center justify-center gap-1.5 w-full max-w-[120px]"
                                                >
                                                    <CreditCard size={14} /> MANUAL PAY
                                                </button>
                                                <p className="text-[9px] text-slate-400 font-medium max-w-[120px] text-center">
                                                    If student paid in cash
                                                </p>
                                            </div>
                                        ) : (
                                            <span className="text-[10px] font-bold tracking-widest text-emerald-500 py-1.5 px-3 block">
                                                SETTLED
                                            </span>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}