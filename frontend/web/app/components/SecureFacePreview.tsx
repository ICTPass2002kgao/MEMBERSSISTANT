"use client";

import React, { useState, useEffect } from 'react';
import { Loader2, User } from 'lucide-react';
import { apiFetch } from './../components/api'; 

export default function SecureFacePreview({ studentId, className = "w-12 h-12 rounded-full object-cover shadow-sm" }: { studentId: string, className?: string }) {
    const [imgSrc, setImgSrc] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(false);

    useEffect(() => {
        const fetchFace = async () => {
            if (!studentId) return;
            
            try {
                // Hits your Django endpoint that returns the base64 JSON
                const response = await apiFetch(`/students/${studentId}/decrypted-face/`, { method: 'GET' });
                
                if (response && response.face_base64) {
                    // Formats the base64 string so the browser renders it as a live image
                    setImgSrc(`data:image/jpeg;base64,${response.face_base64}`);
                } else {
                    setError(true);
                }
            } catch (err) {
                setError(true);
            } finally {
                setLoading(false);
            }
        };

        fetchFace();
    }, [studentId]);

    if (loading) {
        return (
            <div className={`bg-slate-100 flex items-center justify-center animate-pulse border border-slate-200 ${className}`}>
                <Loader2 className="animate-spin text-slate-400" size={16} />
            </div>
        );
    }

    if (error || !imgSrc) {
        return (
            <div className={`bg-slate-100 flex items-center justify-center border border-slate-200 ${className}`}>
                <User className="text-slate-400" size={20} />
            </div>
        );
    }

    return <img src={imgSrc} alt="Decrypted Biometric Preview" className={className} />;
}