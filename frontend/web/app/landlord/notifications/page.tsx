"use client";

import React, { useEffect, useState } from "react";
import { Bell, CheckCircle2, Circle, Loader2, AlertCircle } from "lucide-react";
import { apiFetch } from "../../components/api"; // Adjust path to match your structure
import { SectionHeader } from "../../components/SharedUI"; // Adjust path

type Notification = {
    id: string;
    title: string;
    message: string;
    created_at: string;
    is_read: boolean;
};

export default function LandlordNotificationsPage() {
    const [notifications, setNotifications] = useState<Notification[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchNotifications();
    }, []);

    const fetchNotifications = async () => {
        setLoading(true);
        try {
            // Your backend automatically filters this by the authenticated landlord's token
            const data = await apiFetch("/notifications/");
            const results = data.results || data || [];
            setNotifications(results);
        } catch (e) {
            console.error("Failed to fetch notifications", e);
            setNotifications([]);
        }
        setLoading(false);
    };

    const markAsRead = async (id: string, is_read: boolean) => {
        if (is_read) return; // Already read, do nothing

        // Optimistically update the UI instantly
        setNotifications((prev) =>
            prev.map((n) => (n.id === id ? { ...n, is_read: true } : n))
        );

        try {
            // Call the custom action defined in your Django NotificationViewSet
            await apiFetch(`/notifications/${id}/mark_read/`, { method: "POST" });
        } catch (error) {
            console.error("Failed to mark as read", error);
            // Revert on failure
            setNotifications((prev) =>
                prev.map((n) => (n.id === id ? { ...n, is_read: false } : n))
            );
        }
    };

    const unreadCount = notifications.filter((n) => !n.is_read).length;

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
            {/* Header Section */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="System Notifications" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        Tracking: {unreadCount} Unread Alerts
                    </p>
                </div>
            </div>

            {/* Notifications Container */}
            <div className="bg-white border border-blue-100 rounded-[28px] shadow-sm overflow-hidden p-2">
                {loading ? (
                    <div className="py-24 flex flex-col items-center justify-center text-blue-500">
                        <Loader2 className="animate-spin mb-4" size={32} />
                        <span className="text-[10px] font-black uppercase tracking-widest text-slate-400">
                            Syncing Alerts...
                        </span>
                    </div>
                ) : notifications.length === 0 ? (
                    <div className="py-24 flex flex-col items-center justify-center text-center">
                        <div className="w-16 h-16 bg-slate-50 text-slate-300 rounded-full flex items-center justify-center mb-4">
                            <Bell size={24} />
                        </div>
                        <p className="text-slate-400 font-bold uppercase tracking-widest italic text-sm">
                            You have no notifications.
                        </p>
                    </div>
                ) : (
                    <ul className="space-y-2">
                        {notifications.map((n) => (
                            <li
                                key={n.id}
                                onClick={() => markAsRead(n.id, n.is_read)}
                                className={`p-5 rounded-2xl border transition-all cursor-pointer group flex items-start gap-4 ${
                                    n.is_read
                                        ? "bg-transparent border-transparent hover:bg-slate-50"
                                        : "bg-blue-50/50 border-blue-100 hover:bg-blue-50 shadow-sm"
                                }`}
                            >
                                <div className="mt-1 shrink-0">
                                    {n.is_read ? (
                                        <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-slate-400">
                                            <CheckCircle2 size={16} strokeWidth={2.5} />
                                        </div>
                                    ) : (
                                        <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-500 shadow-sm shadow-blue-500/20">
                                            <AlertCircle size={16} strokeWidth={2.5} className="animate-pulse" />
                                        </div>
                                    )}
                                </div>
                                <div className="flex-1">
                                    <div className="flex items-center justify-between gap-4">
                                        <div className="flex items-center gap-2">
                                            <span className={`font-black text-sm ${n.is_read ? 'text-slate-600' : 'text-blue-950'}`}>
                                                {n.title}
                                            </span>
                                            {!n.is_read && (
                                                <span className="px-2 py-0.5 rounded text-[9px] font-black uppercase tracking-widest bg-blue-600 text-white shadow-sm">
                                                    New
                                                </span>
                                            )}
                                        </div>
                                        <div className="text-[10px] font-bold tracking-widest text-slate-400 uppercase shrink-0">
                                            {new Date(n.created_at).toLocaleDateString(undefined, { 
                                                month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' 
                                            })}
                                        </div>
                                    </div>
                                    <div className={`text-sm mt-1.5 leading-relaxed ${n.is_read ? 'text-slate-400 font-medium' : 'text-slate-600 font-bold'}`}>
                                        {n.message}
                                    </div>
                                </div>
                            </li>
                        ))}
                    </ul>
                )}
            </div>
        </div>
    );
}
