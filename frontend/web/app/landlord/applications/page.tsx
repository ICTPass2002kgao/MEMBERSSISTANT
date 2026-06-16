"use client";

import React, { useState, useEffect, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { 
  FileText, CheckCircle2, XCircle, Loader2, User, 
  Search, ShieldAlert, AlertCircle, Building2
} from 'lucide-react';
import { apiFetch } from '../../components/api';
import { SectionHeader, ModalWrapper, SubmitButton } from '../../components/SharedUI';

export default function ApplicationsPage() {
    const [allStudents, setAllStudents] = useState<any[]>([]);
    const [applicants, setApplicants] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState("");

    // Modal States
    const [isApprovalModalOpen, setIsApprovalModalOpen] = useState(false);
    const [applicantToApprove, setApplicantToApprove] = useState<any | null>(null);
     
    const [previewInfo, setPreviewInfo] = useState<{id: string, type: 'id' | 'proof', name: string} | null>(null);

    const fetchData = async () => {
        setLoading(true);
        try {
            const data = await apiFetch('/students/');
            const students = data.results || data || [];
            
            setAllStudents(students); 
            setApplicants(students.filter((s: any) => 
                s.room === null && 
                !s.verification_status && 
                s.applied_accommodation_name != null
            ));
            
        } catch (error) { 
            console.error("Fetch Error:", error); 
        } finally { 
            setLoading(false); 
        }
    };

    useEffect(() => { fetchData(); }, []);

    const filteredApplicants = useMemo(() => {
        return applicants.filter(s => 
            `${s.name} ${s.surname}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
            s.student_number.toLowerCase().includes(searchTerm.toLowerCase())
        );
    }, [applicants, searchTerm]);

    const handleReject = async (id: string, name: string) => {
        if (!window.confirm(`Are you sure you want to reject and permanently delete ${name}'s application?`)) return;
        try {
            await apiFetch(`/students/${id}/`, { method: 'DELETE' });
            fetchData(); 
        } catch (error) { console.error(error); }
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
            {/* Header Section */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="Pending Applications" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        System Tracking: {filteredApplicants.length} Awaiting Review
                    </p>
                </div>
            </div>

            {/* Glassmorphic Search Engine */}
            <div className="bg-white border border-blue-100 p-6 rounded-[28px] shadow-sm">
                <div className="relative w-full md:w-1/2">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300" size={18} />
                    <input 
                        type="text"
                        placeholder="Search applicants by name or student number..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full bg-blue-50/50 border border-blue-100 pl-12 pr-4 py-3.5 rounded-2xl text-sm outline-none focus:bg-white focus:border-blue-400 transition-all"
                    />
                </div>
            </div>

            {/* Applications Table Container */}
            <div className="bg-white border border-blue-100 rounded-[28px] shadow-sm overflow-hidden">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left min-w-[1100px]">
                        <thead className="bg-slate-50/50 border-b border-blue-50 text-slate-400 text-[10px] uppercase tracking-[0.2em]">
                            <tr>
                                <th className="py-5 px-6 font-black w-12 text-center">Applicant</th>
                                <th className="py-5 px-6 font-black">Identity Details</th>
                                <th className="py-5 px-6 font-black">Student No.</th>
                                <th className="py-5 px-6 font-black text-center">Compliance</th>
                                <th className="py-5 px-6 font-black text-right sticky right-0 bg-white">Decisions & Documents</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-blue-50 text-sm">
                            {loading ? (
                                <tr><td colSpan={5} className="py-24 text-center"><Loader2 className="animate-spin mx-auto text-blue-500" size={32} /></td></tr>
                            ) : filteredApplicants.length === 0 ? (
                                <tr><td colSpan={5} className="py-24 text-center text-slate-400 font-bold uppercase tracking-widest italic">No pending applications found.</td></tr>
                            ) : filteredApplicants.map((app: any) => {
                                const hasDocuments = app.id_document_url && app.proof_of_registration_url;

                                return (
                                <tr key={app.id} className="hover:bg-blue-50/30 transition-all group">
                                    <td className="py-4 px-6">
                                        <div className="w-10 h-10 rounded-2xl bg-orange-50 border border-orange-100 flex items-center justify-center text-orange-400 overflow-hidden shadow-sm">
                                            <User size={18} />
                                        </div>
                                    </td>
                                    <td className="py-4 px-6">
                                        <div className="font-black text-blue-950 text-base">{app.name} {app.surname}</div>
                                        <div className="text-[10px] text-slate-400 font-bold lowercase tracking-tighter">{app.email}</div>
                                        {app.phone && <div className="text-[10px] text-slate-400 font-bold tracking-widest mt-0.5">{app.phone}</div>}
                                        
                                        <div className="mt-2 inline-flex items-center gap-1.5 px-2 py-1 bg-blue-50 text-blue-600 rounded text-[9px] font-black uppercase tracking-widest">
                                            <Building2 size={10} />
                                            {app.applied_accommodation_name}
                                        </div>
                                    </td>
                                    <td className="py-4 px-6">
                                        <div className="font-bold text-blue-500 tracking-widest">{app.student_number}</div>
                                        <div className="text-[9px] font-black text-slate-400 uppercase mt-1">{app.gender}</div>
                                    </td>
                                    <td className="py-4 px-6 text-center">
                                        {hasDocuments ? (
                                            <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-emerald-50 text-emerald-600 border border-emerald-100 rounded-lg text-[9px] font-black tracking-widest">
                                                <CheckCircle2 size={12} /> VERIFIED
                                            </span>
                                        ) : (
                                            <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-rose-50 text-rose-600 border border-rose-100 rounded-lg text-[9px] font-black tracking-widest">
                                                <ShieldAlert size={12} /> INCOMPLETE
                                            </span>
                                        )}
                                    </td>
                                    <td className="py-4 px-6 text-right sticky right-0 bg-white group-hover:bg-blue-50/10 transition-all border-l border-blue-50">
                                        <div className="flex items-center justify-end gap-3">
                                            
                                            {hasDocuments ? (
                                                <div className="flex flex-col gap-1.5 mr-2">
                                                    <button 
                                                        onClick={() => setPreviewInfo({id: app.id, type: 'id', name: app.name})}
                                                        className="flex items-center justify-center gap-1.5 px-3 py-1 bg-blue-50 hover:bg-blue-600 text-blue-500 hover:text-white rounded-lg text-[9px] font-black uppercase tracking-widest transition-all shadow-sm shadow-blue-500/10"
                                                    >
                                                        <FileText size={10}/> Preview ID
                                                    </button>
                                                    <button 
                                                        onClick={() => setPreviewInfo({id: app.id, type: 'proof', name: app.name})}
                                                        className="flex items-center justify-center gap-1.5 px-3 py-1 bg-purple-50 hover:bg-purple-600 text-purple-500 hover:text-white rounded-lg text-[9px] font-black uppercase tracking-widest transition-all shadow-sm shadow-purple-500/10"
                                                    >
                                                        <FileText size={10}/> Preview Proof
                                                    </button>
                                                </div>
                                            ) : (
                                                <span className="text-[9px] font-bold text-slate-300 uppercase tracking-widest mr-2">Awaiting Docs</span>
                                            )}

                                            <div className="h-8 w-px bg-blue-100 mx-1"></div>

                                            <button 
                                                onClick={() => handleReject(app.id, app.name)} 
                                                className="p-2 text-slate-300 hover:text-rose-600 hover:bg-white rounded-xl shadow-sm transition-all"
                                                title="Reject Application"
                                            >
                                                <XCircle size={18}/>
                                            </button>
                                            
                                            <button 
                                                onClick={() => { setApplicantToApprove(app); setIsApprovalModalOpen(true); }}
                                                disabled={!hasDocuments}
                                                className={`px-4 py-2 rounded-xl text-[10px] font-black tracking-widest transition-all ${
                                                    hasDocuments ? 'bg-blue-600 text-white shadow-md shadow-blue-600/20 hover:bg-blue-700' : 'bg-slate-100 text-slate-400 cursor-not-allowed'
                                                }`}
                                            >
                                                ACCEPT APPLICATION
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            )})}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Application Approval Modal */}
            {isApprovalModalOpen && (
                <ApprovalModal 
                    applicant={applicantToApprove} 
                    onClose={() => setIsApprovalModalOpen(false)} 
                    onSuccess={() => { 
                        setIsApprovalModalOpen(false); 
                    }} 
                />
            )}

            {/* Decrypted Document Preview Modal */}
            {previewInfo && (
                <DocumentPreviewModal 
                    info={previewInfo} 
                    onClose={() => setPreviewInfo(null)} 
                />
            )}
        </div>
    );
}

// --- DOCUMENT PREVIEW MODAL ---
function DocumentPreviewModal({ info, onClose }: { info: {id: string, type: string, name: string}, onClose: () => void }) {
    const [docData, setDocData] = useState<{document_base64: string, mime_type: string} | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        const fetchDecryptedDoc = async () => {
            try {
                const res = await apiFetch(`/students/${info.id}/decrypted-document/?type=${info.type}`);
                if (res.error) {
                    setError(res.error);
                } else {
                    setDocData(res);
                }
            } catch (err: any) {
                setError(err.message || "Failed to securely decrypt the document.");
            } finally {
                setLoading(false);
            }
        };
        fetchDecryptedDoc();
    }, [info]);

    return (
        <ModalWrapper title={`Secure Preview: ${info.name}'s ${info.type === 'id' ? 'ID Document' : 'Proof of Registration'}`} onClose={onClose}>
            <div className="w-full h-[60vh] bg-slate-50 rounded-2xl flex items-center justify-center border border-slate-200 overflow-hidden relative">
                {loading && <Loader2 className="animate-spin text-blue-500" size={32} />}
                {error && <div className="text-rose-500 font-bold text-xs uppercase tracking-widest flex items-center gap-2"><AlertCircle size={16}/>{error}</div>}
                
                {docData && !error && (
                    (docData.mime_type && docData.mime_type.includes('image')) ? (
                        <img src={`data:${docData.mime_type};base64,${docData.document_base64}`} alt="Document Preview" className="max-w-full max-h-full object-contain" />
                    ) : (
                        <iframe src={`data:${docData.mime_type || 'application/pdf'};base64,${docData.document_base64}#toolbar=0`} className="w-full h-full border-0"></iframe>
                    )
                )}
            </div>
        </ModalWrapper>
    );
}

// --- APPLICANT APPROVAL MODAL ---
function ApprovalModal({ applicant, onClose, onSuccess }: any) {
    const router = useRouter(); // Next.js router instance
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [isSuccess, setIsSuccess] = useState(false); 
    
    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault(); 
        setLoading(true); 
        setError('');

        try {
            // 1. Mark Application as Verified
            await apiFetch(`/students/${applicant.id}/`, { 
                method: 'PATCH', 
                body: JSON.stringify({ verification_status: true }) 
            });
            
            // 2. Dispatch Push Notification to the Student's Mobile App
            try {
                await apiFetch('/send-communication/', {
                    method: 'POST',
                    body: JSON.stringify({
                        title: "Application Approved 🎉",
                        message: "Your application has been accepted! \n Please come to the administration office to complete your biometric setup and receive your room allocation.\nPlease note that should you not be come within a max of 3 days, consider your application unsuccessful.\n\nKind Regards\nDankie Team",
                        send_mode: "direct",
                        recipient_ids: [applicant.firebase_uid]
                    })
                });
            } catch (notifyErr) {
                console.warn("Approval successful, but notification dispatch failed.", notifyErr);
            }
            
            // 3. Trigger Premium Success State & Redirect
            setIsSuccess(true);
            setTimeout(() => {
                onSuccess();
                router.push('/landlord/students'); // Redirect to Resident Directory to assign room
            }, 2500); 
            
        } catch (err: any) { 
            setError(err.message || 'Approval process failed.'); 
            setLoading(false);
        }
    };

    // Render Premium Success State
    if (isSuccess) {
        return (
            <ModalWrapper title="Approval Confirmed" onClose={() => {}}>
                <div className="flex flex-col items-center justify-center py-12 px-6 text-center animate-in zoom-in duration-500">
                    <div className="w-20 h-20 bg-emerald-50 text-emerald-500 rounded-[24px] flex items-center justify-center mb-6 shadow-lg shadow-emerald-500/20 border border-emerald-100">
                        <CheckCircle2 size={40} strokeWidth={3} />
                    </div>
                    <h3 className="text-2xl font-black text-blue-950 tracking-tight mb-2">Application Accepted</h3>
                    <p className="text-slate-500 text-sm font-medium leading-relaxed max-w-sm mb-6">
                        <strong className="text-blue-600">{applicant.name} {applicant.surname}</strong> has been verified. 
                    </p>
                    <div className="flex items-center gap-2 text-blue-500 font-bold text-[11px] uppercase tracking-widest">
                        <Loader2 className="animate-spin" size={14} />
                        Redirecting to assign room...
                    </div>
                </div>
            </ModalWrapper>
        );
    }

    // Render Confirmation Form State
    return (
        <ModalWrapper title="Approve Application" onClose={onClose}>
            <form onSubmit={handleSubmit} className="space-y-6">
                {error && <div className="p-3 bg-rose-50 text-rose-600 text-[10px] font-black uppercase tracking-widest border border-rose-100 rounded-xl flex items-center gap-2"><AlertCircle size={14}/>{error}</div>}
                
                <div className="p-5 bg-blue-50/50 border border-blue-100 rounded-2xl text-center">
                    <div className="w-16 h-16 rounded-full bg-white border border-blue-100 flex items-center justify-center text-blue-500 shadow-sm mx-auto mb-4">
                        <User size={24} />
                    </div>
                    <h3 className="text-lg font-black text-blue-950">{applicant.name} {applicant.surname}</h3>
                    <p className="text-blue-500 font-bold tracking-widest text-xs mt-1">{applicant.student_number}</p>
                    
                    <div className="flex justify-center gap-4 mt-4 text-[10px] font-black uppercase tracking-widest text-slate-400">
                        <span>Gender: <strong className="text-slate-600">{applicant.gender}</strong></span>
                        <span>Phone: <strong className="text-slate-600">{applicant.phone || 'N/A'}</strong></span>
                    </div>
                </div>

                <div className="bg-amber-50 border border-amber-100 p-4 rounded-xl flex gap-3 text-amber-800 text-sm">
                    <AlertCircle className="shrink-0 mt-0.5" size={18} />
                    <p>
                        <strong>Next Step:</strong> Approving this application will redirect you to the <strong>Resident Directory</strong> where you can complete their physical onboarding and assign a room.
                    </p>
                </div>

                <SubmitButton loading={loading} text="Approve & Proceed to Room Assignment" />
            </form>
        </ModalWrapper>
    );
}