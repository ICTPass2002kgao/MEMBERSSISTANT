
export const BASE_URL = 'https://memberssistant.up.railway.app/api'; 

// export const BASE_URL = 'http://127.0.0.1:8000/api'; 
 

// export const BASE_URL = 'http://127.0.0.1:8000/api';

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
  const token = getCookie('fb_id_token');

  const headers: any = { 
    ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    ...options.headers,
  };
  
  if (!(options.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
  }
  
  const response = await fetch(`${BASE_URL}${endpoint}`, { ...options, headers });
  
  // Only redirect on auth errors for endpoints that require login
  if (response.status === 401 || response.status === 403) {
      const publicEndpoints = ['/accommodations/', '/accommodations', '/student-self-register/', '/login/', '/register/'];
      const isPublic = publicEndpoints.some(e => endpoint.startsWith(e));
      if (!isPublic) {
          console.error(`Auth/Permission Error on ${endpoint}`); 
          if (typeof window !== 'undefined') {
              window.location.href = '/';
          }
      }
  }
  
  if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      throw new Error(errData.error || `API Error: ${response.status}`);
  }
  
  return response.json();
};
export async function sendEmail(receiver: string, title: string, message: string): Promise<boolean> {
  try {
    const url = 'https://api-w6yanm6o4q-uc.a.run.app/sendCustomEmail';
    const currentYear = new Date().getFullYear();
    const formattedMessage = message.replace(/\n/g, '<br/>');
    const htmlBody = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 550px; margin: 0 auto; background-color: #020617; padding: 16px; border-radius: 24px;">
        <div style="background-color: #0f172a; border: 1px solid #1e293b; border-radius: 18px; overflow: hidden; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);">
          <div style="padding: 16px 20px; border-bottom: 1px solid #1e293b; background: linear-gradient(to right, #0f172a, #1e293b); text-align: left;">
            <img src="https://firebasestorage.googleapis.com/v0/b/membersisstant.firebasestorage.app/o/FCMImages%2Fmemberssistant_icon.png?alt=media&token=01c986f2-5504-497b-bd75-e271edb4abf7" alt="Memberssistant Logo" style="max-height: 45px; margin-bottom: 10px; border-radius: 6px; display: block;">
            <h1 style="color: #ffffff; margin: 0; font-size: 18px; font-weight: 800; letter-spacing: 0.5px;">Memberssistant</h1>
            <p style="color: #64748b; margin: 2px 0 0 0; font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase;">System Notification</p>
          </div>
          <div style="padding: 20px; color: #f1f5f9; background-color: #0f172a;">
            <h2 style="color: #3b82f6; margin-top: 0; margin-bottom: 12px; font-size: 15px; font-weight: 700; letter-spacing: 0.3px;">${title.toUpperCase()}</h2>
            <div style="font-size: 14px; line-height: 1.5; color: #cbd5e1; margin: 0;">${formattedMessage}</div>
          </div>
          <div style="padding: 16px 20px; background-color: #090d16; border-top: 1px solid #1e293b; text-align: center;">
            <a href="https://mst.mktechcloud.co.za/terms-and-conditions" style="color: #94a3b8; text-decoration: none; font-size: 11px; font-weight: 600; margin: 0 8px; display: inline-block;">Terms & Conditions</a>
            <span style="color: #334155; font-size: 11px;">•</span>
            <a href="https://mst.mktechcloud.co.za/privacy-policy" style="color: #94a3b8; text-decoration: none; font-size: 11px; font-weight: 600; margin: 0 8px; display: inline-block;">Privacy Policy</a>
            <span style="color: #334155; font-size: 11px;">•</span>
            <a href="https://mst.mktechcloud.co.za/contact-support" style="color: #3b82f6; text-decoration: none; font-size: 11px; font-weight: 700; margin: 0 8px; display: inline-block;">Contact Us</a>
            <p style="margin: 12px 0 0 0; color: #475569; font-size: 10px; font-weight: 500; letter-spacing: 0.2px;">&copy; ${currentYear} MK TECHCLOUD (Pty) Ltd. All rights reserved.</p>
          </div>
        </div>
      </div>
    `;

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: receiver,
        subject: title,
        body: htmlBody,
        attachmentUrl: "",
      }),
    });

    return response.ok;
  } catch (e) {
    console.error('Exception sending email:', e);
    return false;
  }
}