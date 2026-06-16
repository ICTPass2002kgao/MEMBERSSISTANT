"use client";

import React, { useState, useEffect, FormEvent } from 'react';
import { 
    Loader2, Search, CheckCircle2, ShieldAlert, Ban, 
    Fingerprint, FileText, X, Download, Send, CheckCircle, XCircle, AlertTriangle, Filter, BadgeAlert
} from 'lucide-react';

import { apiFetch } from '../../components/api';

interface Landlord {
    id: string;
    name?: string;
    surname?: string;
    email?: string;
    phone?: string;
    is_verified?: boolean;
    manual_verification_status?: boolean;
    id_document_url?: string;
    contract_url?: string;
    face_url?: string;
    firebase_uid?: string;
}

interface PreviewModalState {
    isOpen: boolean;
    title: string;
    url: string;
    mimeType: string;
}

interface RejectModalState {
    isOpen: boolean;
    landlordId: string | null;
    landlordName: string;
}

interface AlertModalState {
    isOpen: boolean;
    title: string;
    message: string;
}

type FilterStatus = 'ALL' | 'VERIFIED' | 'REVIEW' | 'UNVERIFIED';

export default function ManageLandlordsPage() {
    const [loading, setLoading] = useState<boolean>(true);
    const [landlords, setLandlords] = useState<Landlord[]>([]);
    
    const [searchTerm, setSearchTerm] = useState<string>('');
    const [statusFilter, setStatusFilter] = useState<FilterStatus>('ALL');

    const [previewModal, setPreviewModal] = useState<PreviewModalState>({ isOpen: false, title: '', url: '', mimeType: '' });
    const [rejectModal, setRejectModal] = useState<RejectModalState>({ isOpen: false, landlordId: null, landlordName: '' });
    const [alertModal, setAlertModal] = useState<AlertModalState>({ isOpen: false, title: '', message: '' });
    
    const [rejectSubject, setRejectSubject] = useState<string>('');
    const [rejectMessage, setRejectMessage] = useState<string>('');
    const [isRejecting, setIsRejecting] = useState<boolean>(false);

    const [isDecrypting, setIsDecrypting] = useState<string | null>(null);

    useEffect(() => {
        fetchLandlords();
    }, []);

    const fetchLandlords = async () => {
        try {
            const data = await apiFetch('/landlords/');
            setLandlords(data.results || data || []);
        } catch (err) {
            console.error("Failed to fetch landlords", err);
        } finally {
            setLoading(false);
        }
    };

    const handleApprove = async (id: string) => {
        try {
            await apiFetch(`/landlords/${id}/`, {
                method: 'PATCH',
                body: JSON.stringify({ 
                    is_verified: true,
                    manual_verification_status: false
                })
            });
            fetchLandlords(); 
        } catch (err) {
            console.error("Failed to approve landlord", err);
        }
    };

    const handleRejectSubmit = async (e: FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        if (!rejectModal.landlordId) return;

        setIsRejecting(true);

        try {
            await apiFetch(`/landlords/${rejectModal.landlordId}/`, {
                method: 'PATCH',
                body: JSON.stringify({ 
                    is_verified: false,
                    manual_verification_status: false 
                })
            });

            setRejectModal({ isOpen: false, landlordId: null, landlordName: '' });
            setRejectSubject('');
            setRejectMessage('');
            fetchLandlords(); 
        } catch (err) {
            console.error("Failed to reject landlord", err);
        } finally {
            setIsRejecting(false);
        }
    };

   const handleOpenSecurePreview = async (
        landlordId: string, 
        rawUrl: string | undefined, 
        docType: 'contract' | 'face' | 'id_document', 
        title: string
    ) => {
        if (!rawUrl) {
            setAlertModal({
                isOpen: true,
                title: "Document Missing",
                message: `This landlord has not uploaded their ${title} yet. Setup must be finalized within the mobile application context.`
            });
            return;
        }

        setIsDecrypting(`${landlordId}-${docType}`);
        try {
            const data = await apiFetch(`/landlords/${landlordId}/decrypted-document/?type=${docType}`);
            
            let finalUrl = '';
            
            if (data.mime_type.includes('image')) {
                // Inline images bind directly via lightweight Data URIs
                finalUrl = `data:${data.mime_type};base64,${data.document_base64}`;
            } else {
                // Complex objects (PDFs) are hydrated natively into sandboxed Local Binary Blobs
                const byteCharacters = atob(data.document_base64);
                const byteNumbers = new Array(byteCharacters.length);
                for (let i = 0; i < byteCharacters.length; i++) {
                    byteNumbers[i] = byteCharacters.charCodeAt(i);
                }
                const byteArray = new Uint8Array(byteNumbers);
                const blob = new Blob([byteArray], { type: data.mime_type });
                finalUrl = URL.createObjectURL(blob);
            }

            setPreviewModal({ 
                isOpen: true, 
                title, 
                url: finalUrl, 
                mimeType: data.mime_type 
            });
            
        } catch (error) {
            setAlertModal({
                isOpen: true,
                title: "Decryption Operations Error",
                message: "Security exception encountered while trying to translate asset. Please verify cryptographic key alignment parameters."
            });
        } finally {
            setIsDecrypting(null);
        }
    };

    const filteredLandlords = landlords.filter((l) => {
        const matchesSearch = (l.name && l.name.toLowerCase().includes(searchTerm.toLowerCase())) ||
                              (l.email && l.email.toLowerCase().includes(searchTerm.toLowerCase()));
        
        let matchesStatus = true;
        if (statusFilter === 'VERIFIED') matchesStatus = l.is_verified === true;
        else if (statusFilter === 'REVIEW') matchesStatus = l.manual_verification_status === true && !l.is_verified;
        else if (statusFilter === 'UNVERIFIED') matchesStatus = !l.is_verified && !l.manual_verification_status;

        return matchesSearch && matchesStatus;
    });

    if (loading) return <div className="flex justify-center py-32"><Loader2 className="animate-spin text-blue-500" size={48} /></div>;

    return (
        <div className="space-y-6 animate-in slide-in-from-right-4 duration-300 relative">
            
            {alertModal.isOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-blue-950/60 backdrop-blur-sm">
                    <div className="bg-white rounded-[24px] p-8 w-full max-w-sm shadow-2xl shadow-blue-950/20 animate-in zoom-in-95 duration-200 border border-blue-100 text-center">
                        <div className="w-16 h-16 bg-rose-50 rounded-full flex items-center justify-center mx-auto mb-4 border border-rose-100">
                            <AlertTriangle className="text-rose-500" size={32} />
                        </div>
                        <h3 className="text-xl font-black text-blue-950 mb-2 tracking-tight">{alertModal.title}</h3>
                        <p className="text-sm text-slate-500 leading-relaxed mb-6">
                            {alertModal.message}
                        </p>
                        <button 
                            onClick={() => setAlertModal({ isOpen: false, title: '', message: '' })}
                            className="w-full py-3 bg-blue-950 text-white rounded-xl text-xs font-bold hover:bg-blue-900 transition-all shadow-lg shadow-blue-950/20"
                        >
                            ACKNOWLEDGE
                        </button>
                    </div>
                </div>
            )}

            {rejectModal.isOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-blue-950/60 backdrop-blur-sm">
                    <div className="bg-white rounded-[32px] p-8 w-full max-w-md shadow-2xl shadow-blue-950/20 animate-in zoom-in-95 duration-200 border border-blue-100">
                        <div className="flex justify-between items-center mb-6">
                            <div>
                                <h3 className="text-xl font-black text-blue-950 tracking-tight">Reject Application</h3>
                                <p className="text-xs font-bold text-rose-500 uppercase tracking-widest mt-1">
                                    {rejectModal.landlordName}
                                </p>
                            </div>
                            <button onClick={() => setRejectModal({ isOpen: false, landlordId: null, landlordName: '' })} className="p-2 text-slate-400 hover:bg-slate-100 rounded-full transition-colors">
                                <X size={20} />
                            </button>
                        </div>
                        
                        <form onSubmit={handleRejectSubmit} className="space-y-4">
                            <div className="space-y-1.5">
                                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest pl-1">Reason / Subject</label>
                                <input 
                                    type="text" required
                                    value={rejectSubject} onChange={(e) => setRejectSubject(e.target.value)}
                                    placeholder="e.g. ID Document Unclear"
                                    className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:bg-white focus:border-rose-400 focus:ring-2 focus:ring-rose-100 outline-none transition-all"
                                />
                            </div>
                            <div className="space-y-1.5">
                                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest pl-1">Detailed Feedback</label>
                                <textarea 
                                    required rows={4}
                                    value={rejectMessage} onChange={(e) => setRejectMessage(e.target.value)}
                                    placeholder="Explain exactly what needs to be fixed..."
                                    className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:bg-white focus:border-rose-400 focus:ring-2 focus:ring-rose-100 outline-none transition-all resize-none"
                                ></textarea>
                            </div>
                            
                            <div className="pt-4 flex gap-3">
                                <button type="button" onClick={() => setRejectModal({ isOpen: false, landlordId: null, landlordName: '' })} className="flex-1 py-3 bg-slate-100 text-slate-600 rounded-xl text-xs font-bold hover:bg-slate-200 transition-colors">
                                    CANCEL
                                </button>
                                <button type="submit" disabled={isRejecting} className="flex-1 py-3 bg-rose-500 text-white rounded-xl text-xs font-bold hover:bg-rose-600 shadow-lg shadow-rose-500/20 transition-all flex items-center justify-center gap-2 disabled:opacity-70">
                                    {isRejecting ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
                                    SEND REJECTION
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {previewModal.isOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-blue-950/80 backdrop-blur-sm">
                    <div className="bg-white rounded-3xl w-full max-w-4xl max-h-[90vh] shadow-2xl flex flex-col overflow-hidden animate-in zoom-in-95 duration-200">
                        <div className="px-6 py-4 border-b border-blue-100 flex justify-between items-center bg-blue-50/50">
                            <div>
                                <h3 className="text-lg font-black text-blue-950">{previewModal.title}</h3>
                                <p className="text-xs text-slate-500 font-medium">Secure Decrypted File Preview</p>
                            </div>
                            <div className="flex items-center gap-2">
                                <a 
                                    href={previewModal.url} 
                                    target="_blank" 
                                    rel="noopener noreferrer" 
                                    download={previewModal.title.replace(/\s+/g, '_').toLowerCase()}
                                    className="flex items-center gap-2 px-4 py-2 bg-blue-100 text-blue-700 hover:bg-blue-200 rounded-lg text-xs font-bold transition-colors"
                                >
                                    <Download size={14} /> DOWNLOAD
                                </a>
                                <button onClick={() => setPreviewModal({ isOpen: false, title: '', url: '', mimeType: '' })} className="p-2 text-slate-400 hover:bg-slate-200 hover:text-slate-600 rounded-full transition-colors">
                                    <X size={20} />
                                </button>
                            </div>
                        </div>
                        <div className="flex-1 bg-slate-100 overflow-auto p-4 flex items-center justify-center min-h-[50vh]">
                            {previewModal.mimeType.includes('pdf') ? (
                                <iframe src={previewModal.url} className="w-full h-[60vh] rounded-xl border border-slate-300" title="PDF Document" />
                            ) : previewModal.mimeType.includes('image') ? (
                                <img src={previewModal.url} alt="Document" className="max-w-full max-h-[60vh] rounded-xl shadow-lg border border-slate-200 object-contain" />
                            ) : (
                                <p className="text-slate-400 text-sm font-medium flex flex-col items-center gap-2">
                                    <FileText size={48} className="text-slate-300" />
                                    File successfully decrypted. Click Download or Open in New Tab to view it.
                                    <a href={previewModal.url} target="_blank" rel="noopener noreferrer" className="mt-4 px-6 py-2 bg-blue-950 text-white rounded-xl font-bold text-xs hover:bg-blue-900 transition-colors shadow-lg shadow-blue-950/20">
                                        OPEN IN NEW TAB
                                    </a>
                                </p>
                            )}
                        </div>
                    </div>
                </div>
            )}

            <div className="flex flex-col xl:flex-row xl:items-end justify-between gap-6 bg-white p-6 rounded-[28px] border border-blue-50 shadow-sm">
                <div>
                    <h2 className="text-2xl font-black text-blue-950 tracking-tight">Landlord Verification</h2>
                    <p className="text-slate-500 text-xs font-medium mt-1">Review biometrics, legal contracts, and approve accounts.</p>
                </div>
                
                <div className="flex flex-col sm:flex-row items-center gap-4 w-full xl:w-auto">
                    <div className="flex items-center p-1 bg-slate-50 rounded-xl w-full sm:w-auto border border-blue-50">
                        <FilterButton active={statusFilter === 'ALL'} onClick={() => setStatusFilter('ALL')} label="All" />
                        <FilterButton active={statusFilter === 'VERIFIED'} onClick={() => setStatusFilter('VERIFIED')} label="Verified" icon={<CheckCircle2 size={12}/>} />
                        <FilterButton active={statusFilter === 'REVIEW'} onClick={() => setStatusFilter('REVIEW')} label="Review" icon={<ShieldAlert size={12}/>} />
                        <FilterButton active={statusFilter === 'UNVERIFIED'} onClick={() => setStatusFilter('UNVERIFIED')} label="Unverified" icon={<Ban size={12}/>} />
                    </div>

                    <div className="relative w-full sm:w-64">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-blue-300" size={16} />
                        <input 
                            type="text" 
                            placeholder="Search name or email..." 
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full pl-10 pr-4 py-2.5 bg-blue-50/50 border border-blue-100 rounded-xl outline-none focus:bg-white focus:border-blue-400 transition-all text-sm shadow-inner shadow-blue-50/50 placeholder-blue-300 font-medium"
                        />
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                {filteredLandlords.map((landlord) => {
                    
                    const missingDocs: string[] = [];
                    if (!landlord.id_document_url) missingDocs.push("ID Document");
                    if (!landlord.contract_url) missingDocs.push("Legal Contract");
                    if (!landlord.face_url) missingDocs.push("Live Biometrics");
                    
                    const isReadyToApprove = missingDocs.length === 0;

                    return (
                        <div key={landlord.id} className="bg-white rounded-[28px] p-6 border border-blue-50 shadow-sm hover:shadow-md relative overflow-hidden flex flex-col h-full hover:-translate-y-1 transition-all duration-300">
                            
                            <div className={`absolute top-0 left-0 w-full h-1.5 ${
                                landlord.is_verified ? 'bg-emerald-500' : 
                                landlord.manual_verification_status ? 'bg-amber-500' : 'bg-slate-300'
                            }`}></div>

                            <div className="flex items-start justify-between mb-4">
                                <div className="w-12 h-12 rounded-2xl bg-blue-50 flex items-center justify-center text-blue-600 font-black text-lg border border-blue-100 shadow-sm">
                                    {landlord.name ? landlord.name.charAt(0) : 'L'}
                                </div>
                                
                                {landlord.is_verified ? (
                                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-emerald-50 text-emerald-600 text-[10px] font-bold border border-emerald-100 uppercase tracking-wider">
                                        <CheckCircle2 size={12} /> Verified
                                    </span>
                                ) : landlord.manual_verification_status ? (
                                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-amber-50 text-amber-600 text-[10px] font-bold border border-amber-100 uppercase tracking-wider animate-pulse">
                                        <ShieldAlert size={12} /> Manual Review
                                    </span>
                                ) : (
                                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-slate-100 text-slate-500 text-[10px] font-bold border border-slate-200 uppercase tracking-wider">
                                        <Ban size={12} /> Unverified
                                    </span>
                                )}
                            </div>

                            <div>
                                <h3 className="text-lg font-black text-blue-950">{landlord.name || 'Pending Setup'} {landlord.surname || ''}</h3>
                                <p className="text-sm text-slate-500 font-medium truncate">{landlord.email || 'No email provided'}</p>
                                <p className="text-xs text-slate-400 mt-1 font-mono bg-slate-50 inline-block px-2 py-0.5 rounded mt-2">{landlord.firebase_uid?.slice(0, 8) || 'No UID'}</p>
                            </div>

                            <div className="mt-5 p-4 rounded-2xl bg-slate-50 border border-slate-100">
                                {isReadyToApprove ? (
                                    <div className="flex items-center gap-2 text-emerald-600 text-[11px] font-bold">
                                        <CheckCircle size={16} /> All files submitted securely.
                                    </div>
                                ) : (
                                    <div>
                                        <div className="flex items-center gap-2 text-slate-700 text-xs font-bold mb-2">
                                            <AlertTriangle size={14} className="text-rose-500" /> Missing Requirements:
                                        </div>
                                        <div className="flex flex-wrap gap-2 mt-1">
                                            {missingDocs.map((doc, idx) => (
                                                <span key={idx} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-md bg-rose-50 text-rose-600 text-[10px] font-bold border border-rose-100">
                                                    <XCircle size={10} /> {doc}
                                                </span>
                                            ))}
                                        </div>
                                    </div>
                                )}
                            </div>

                            <div className="mt-4 pt-4 border-t border-blue-50 grid grid-cols-3 gap-2 flex-grow">
                                <button 
                                    onClick={() => handleOpenSecurePreview(landlord.id, landlord.id_document_url, 'id_document', `${landlord.name || 'Landlord'}'s ID`)}
                                    disabled={isDecrypting === `${landlord.id}-id_document`}
                                    className="flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-white text-slate-600 text-[10px] font-bold hover:bg-blue-50 hover:text-blue-600 transition-colors border border-slate-200 shadow-sm disabled:opacity-50"
                                >
                                    {isDecrypting === `${landlord.id}-id_document` ? <Loader2 size={12} className="animate-spin" /> : <BadgeAlert size={12} />} Identity
                                </button>
                                <button 
                                    onClick={() => handleOpenSecurePreview(landlord.id, landlord.contract_url, 'contract', `${landlord.name || 'Landlord'}'s Contract`)}
                                    disabled={isDecrypting === `${landlord.id}-contract`}
                                    className="flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-white text-slate-600 text-[10px] font-bold hover:bg-blue-50 hover:text-blue-600 transition-colors border border-slate-200 shadow-sm disabled:opacity-50"
                                >
                                    {isDecrypting === `${landlord.id}-contract` ? <Loader2 size={12} className="animate-spin" /> : <FileText size={12} />} Contract
                                </button>
                                <button 
                                    onClick={() => handleOpenSecurePreview(landlord.id, landlord.face_url, 'face', `${landlord.name || 'Landlord'}'s Biometrics`)}
                                    disabled={isDecrypting === `${landlord.id}-face`}
                                    className="flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-white text-slate-600 text-[10px] font-bold hover:bg-blue-50 hover:text-blue-600 transition-colors border border-slate-200 shadow-sm disabled:opacity-50"
                                >
                                    {isDecrypting === `${landlord.id}-face` ? <Loader2 size={12} className="animate-spin" /> : <Fingerprint size={12} />} Biometrics
                                </button>
                            </div>

                            {!landlord.is_verified && (
                                <div className="mt-4 pt-2 flex gap-3">
                                    <button 
                                        onClick={() => handleApprove(landlord.id)}
                                        disabled={!isReadyToApprove}
                                        className="flex-1 py-3 rounded-xl bg-emerald-500 text-white text-xs font-bold hover:bg-emerald-600 transition-all shadow-md shadow-emerald-500/20 disabled:opacity-40 disabled:hover:bg-emerald-500 disabled:shadow-none"
                                        title={!isReadyToApprove ? "Cannot approve: Missing files" : "Approve Landlord"}
                                    >
                                        APPROVE
                                    </button>
                                    <button 
                                        onClick={() => setRejectModal({ isOpen: true, landlordId: landlord.id, landlordName: `${landlord.name} ${landlord.surname}` })}
                                        className="flex-1 py-3 rounded-xl bg-white text-rose-600 text-xs font-bold hover:bg-rose-50 transition-colors border border-rose-200 shadow-sm"
                                    >
                                        REJECT
                                    </button>
                                </div>
                            )}
                        </div>
                    );
                })}
            </div>
            
            {filteredLandlords.length === 0 && !loading && (
                <div className="text-center py-24 bg-white rounded-[32px] border border-blue-50 shadow-sm">
                    <div className="w-20 h-20 bg-blue-50 rounded-full flex items-center justify-center mx-auto mb-4 border border-blue-100">
                        <Filter size={32} className="text-blue-400" />
                    </div>
                    <h3 className="text-lg font-black text-blue-950">No Landlords Found</h3>
                    <p className="text-slate-500 text-sm mt-1 max-w-md mx-auto">
                        There are no landlords matching your current search criteria or status filter.
                    </p>
                </div>
            )}
        </div>
    );
}

function FilterButton({ active, onClick, label, icon }: { active: boolean, onClick: () => void, label: string, icon?: React.ReactNode }) {
    return (
        <button 
            onClick={onClick}
            className={`flex-1 sm:flex-none flex items-center justify-center gap-1.5 px-4 py-1.5 rounded-lg text-[11px] font-bold transition-all ${
                active 
                ? 'bg-white text-blue-950 shadow-sm border border-blue-100' 
                : 'text-slate-500 hover:text-blue-700 border border-transparent'
            }`}
        >
            {icon} {label}
        </button>
    );
}