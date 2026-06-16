export const BASE_URL = 'https://memberssistant.up.railway.app/api'; 

export const apiFetch = async (endpoint: string, options: any = {}) => {
  const token = localStorage.getItem('fb_id_token');

  const headers = { 
    ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    ...options.headers,
  };
if (!(options.body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
}
  const response = await fetch(`${BASE_URL}${endpoint}`, { ...options, headers });
  
  if (response.status === 401 || response.status === 403) {
    console.error(`Auth/Permission Error on ${endpoint}`);
      window.location.href = '/';
  }
  
  if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      throw new Error(errData.error || `API Error: ${response.status}`);
  }
  
  return response.json();
};