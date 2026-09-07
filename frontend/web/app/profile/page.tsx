"use client";

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { 
    ArrowLeft, 
    Mail, 
    Phone, 
    Building2, 
    Layers, 
    BedDouble, 
    Heart, 
    ShieldCheck, 
    FileText, 
    LogOut, 
    Trash2,
    KeyRound,
    UserCircle,
    Loader2,
    CheckCircle2,
    XCircle,
    ExternalLink
} from 'lucide-react';
import { apiFetch, BASE_URL } from '../components/api';
import { auth } from '../firebase/config';
import { getIdToken, onAuthStateChanged, signOut } from 'firebase/auth';

interface StudentProfile {
    id: string;
    name: string;
    surname: string;
    email: string;
    student_number: string;
    phone?: string;
    accommodation_name?: string;
    block_name?: string;
    room_number_only?: string;
    face_url?: string;
}

export default function ProfilePage() {
    const router = useRouter();
    const [user, setUser] = useState<any>(null);
    const [profile, setProfile] = useState<StudentProfile | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [isLoadingFace, setIsLoadingFace] = useState(false);
    const [faceImage, setFaceImage] = useState<string | null>(null);
    const [error, setError] = useState<string>('');
    const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
    const [isDeleting, setIsDeleting] = useState(false);

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
            if (!firebaseUser) {
                router.push('/login');
                return;
            }
            setUser(firebaseUser);
            try {
                const token = await getIdToken(firebaseUser);
                const profileData = await fetchProfile(token);
                setProfile(profileData);
                if (profileData?.id) {
                    fetchFaceImage(profileData.id, token);
                }
            } catch (err) {
                console.error("Failed to fetch profile:", err);
                setError('Could not load profile.');
            } finally {
                setIsLoading(false);
            }
        });

        return () => unsubscribe();
    }, [router]);

    const fetchProfile = async (token: string): Promise<StudentProfile> => {
        const res = await apiFetch('/students/me/', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json',
            }
        });
        return res;
    };

    const fetchFaceImage = async (studentId: string, token: string) => {
        setIsLoadingFace(true);
        try {
            const response = await fetch(`${BASE_URL}/students/${studentId}/decrypted-face/`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                }
            });
            if (response.ok) {
                const data = await response.json();
                if (data.face_base64) {
                    setFaceImage(`data:image/jpeg;base64,${data.face_base64}`);
                }
            }
        } catch (e) {
            console.error("Error fetching face:", e);
        } finally {
            setIsLoadingFace(false);
        }
    };

    const handleLogout = async () => {
        await signOut(auth);
        router.push('/');
    };
 
    const handleDeleteAccount = async () => {
        if (!profile?.id) return;
        setIsDeleting(true);
        try {
            const token = await getIdToken(user);
            const response = await apiFetch(`/students/${profile.id}/`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                }
            });
            if (response.ok) {
                await user.delete();
                router.push('/');
            } else {
                alert('Failed to delete account.');
            }
        } catch (e) {
            console.error("Delete error:", e);
            alert('An error occurred while deleting your account.');
        } finally {
            setIsDeleting(false);
            setShowDeleteConfirm(false);
        }
    };

    if (isLoading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-blue-50">
                <Loader2 className="w-12 h-12 text-red-600 animate-spin" />
            </div>
        );
    }

    if (error || !profile) {
        return (
            <div className="min-h-screen flex items-center justify-center p-6">
                <div className="bg-white rounded-3xl p-10 text-center shadow-xl max-w-md w-full">
                    <XCircle className="w-16 h-16 text-rose-500 mx-auto mb-4" />
                    <h2 className="text-2xl font-black text-slate-900">Unable to load profile</h2>
                    <p className="text-slate-500 mt-2">{error}</p>
                    <button onClick={() => router.push('/')} className="mt-6 bg-slate-900 text-white px-6 py-3 rounded-xl">Go Home</button>
                </div>
            </div>
        );
    }

    const initials = `${profile.name.charAt(0)}${profile.surname.charAt(0)}`.toUpperCase();

    return (
        <div className="min-h-screen bg-blue-50">
            {/* Top Navigation */}
            <div className="fixed top-0 left-0 w-full z-40 bg-white/80 backdrop-blur-xl border-b border-slate-200/50">
                <div className="max-w-5xl mx-auto px-6 py-4 flex justify-between items-center">
                    <button onClick={() => router.back()} className="p-2 rounded-xl hover:bg-slate-100 transition">
                        <ArrowLeft className="w-6 h-6 text-slate-700" />
                    </button>
                    <h1 className="text-xs font-black text-slate-700 uppercase tracking-widest">My Profile</h1>
                    <div className="w-8"></div>
                </div>
            </div>

            <div className="pt-24 pb-20 px-6 max-w-5xl mx-auto">
                {/* Avatar Section */}
                <div className="flex flex-col items-center mb-12">
                    <div className="relative">
                        <div className="absolute -inset-2 rounded-full bg-gradient-to-tr from-red-500 to-rose-400 opacity-20 blur-lg"></div>
                        <div className="relative w-32 h-32 rounded-full border-4 border-white shadow-xl overflow-hidden bg-slate-100">
                            {faceImage ? (
                                <img src={faceImage} alt="Profile" className="w-full h-full object-cover" />
                            ) : isLoadingFace ? (
                                <div className="flex items-center justify-center h-full">
                                    <Loader2 className="w-8 h-8 text-slate-400 animate-spin" />
                                </div>
                            ) : (
                                <div className="flex items-center justify-center h-full bg-red-100">
                                    <span className="text-4xl font-black text-red-700">{initials}</span>
                                </div>
                            )}
                        </div>
                    </div>
                    <h2 className="text-3xl font-black text-slate-900 mt-4">{profile.name} {profile.surname}</h2>
                    <p className="text-slate-500 font-bold text-sm mt-1">{profile.student_number}</p>
                </div>

                {/* Personal Information */}
                <SectionTitle icon={<Mail className="w-4 h-4" />} title="Personal Information" />
                <InfoCard>
                    <InfoRow icon={<Mail className="w-5 h-5 text-slate-400" />} label="Email" value={profile.email} />
                    <Divider />
                    <InfoRow icon={<Phone className="w-5 h-5 text-slate-400" />} label="Phone" value={profile.phone || 'N/A'} />
                </InfoCard>

                {/* Accommodation Details */}
                <SectionTitle icon={<Building2 className="w-4 h-4" />} title="Accommodation Details" />
                <InfoCard>
                    <InfoRow icon={<Building2 className="w-5 h-5 text-slate-400" />} label="Property" value={profile.accommodation_name || 'Unassigned'} />
                    <Divider />
                    <InfoRow icon={<Layers className="w-5 h-5 text-slate-400" />} label="Block" value={profile.block_name || 'Unassigned'} />
                    <Divider />
                    <InfoRow icon={<BedDouble className="w-5 h-5 text-slate-400" />} label="Room" value={profile.room_number_only || 'Unassigned'} />
                </InfoCard>

                {/* Emergency & Medical */}
                <SectionTitle icon={<Heart className="w-4 h-4" />} title="Emergency & Medical" color="text-rose-600" />
                <InfoCard>
                    <ActionRow
                        icon={<Heart className="w-5 h-5 text-rose-500" />}
                        title="Medical Profile"
                        subtitle="Update health & contact info"
                        onClick={() => router.push('/medical')}
                        color="text-rose-600"
                    />
                </InfoCard>

                {/* Settings & Legal */}
                <SectionTitle icon={<ShieldCheck className="w-4 h-4" />} title="Settings & Legal" />
                <InfoCard>
                      
                    <ActionRow
                        icon={<FileText className="w-5 h-5 text-slate-500" />}
                        title="Terms & Conditions"
                        subtitle="Read our rules & policies"
                        onClick={() => window.open('https://mst.mktechcloud.co.za/terms-and-conditions', '_blank')}
                    />
                    <Divider />
                    <ActionRow
                        icon={<ShieldCheck className="w-5 h-5 text-slate-500" />}
                        title="Privacy Policy"
                        subtitle="How we handle your data"
                        onClick={() => window.open('https://mst.mktechcloud.co.za/privacy-policy', '_blank')}
                    />
                    <Divider />
                    <ActionRow
                        icon={<Trash2 className="w-5 h-5 text-rose-500" />}
                        title="Delete Account"
                        subtitle="Irreversibly wipe your profile data"
                        onClick={() => setShowDeleteConfirm(true)}
                        color="text-rose-600"
                    />
                </InfoCard>

                {/* Logout Button */}
                <button
                    onClick={handleLogout}
                    className="w-full mt-12 py-4 rounded-2xl bg-red-50 border border-red-200 text-red-600 font-black text-sm uppercase tracking-wider hover:bg-red-100 transition flex items-center justify-center gap-2"
                >
                    <LogOut className="w-5 h-5" />
                    Sign Out Securely
                </button>
            </div>

            {/* Delete Confirmation Modal */}
            {showDeleteConfirm && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
                    <div className="bg-white rounded-[32px] p-8 shadow-2xl max-w-md w-full">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="p-3 bg-rose-50 rounded-2xl">
                                <Trash2 className="w-6 h-6 text-rose-600" />
                            </div>
                            <h3 className="text-xl font-black text-slate-900">Delete Account</h3>
                        </div>
                        <p className="text-slate-600 mb-8 leading-relaxed">
                            This will permanently erase your student profile, biometric records, and all associated data. This action is irreversible.
                        </p>
                        <div className="flex gap-4">
                            <button
                                onClick={() => setShowDeleteConfirm(false)}
                                className="flex-1 py-3 rounded-xl bg-slate-100 text-slate-600 font-bold hover:bg-slate-200 transition"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={handleDeleteAccount}
                                disabled={isDeleting}
                                className="flex-1 py-3 rounded-xl bg-rose-600 text-white font-bold hover:bg-rose-700 transition disabled:opacity-50 disabled:shadow-none"
                            >
                                {isDeleting ? <Loader2 className="w-5 h-5 animate-spin mx-auto" /> : 'Delete Permanently'}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

// ====== Helper Components ======

function SectionTitle({ icon, title, color = "text-slate-700" }: { icon: React.ReactNode; title: string; color?: string }) {
    return (
        <div className="flex items-center gap-2 mb-3 mt-10">
            <div className="p-1.5 bg-slate-100 rounded-lg">
                {icon}
            </div>
            <h3 className={`text-[11px] font-black uppercase tracking-widest ${color}`}>{title}</h3>
        </div>
    );
}

function InfoCard({ children }: { children: React.ReactNode }) {
    return (
        <div className="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="divide-y divide-slate-100">{children}</div>
        </div>
    );
}

function InfoRow({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
    return (
        <div className="flex items-center gap-4 px-6 py-4">
            <div className="text-slate-400">{icon}</div>
            <div className="flex-1">
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{label}</p>
                <p className="text-sm font-bold text-slate-800 mt-0.5">{value}</p>
            </div>
        </div>
    );
}

function ActionRow({ icon, title, subtitle, onClick, color = "text-slate-700" }: { icon: React.ReactNode; title: string; subtitle: string; onClick: () => void; color?: string }) {
    return (
        <button
            onClick={onClick}
            className="w-full flex items-center gap-4 px-6 py-4 hover:bg-slate-50 transition text-left"
        >
            <div className={`p-2 rounded-xl ${color} bg-slate-100`}>{icon}</div>
            <div className="flex-1">
                <p className="text-sm font-black text-slate-800">{title}</p>
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">{subtitle}</p>
            </div>
            <ExternalLink className="w-4 h-4 text-slate-400" />
        </button>
    );
}

function Divider() {
    return <div className="border-t border-slate-100" />;
}