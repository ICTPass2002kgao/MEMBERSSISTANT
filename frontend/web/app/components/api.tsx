
export const BASE_URL = 'https://memberssistant.up.railway.app/api'; 

// Helper to retrieve and decode a cookie by name
const getCookie = (name: string): string | null => {
    if (typeof document === 'undefined') return null;
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) {
        const cookieValue = parts.pop()?.split(';').shift();
        return cookieValue ? decodeURIComponent(cookieValue) : null;
    }
    return null;
};

export const apiFetch = async (endpoint: string, options: any = {}) => {
  // Extract token from document.cookie instead of localStorage
  const token = getCookie('fb_id_token');

  const headers: any = { 
    ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    ...options.headers,
  };
  
  if (!(options.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
  }
  
  const response = await fetch(`${BASE_URL}${endpoint}`, { ...options, headers });
  
  if (response.status === 401 || response.status === 403) {
      console.error(`Auth/Permission Error on ${endpoint}`);
      // Ensure this only runs on the client to avoid SSR hydration errors
      if (typeof window !== 'undefined') {
          window.location.href = '/';
      }
  }
  
  if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      throw new Error(errData.error || `API Error: ${response.status}`);
  }
  
  return response.json();
};