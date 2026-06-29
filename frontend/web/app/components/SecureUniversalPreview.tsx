"use client";

import React, { useState, useEffect } from 'react';
import { Loader2, Image as ImageIcon } from 'lucide-react';
import { apiFetch } from './api';

export default function SecureUniversalPreview({ encryptedUrl, className = "w-full h-full object-cover" }: { encryptedUrl: string, className?: string }) {
    const [imgSrc, setImgSrc] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(false);

    useEffect(() => {
        const fetchDecryptedFile = async () => {
            if (!encryptedUrl) return;

            try {
                // Grab the current auth token from local storage
                const token = localStorage.getItem('access_token'); // Ensure this matches your token key
                
                // Fetch the raw bytes from your universal Django endpoint
                const response = await apiFetch(`/serve-decrypted-file/?token=${token}&file_url=${encodeURIComponent(encryptedUrl)}`);
                
                if (!response.ok) throw new Error("Failed to decrypt image");

                // Convert the raw bytes into a temporary browser object URL
                const blob = await response.blob();
                const objectUrl = URL.createObjectURL(blob);
                
                setImgSrc(objectUrl);
            } catch (err) {
                setError(true);
            } finally {
                setLoading(false);
            }
        };

        fetchDecryptedFile();

        // Cleanup function to free browser memory when the image is removed from the screen
        return () => {
            if (imgSrc) URL.revokeObjectURL(imgSrc);
        };
    }, [encryptedUrl]);

    if (loading) {
        return (
            <div className={`bg-slate-100 flex items-center justify-center ${className}`}>
                <Loader2 className="animate-spin text-slate-400" size={24} />
            </div>
        );
    }

    if (error || !imgSrc) {
        return (
            <div className={`bg-slate-100 flex flex-col items-center justify-center text-slate-400 ${className}`}>
                <ImageIcon size={32} className="mb-2" />
                <span className="text-[10px] font-black uppercase tracking-widest">Preview Failed</span>
            </div>
        );
    }

    return <img src={imgSrc} alt="Secure Preview" className={className} />;
}