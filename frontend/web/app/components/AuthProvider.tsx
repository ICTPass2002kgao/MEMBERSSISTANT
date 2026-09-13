"use client";

import { useEffect, useState, useRef, createContext, useContext } from "react";
import { onAuthStateChanged, signInAnonymously, User } from "firebase/auth";
import { auth } from "@/app/firebase/config";

const AuthContext = createContext<{ user: User | null; ready: boolean }>({
  user: null,
  ready: false,
});

export const useAuth = () => useContext(AuthContext);

export default function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);
  const signingInRef = useRef(false); // 👈 prevents duplicate sign-in calls

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        setUser(firebaseUser);
        setReady(true);
        return;
      }

      // No user → sign in anonymously ONCE
      if (signingInRef.current) return;
      signingInRef.current = true;

      try {
        await signInAnonymously(auth);
        // onAuthStateChanged will re-fire with the new user
      } catch (err) {
        console.error("Anonymous sign-in failed:", err);
        setReady(true); // let the app render even if auth fails
      } finally {
        signingInRef.current = false;
      }
    });

    return () => unsubscribe();
  }, []); // 👈 empty array — this is the key

  return (
    <AuthContext.Provider value={{ user, ready }}>
      {children}
    </AuthContext.Provider>
  );
}