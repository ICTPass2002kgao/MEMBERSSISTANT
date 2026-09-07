"use client";

import React, { useState, useEffect, useRef } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { 
    ArrowLeft, 
    MapPin, 
    Building2, 
    KeyRound, 
    Loader2, 
    ShieldCheck, 
    Wifi, 
    BedDouble,
    CheckCircle2,
    Lock,
    FolderOpen,
    UploadCloud,
    CheckCircle,
    ChevronLeft,
    ChevronRight
} from 'lucide-react';
import { apiFetch, BASE_URL } from '../../components/api'; 
import { auth } from '../../firebase/config'; 
import { getIdToken } from 'firebase/auth';

interface Accommodation {
    id: string | number;
    name: string;
    address: string;
    gender_target: string;
    key_price?: string;
    accommodation_logo_url?: string;
    description?: string;
    images?: { id?: string | number; image_url: string; is_primary?: boolean }[];
}

interface Block {
    id: string | number;
    name: string;
    gender_target: string;
}

export default function AccommodationDetailsPage() {
    const params = useParams();
    const router = useRouter();
    const id = params?.id;

    const [accommodation, setAccommodation] = useState<Accommodation | null>(null);
    const [blocks, setBlocks] = useState<Block[]>([]);
    const [isLoading, setIsLoading] = useState<boolean>(true);
    const [error, setError] = useState<string>('');

    const [isApplying, setIsApplying] = useState<boolean>(false);
    const [showLoginPrompt, setShowLoginPrompt] = useState<boolean>(false);
    const [showUploadModal, setShowUploadModal] = useState<boolean>(false);
    const [missingDocs, setMissingDocs] = useState({ id: false, proof: false });
    const [idFile, setIdFile] = useState<File | null>(null);
    const [proofFile, setProofFile] = useState<File | null>(null);
    const [applicationSuccess, setApplicationSuccess] = useState<boolean>(false);

    // Carousel state
    const [currentImageIndex, setCurrentImageIndex] = useState(0);
    const [isAutoPlaying, setIsAutoPlaying] = useState(true);
    const autoPlayRef = useRef<NodeJS.Timeout | null>(null);

    // Fetch details (no timeout)
    useEffect(() => {
        if (!id) return;

        let isMounted = true;

        const fetchDetails = async () => {
            try {
                const accData = await apiFetch(`/accommodations/${id}/`, {
                    method: 'GET',
                    headers: { 'Content-Type': 'application/json' },
                });
                if (!isMounted) return;
                setAccommodation(accData);

                const blocksData = await apiFetch(`/blocks/?accommodation=${id}`, {
                    method: 'GET',
                    headers: { 'Content-Type': 'application/json' },
                });
                if (!isMounted) return;
                
                if (blocksData && blocksData.results) {
                    setBlocks(blocksData.results);
                } else if (Array.isArray(blocksData)) {
                    setBlocks(blocksData);
                }
            } catch (err) {
                if (!isMounted) return;
                console.error("Fetch Accommodation Details Error:", err);
                setError('Could not load accommodation details.');
            } finally {
                if (isMounted) setIsLoading(false);
            }
        };

        fetchDetails();

        return () => {
            isMounted = false;
        };
    }, [id]);

    // Auto-advance carousel
    useEffect(() => {
        if (!accommodation || !accommodation.images || accommodation.images.length <= 1) return;

        if (isAutoPlaying) {
            autoPlayRef.current = setInterval(() => {
                setCurrentImageIndex(prev => (prev + 1) % (accommodation.images?.length || 1));
            }, 5000);
        }

        return () => {
            if (autoPlayRef.current) clearInterval(autoPlayRef.current);
        };
    }, [accommodation, isAutoPlaying]);

    // Reset index when accommodation changes
    useEffect(() => {
        setCurrentImageIndex(0);
    }, [accommodation]);

    // Build the list of images to display
    const imageList = accommodation?.images && accommodation.images.length > 0 
        ? accommodation.images.map(img => img.image_url) 
        : accommodation?.accommodation_logo_url 
            ? [accommodation.accommodation_logo_url]
            : ['https://images.unsplash.com/photo-1555854877-bab0e564b8d5?q=80&w=2000&auto=format&fit=crop'];

    const handlePrevImage = () => {
        setCurrentImageIndex(prev => (prev - 1 + imageList.length) % imageList.length);
    };

    const handleNextImage = () => {
        setCurrentImageIndex(prev => (prev + 1) % imageList.length);
    };

    // Redirect to login and remember current page
    const redirectToLogin = () => {
        sessionStorage.setItem('redirectAfterLogin', window.location.pathname);
        router.push('/login');
    };

    const handleApplyClick = async () => {
        const user = auth.currentUser;
        if (!user) {
            setShowLoginPrompt(true);
            return;
        }

        setIsApplying(true);

        try {
            const token = await getIdToken(user);
            const profileData = await apiFetch('/students/me/', {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                }
            });

            const hasId = !!profileData.id_document_url;
            const hasProof = !!profileData.proof_of_registration_url;

            if (!hasId || !hasProof) {
                setMissingDocs({ id: !hasId, proof: !hasProof });
                setShowUploadModal(true);
                setIsApplying(false);
                return;
            }

            await submitApplication(token);
        } catch (err) {
            console.error("Application error:", err);
            alert("An error occurred while processing your application. Please try again.");
            setIsApplying(false);
        }
    };

    const submitApplication = async (token: string) => {
        setIsApplying(true);
        try {
            await apiFetch('/apply-accommodation/', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ accommodation_id: id })
            });

            setApplicationSuccess(true);
            setTimeout(() => {
                router.push('/');
            }, 3000);
        } catch (err) {
            console.error("Submit application error:", err);
            alert("Failed to submit application.");
        } finally {
            setIsApplying(false);
        }
    };

    const handleDocumentUpload = async () => {
        if ((missingDocs.id && !idFile) || (missingDocs.proof && !proofFile)) {
            alert("Please upload all required missing documents.");
            return;
        }

        const user = auth.currentUser;
        if (!user) return;
        
        setIsApplying(true);
        setShowUploadModal(false);

        try {
            const token = await getIdToken(user);
            const formData = new FormData();
            
            if (idFile) formData.append('id_document', idFile);
            if (proofFile) formData.append('proof_of_registration', proofFile);

            const response = await fetch(`${BASE_URL || 'http://localhost:8000'}/students/update-documents/`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}` },
                body: formData
            });

            if (!response.ok) throw new Error("Document upload failed");
            await submitApplication(token);

        } catch (err) {
            console.error("Upload error:", err);
            alert("Failed to upload documents. Please try again.");
            setIsApplying(false);
        }
    };

    if (isLoading) {
        return (
            <div className="min-h-screen pt-40 pb-20 flex flex-col items-center justify-center gap-4">
                <div className="relative">
                    <div className="absolute inset-0 border-4 border-red-200 rounded-full animate-ping opacity-20"></div>
                    <Loader2 className="w-12 h-12 text-red-600 animate-spin relative z-10" />
                </div>
            </div>
        );
    }

    if (error || !accommodation) {
        return (
            <div className="min-h-screen pt-40 pb-20 flex flex-col items-center justify-center p-6">
                <div className="bg-white/80 backdrop-blur-xl border border-rose-100 p-10 rounded-[32px] text-center shadow-sm max-w-lg w-full">
                    <ShieldCheck className="w-16 h-16 text-rose-500 mx-auto mb-4" />
                    <h2 className="text-2xl font-black text-slate-900 mb-2">Property Not Found</h2>
                    <p className="text-slate-500 mb-8 font-medium">{error || "The accommodation you are looking for does not exist or has been removed."}</p>
                    <button onClick={() => router.push('/')} className="px-8 py-3.5 bg-slate-900 text-white rounded-xl text-sm font-bold shadow-lg hover:bg-slate-800 transition-all">
                        Return Home
                    </button>
                </div>
            </div>
        );
    }

    return (
        <div className="w-full pb-24 bg-blue-50">
            
            <nav className="fixed w-full z-[60] top-0 p-6 flex justify-between items-center mix-blend-difference text-white pointer-events-none">
                <button 
                    onClick={() => router.back()} 
                    className="w-12 h-12 rounded-full bg-white/10 backdrop-blur-md border border-white/20 flex items-center justify-center hover:bg-white/20 transition-colors pointer-events-auto"
                >
                    <ArrowLeft className="w-5 h-5" />
                </button>
            </nav>

            {/* HERO SECTION WITH CAROUSEL */}
            <section 
                className="relative w-full h-[60vh] md:h-[70vh] z-10"
                onMouseEnter={() => setIsAutoPlaying(false)}
                onMouseLeave={() => setIsAutoPlaying(true)}
            >
                <div className="absolute inset-0 overflow-hidden">
                    {imageList.map((img, idx) => (
                        <div
                            key={idx}
                            className={`absolute inset-0 transition-opacity duration-700 ${idx === currentImageIndex ? 'opacity-100 z-10' : 'opacity-0 z-0'}`}
                        >
                            <img 
                                src={img} 
                                alt={`${accommodation.name} - Image ${idx + 1}`}
                                className="w-full h-full object-cover"
                            />
                        </div>
                    ))}

                    <div className="absolute inset-0 bg-gradient-to-t from-[#FAFAFA] via-slate-900/40 to-transparent z-20"></div>
                </div>

                {imageList.length > 1 && (
                    <>
                        <button
                            onClick={handlePrevImage}
                            className="absolute left-4 top-1/2 -translate-y-1/2 z-30 w-12 h-12 rounded-full bg-white/20 backdrop-blur-md border border-white/30 flex items-center justify-center hover:bg-white/40 transition-all"
                        >
                            <ChevronLeft className="w-6 h-6 text-white" />
                        </button>
                        <button
                            onClick={handleNextImage}
                            className="absolute right-4 top-1/2 -translate-y-1/2 z-30 w-12 h-12 rounded-full bg-white/20 backdrop-blur-md border border-white/30 flex items-center justify-center hover:bg-white/40 transition-all"
                        >
                            <ChevronRight className="w-6 h-6 text-white" />
                        </button>

                        <div className="absolute bottom-24 left-1/2 -translate-x-1/2 z-30 flex gap-2">
                            {imageList.map((_, idx) => (
                                <button
                                    key={idx}
                                    onClick={() => setCurrentImageIndex(idx)}
                                    className={`w-2.5 h-2.5 rounded-full transition-all ${
                                        idx === currentImageIndex ? 'bg-white scale-125' : 'bg-white/50 hover:bg-white/80'
                                    }`}
                                />
                            ))}
                        </div>
                    </>
                )}

                <div className="absolute bottom-0 left-0 w-full px-6 translate-y-1/2 z-40">
                    <div className="max-w-6xl mx-auto flex items-end justify-between">
                        <div className="w-32 h-32 md:w-48 md:h-48 rounded-[2.5rem] bg-white p-5 shadow-[0_8px_30px_rgb(0,0,0,0.12)] border border-slate-100 flex items-center justify-center overflow-hidden">
                            {accommodation.accommodation_logo_url ? (
                                <img src={accommodation.accommodation_logo_url} alt="Logo" className="w-full h-full object-contain" />
                            ) : (
                                <Building2 className="w-20 h-20 text-red-700/50" />
                            )}
                        </div>
                    </div>
                </div>
            </section>

            <section className="relative z-10 pt-28 md:pt-40 px-6">
                <div className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-12">
                    
                    <div className="lg:col-span-2 space-y-12">
                        <div className="space-y-5">
                            <div className="flex items-center gap-3">
                                <span className="px-4 py-1.5 bg-red-100 text-red-800 text-[10px] font-black uppercase tracking-widest rounded-lg border border-red-200">
                                    {accommodation.gender_target} RESIDENCE
                                </span>
                            </div>
                            <h1 className="text-4xl md:text-6xl font-black text-slate-900 leading-tight tracking-tight">
                                {accommodation.name}
                            </h1>
                            <div className="flex items-start gap-3 text-slate-500 font-medium bg-white/60 p-4 rounded-2xl border border-slate-200 backdrop-blur-md shadow-sm w-fit">
                                <MapPin className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
                                <p className="text-lg leading-relaxed">{accommodation.address}</p>
                            </div>
                        </div>

                        <div className="space-y-4">
                            <h3 className="text-2xl font-black text-slate-900">About</h3>
                            <p className="text-slate-600 text-lg leading-relaxed font-medium">
                                {accommodation.description || 'No description provided by the landlord.'}
                            </p>
                        </div>

                        <div className="bg-white/80 backdrop-blur-xl p-10 rounded-[2.5rem] border border-slate-100 shadow-[0_8px_30px_rgb(0,0,0,0.04)]">
                            <h3 className="text-2xl font-black text-slate-900 mb-8">Property Highlights</h3>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-8">
                                <div className="flex items-center gap-5">
                                    <div className="w-14 h-14 rounded-2xl bg-red-50 border border-red-100 text-red-700 flex items-center justify-center">
                                        <Wifi className="w-6 h-6" />
                                    </div>
                                    <div>
                                        <p className="text-base font-black text-slate-900">Free Wi-Fi</p>
                                        <p className="text-[10px] uppercase font-bold text-slate-400">Uncapped Data</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-5">
                                    <div className="w-14 h-14 rounded-2xl bg-red-50 border border-red-100 text-red-700 flex items-center justify-center">
                                        <ShieldCheck className="w-6 h-6" />
                                    </div>
                                    <div>
                                        <p className="text-base font-black text-slate-900">24/7 Security</p>
                                        <p className="text-[10px] uppercase font-bold text-slate-400">Safe Access</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-5">
                                    <div className="w-14 h-14 rounded-2xl bg-red-50 border border-red-100 text-red-700 flex items-center justify-center">
                                        <KeyRound className="w-6 h-6" />
                                    </div>
                                    <div>
                                        <p className="text-base font-black text-slate-900">R {accommodation.key_price || '150'}</p>
                                        <p className="text-[10px] uppercase font-bold text-slate-400">Lost Key Penalty</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-5">
                                    <div className="w-14 h-14 rounded-2xl bg-red-50 border border-red-100 text-red-700 flex items-center justify-center">
                                        <BedDouble className="w-6 h-6" />
                                    </div>
                                    <div>
                                        <p className="text-base font-black text-slate-900">Furnished</p>
                                        <p className="text-[10px] uppercase font-bold text-slate-400">Bed & Desk Included</p>
                                    </div>
                                </div>
                            </div>
                        </div>
 
                    </div>

                    <div className="lg:col-span-1">
                        <div className="sticky top-28 bg-white/90 backdrop-blur-2xl p-8 rounded-[2.5rem] border border-slate-100 shadow-[0_20px_50px_rgb(0,0,0,0.06)] flex flex-col gap-6 z-20">
                            
                            <div className="text-center pb-6 border-b border-slate-100">
                                <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Application Status</p>
                                <div className="inline-flex items-center gap-2 px-4 py-2 bg-emerald-50 text-emerald-700 rounded-xl border border-emerald-200">
                                    <span className="relative flex h-2 w-2">
                                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                                      <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                                    </span>
                                    <span className="text-[11px] font-black uppercase tracking-wider">Accepting Applications</span>
                                </div>
                            </div>

                            <ul className="space-y-5">
                                <li className="flex items-start gap-4">
                                    <CheckCircle2 className="w-5 h-5 text-red-600 shrink-0" />
                                    <span className="text-sm text-slate-600 font-medium">NSFAS Accredited Property</span>
                                </li>
                                <li className="flex items-start gap-4">
                                    <CheckCircle2 className="w-5 h-5 text-red-600 shrink-0" />
                                    <span className="text-sm text-slate-600 font-medium">No initial deposit required for funded students</span>
                                </li>
                                <li className="flex items-start gap-4">
                                    <CheckCircle2 className="w-5 h-5 text-red-600 shrink-0" />
                                    <span className="text-sm text-slate-600 font-medium">Premium student lifestyle environment</span>
                                </li>
                            </ul>

                            <button 
                                onClick={handleApplyClick}
                                disabled={isApplying}
                                className="w-full mt-4 py-4 rounded-xl bg-gradient-to-r from-red-800 to-red-700 text-white text-sm font-black uppercase tracking-wider hover:from-red-900 hover:to-red-800 transition-all shadow-lg shadow-red-900/20 hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0 flex items-center justify-center gap-2"
                            >
                                {isApplying ? <><Loader2 className="w-5 h-5 animate-spin"/> PROCESSING...</> : 'APPLY NOW'}
                            </button>
                            
                            <p className="text-center text-[9px] font-black text-slate-400 uppercase tracking-widest mt-2">
                                Powered by Student Heights
                            </p>
                        </div>
                    </div>
                </div>
            </section>

            {/* Login Prompt Modal */}
            {showLoginPrompt && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-in fade-in duration-200">
                    <div className="bg-white/95 backdrop-blur-2xl p-8 rounded-[32px] border border-white/40 shadow-2xl max-w-sm w-full text-center">
                        <div className="w-16 h-16 bg-red-50 text-red-700 rounded-full flex items-center justify-center mx-auto mb-6 shadow-sm border border-red-100">
                            <Lock className="w-8 h-8" />
                        </div>
                        <h3 className="text-2xl font-black text-slate-900 mb-2">Authentication Required</h3>
                        <p className="text-slate-600 font-medium text-sm mb-8 leading-relaxed">
                            You need to be securely logged in to apply for this residence and manage your applications.
                        </p>
                        <div className="flex gap-4">
                            <button 
                                onClick={() => setShowLoginPrompt(false)}
                                className="flex-1 py-3.5 rounded-xl bg-slate-100 text-slate-600 font-bold text-sm hover:bg-slate-200 transition-colors"
                            >
                                Cancel
                            </button>
                            <button 
                                onClick={redirectToLogin}
                                className="flex-1 py-3.5 rounded-xl bg-red-700 text-white font-bold text-sm shadow-lg shadow-red-900/20 hover:bg-red-800 transition-colors"
                            >
                                Login
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Document Upload Modal */}
            {showUploadModal && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md animate-in fade-in duration-200">
                    <div className="bg-white/95 backdrop-blur-3xl p-8 md:p-10 rounded-[32px] border border-white/40 shadow-2xl max-w-lg w-full">
                        <div className="w-16 h-16 bg-red-50 text-red-700 rounded-2xl flex items-center justify-center mb-6 shadow-sm border border-red-100">
                            <FolderOpen className="w-8 h-8" />
                        </div>
                        <h3 className="text-2xl font-black text-slate-900 mb-2">Missing Documents</h3>
                        <p className="text-slate-600 font-medium text-sm mb-8 leading-relaxed">
                            To maintain community security, please upload your verification documents before applying.
                        </p>
                        
                        <div className="space-y-4 mb-8">
                            {missingDocs.id && (
                                <div className={`relative p-4 rounded-2xl border-2 transition-all ${idFile ? 'border-emerald-500 bg-emerald-50' : 'border-dashed border-slate-300 bg-slate-50 hover:bg-slate-100'}`}>
                                    <input 
                                        type="file" 
                                        accept=".pdf, .jpg, .jpeg, .png"
                                        onChange={(e) => setIdFile(e.target.files ? e.target.files[0] : null)}
                                        className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                                    />
                                    <div className="flex items-center gap-4">
                                        <div className={`p-2 rounded-xl ${idFile ? 'bg-emerald-500 text-white' : 'bg-white text-slate-400 shadow-sm border border-slate-200'}`}>
                                            {idFile ? <CheckCircle className="w-5 h-5"/> : <UploadCloud className="w-5 h-5"/>}
                                        </div>
                                        <div className="overflow-hidden">
                                            <p className={`font-bold text-sm truncate ${idFile ? 'text-emerald-900' : 'text-slate-700'}`}>
                                                {idFile ? idFile.name : 'Upload ID Document'}
                                            </p>
                                            {!idFile && <p className="text-[10px] text-slate-500 uppercase tracking-widest font-bold mt-0.5">Required</p>}
                                        </div>
                                    </div>
                                </div>
                            )}

                            {missingDocs.proof && (
                                <div className={`relative p-4 rounded-2xl border-2 transition-all ${proofFile ? 'border-emerald-500 bg-emerald-50' : 'border-dashed border-slate-300 bg-slate-50 hover:bg-slate-100'}`}>
                                    <input 
                                        type="file" 
                                        accept=".pdf, .jpg, .jpeg, .png"
                                        onChange={(e) => setProofFile(e.target.files ? e.target.files[0] : null)}
                                        className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                                    />
                                    <div className="flex items-center gap-4">
                                        <div className={`p-2 rounded-xl ${proofFile ? 'bg-emerald-500 text-white' : 'bg-white text-slate-400 shadow-sm border border-slate-200'}`}>
                                            {proofFile ? <CheckCircle className="w-5 h-5"/> : <UploadCloud className="w-5 h-5"/>}
                                        </div>
                                        <div className="overflow-hidden">
                                            <p className={`font-bold text-sm truncate ${proofFile ? 'text-emerald-900' : 'text-slate-700'}`}>
                                                {proofFile ? proofFile.name : 'Proof of Registration'}
                                            </p>
                                            {!proofFile && <p className="text-[10px] text-slate-500 uppercase tracking-widest font-bold mt-0.5">Required</p>}
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>

                        <div className="flex gap-4">
                            <button 
                                onClick={() => { setShowUploadModal(false); setIsApplying(false); }}
                                className="px-6 py-4 rounded-xl bg-slate-100 text-slate-600 font-bold text-sm hover:bg-slate-200 transition-colors"
                            >
                                Cancel
                            </button>
                            <button 
                                onClick={handleDocumentUpload}
                                disabled={isApplying || (missingDocs.id && !idFile) || (missingDocs.proof && !proofFile)}
                                className="flex-1 py-4 rounded-xl bg-gradient-to-r from-red-800 to-red-700 text-white font-black text-sm uppercase tracking-wider shadow-lg shadow-red-900/20 hover:from-red-900 hover:to-red-800 transition-all disabled:opacity-50 disabled:shadow-none flex justify-center items-center gap-2"
                            >
                                {isApplying ? <><Loader2 className="w-5 h-5 animate-spin"/> UPLOADING...</> : 'UPLOAD & APPLY'}
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Success Celebration Modal */}
            {applicationSuccess && (
                <div className="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-slate-900/80 backdrop-blur-md animate-in zoom-in duration-300">
                    <div className="bg-white p-10 rounded-[40px] shadow-2xl max-w-sm w-full text-center relative overflow-hidden">
                        <div className="absolute top-0 left-0 w-full h-2 bg-emerald-500"></div>
                        <div className="w-24 h-24 bg-emerald-50 text-emerald-500 rounded-full flex items-center justify-center mx-auto mb-6 shadow-inner">
                            <CheckCircle2 className="w-12 h-12" />
                        </div>
                        <h3 className="text-3xl font-black text-slate-900 mb-2">WOW! 🎉</h3>
                        <p className="text-slate-600 font-medium text-base mb-2">
                            Application submitted successfully!
                        </p>
                        <p className="text-slate-400 font-medium text-sm">
                            Redirecting you to the home page...
                        </p>
                    </div>
                </div>
            )}
        </div>
    );
}