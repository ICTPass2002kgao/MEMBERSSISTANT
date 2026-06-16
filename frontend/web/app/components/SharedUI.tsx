"use client";
import React from 'react';
import { X, Loader2 } from 'lucide-react';

export function ModalWrapper({ title, onClose, children }: any) {
    return (
        // The backdrop is slightly softened (slate-900/40) but keeps focus on the modal
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
            {/* Modal Body: Crisp white with a soft blue shadow */}
            <div className="bg-white border border-blue-100 w-full max-w-md rounded-3xl overflow-hidden shadow-2xl shadow-blue-900/10 max-h-[90vh] flex flex-col">
                <div className="flex justify-between items-center p-6 border-b border-blue-50 shrink-0 bg-white">
                    <h3 className="font-black text-lg text-blue-950 uppercase tracking-tight">{title}</h3>
                    <button 
                        type="button" 
                        onClick={onClose} 
                        className="p-1.5 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-lg transition-colors"
                    >
                        <X size={20}/>
                    </button>
                </div>
                <div className="p-6 overflow-y-auto custom-scrollbar bg-white">
                    {children}
                </div>
            </div>
        </div>
    );
}

export function Input({ label, ...props }: any) {
    return (
        <div>
            <label className="text-[10px] font-bold text-blue-400 uppercase tracking-widest mb-1.5 block ml-1">
                {label}
            </label>
            <input 
                className="w-full bg-blue-50/50 border border-blue-100 rounded-xl px-4 py-3 text-sm text-blue-950 placeholder-blue-300 focus:bg-white focus:border-blue-400 focus:ring-4 focus:ring-blue-400/10 outline-none transition-all shadow-sm" 
                {...props} 
            />
        </div>
    );
}

export function Select({ label, children, ...props }: any) {
    return (
        <div>
            <label className="text-[10px] font-bold text-blue-400 uppercase tracking-widest mb-1.5 block ml-1">
                {label}
            </label>
            <select 
                className="w-full bg-blue-50/50 border border-blue-100 rounded-xl px-4 py-3 text-sm text-blue-950 focus:bg-white focus:border-blue-400 focus:ring-4 focus:ring-blue-400/10 outline-none transition-all shadow-sm appearance-none cursor-pointer" 
                {...props}
            >
                {children}
            </select>
        </div>
    );
}

export function SubmitButton({ loading, text, disabled }: { loading: boolean; text: string; disabled?: boolean }) {
    return (
        <button 
            type="submit" 
            disabled={loading || disabled} 
            className="w-full py-3.5 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl text-xs font-bold tracking-widest uppercase transition-all shadow-md shadow-blue-600/20 active:scale-[0.98]"
        >
            {loading ? <Loader2 className="animate-spin mx-auto" size={18} /> : text}
        </button>
    );
}

export function SectionHeader({ title }: { title: string }) {
    return (
        <h3 className="text-[10px] font-black tracking-[0.2em] text-blue-600 uppercase">
            {title}
        </h3>
    );
}

