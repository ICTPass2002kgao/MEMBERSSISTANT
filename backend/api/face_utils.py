

import tempfile
import base64
import cv2
import numpy as np
from cryptography.fernet import Fernet
from firebase_admin import storage
from django.conf import settings

import os
import json
import numpy as np
import cv2
from cryptography.fernet import Fernet
import firebase_admin
from firebase_admin import credentials, storage
from insightface.app import FaceAnalysis
from django.conf import settings


# Assume cipher_suite and GLOBAL_FACE_APP are initialized in your apps.py or __init__.py 
# as we discussed previously. 

# ==========================================
# 1. INITIALIZATION (Security, Firebase, AI)
# ==========================================

# A. Encryption Setup
try:
    if hasattr(settings, 'FERNET_KEY') and settings.FERNET_KEY:
        cipher_suite = Fernet(settings.FERNET_KEY)
    else:
        print("⚠️ WARNING: No FERNET_KEY found in settings.")
        cipher_suite = None
except Exception as e:
    print(f"❌ Encryption Init Failed: {e}")
    cipher_suite = None

# B. InsightFace Model (Loaded once into RAM)
try:
    GLOBAL_FACE_APP = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
    GLOBAL_FACE_APP.prepare(ctx_id=0)
    print("✅ InsightFace model loaded successfully.")
except Exception as e:
    GLOBAL_FACE_APP = None
    print(f"❌ Error loading InsightFace: {e}")

# C. Firebase Initialization
if not firebase_admin._apps:
    firebase_config = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if firebase_config:
        try:
            if os.path.exists(str(firebase_config)):
                cred = credentials.Certificate(firebase_config)
            else:
                cred_dict = json.loads(firebase_config)
                cred = credentials.Certificate(cred_dict)

            bucket_name = getattr(settings, 'FIREBASE_STORAGE_BUCKET', 'membersisstant.firebasestorage.app')
            firebase_admin.initialize_app(cred, {'storageBucket': bucket_name})
            print(f"✅ Firebase initialized: {bucket_name}")
        except Exception as e:
            print(f"❌ Firebase Init Error: {e}")


def encrypt_and_upload_to_firebase(file_obj, folder="encrypted_faces"):
    """
    1. Reads the raw image file.
    2. Encrypts it using Fernet.
    3. Uploads securely to Firebase.
    4. Returns the storage path.
    """
    if not cipher_suite: return None
    try:
        file_data = file_obj.read()
        encrypted_data = cipher_suite.encrypt(file_data)
        
        bucket = storage.bucket()
        filename = f"{folder}/{os.urandom(16).hex()}.enc"
        blob = bucket.blob(filename)
        
        # Uploading without make_public() keeps it secure
        blob.upload_from_string(encrypted_data, content_type='application/octet-stream')
        return filename
    except Exception as e:
        print(f"Encryption Upload Error: {e}")
        return None

def decrypt_from_firebase_to_temp(storage_path):
    """
    1. Downloads the .enc file from Firebase.
    2. Decrypts it.
    3. Writes to a temporary file on disk.
    4. Returns the path to the temp file.
    """
    if not cipher_suite: return None
    try:
        bucket = storage.bucket()
        blob = bucket.blob(storage_path)
        encrypted_data = blob.download_as_bytes()
        
        decrypted_data = cipher_suite.decrypt(encrypted_data)
        
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        temp_file.write(decrypted_data)
        temp_file.close()
        
        return temp_file.name
    except Exception as e:
        print(f"Decryption Error: {e}")
        return None

def decrypt_to_base64(storage_path):
    """
    BONUS HELPER: Use this when you want to send the decrypted image 
    straight to Flutter for display without saving it to the server's disk.
    """
    if not cipher_suite: return None
    try:
        bucket = storage.bucket()
        blob = bucket.blob(storage_path)
        encrypted_data = blob.download_as_bytes()
        
        decrypted_data = cipher_suite.decrypt(encrypted_data)
        return base64.b64encode(decrypted_data).decode('utf-8')
    except Exception as e:
        print(f"Base64 Decryption Error: {e}")
        return None

def perform_verification(live_path, ref_path, is_encrypted_ref=True):
    """
    1. Takes the live photo and the reference photo.
    2. Extracts embeddings using InsightFace.
    3. Compares them and returns the match result.
    """
    if GLOBAL_FACE_APP is None: return {'matched': False, 'error': 'AI Engine Down'}
    
    real_ref_path = ref_path
    temp_files_to_clean = []
    
    try:
        if is_encrypted_ref:
            real_ref_path = decrypt_from_firebase_to_temp(ref_path)
            if not real_ref_path: return {'matched': False, 'error': 'Decryption failed'}
            temp_files_to_clean.append(real_ref_path)

        def get_embedding(path):
            img = cv2.imread(path)
            if img is None: return None
            faces = GLOBAL_FACE_APP.get(img)
            if not faces: return None
            faces = sorted(faces, key=lambda x: (x.bbox[2]-x.bbox[0]) * (x.bbox[3]-x.bbox[1]), reverse=True)
            return faces[0].embedding

        emb_live = get_embedding(live_path)
        emb_ref = get_embedding(real_ref_path)
        
        if emb_live is None or emb_ref is None: 
            return {'matched': False, 'error': 'Face not detected'}
        
        # Calculate similarity
        sim = np.dot(emb_live, emb_ref) / (np.linalg.norm(emb_live) * np.linalg.norm(emb_ref))
        return {'matched': bool(sim > 0.50), 'score': float(sim)}
        
    except Exception as e:
        return {'matched': False, 'error': str(e)}
    finally:
        # ALWAYS clean up temp files to prevent server storage from filling up
        for p in temp_files_to_clean:
            if os.path.exists(p): os.remove(p)