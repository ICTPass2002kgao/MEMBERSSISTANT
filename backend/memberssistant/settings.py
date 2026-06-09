"""
Django settings for memberssistant project.
"""

import os
import json
from pathlib import Path
from dotenv import load_dotenv
import dj_database_url

import firebase_admin
from firebase_admin import credentials 

BASE_DIR = Path(__file__).resolve().parent.parent 
load_dotenv(os.path.join(BASE_DIR, '.env')) 

SECRET_KEY = os.environ.get('SECRET_KEY', 'fallback-key-do-not-use-in-production') 
DEBUG = os.environ.get('DEBUG', 'False') == 'True' 

# 1. HOST & CORS SECURITY FIX
# No more wildcards. Explicitly define your domains in your server's environment variables.
allowed_hosts_env = os.environ.get('ALLOWED_HOSTS', '127.0.0.1,localhost')
ALLOWED_HOSTS = [host.strip() for host in allowed_hosts_env.split(',') if host.strip()]

cors_origins_env = os.environ.get('CORS_ALLOWED_ORIGINS', 'http://localhost:3000,http://127.0.0.1:3000')
CORS_ALLOWED_ORIGINS = [origin.strip() for origin in cors_origins_env.split(',') if origin.strip()]

# Critical for React -> Django POST requests (Login/Register)
CSRF_TRUSTED_ORIGINS = CORS_ALLOWED_ORIGINS 

PAYSTACK_API_BASE = 'https://api.paystack.co'

# Application definition
INSTALLED_APPS = [
    'simpleui',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',  
    'rest_framework',
    'django_filters',
    'api',
]

STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  
    'django.middleware.security.SecurityMiddleware', 
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'memberssistant.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [os.path.join(BASE_DIR, 'templates')],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'memberssistant.wsgi.application'


# 2. STRICT DATABASE ENFORCEMENT FIX
DB_URL = os.environ.get('DATABASE_URL', '').strip()

if DEBUG and not DB_URL:
    # Only allow SQLite fallback if we are strictly in local development
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
else:
    # If in production, crash loudly if the Database URL is missing. No silent fallbacks.
    if not DB_URL:
        raise ValueError("CRITICAL ERROR: DATABASE_URL environment variable is missing in production!")
    
    DATABASES = {
        'default': dj_database_url.parse(
            DB_URL,
            conn_max_age=600,
            conn_health_checks=True,
        )
    }

# 3. PRODUCTION SECURITY FLAGS
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True


# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# 4. STATIC FILES FIX
STATIC_URL = 'static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Dynamically check if the 'static' folder exists to prevent deployment warnings
static_dir = os.path.join(BASE_DIR, 'static')
if os.path.exists(static_dir):
    STATICFILES_DIRS = [static_dir]
else:
    STATICFILES_DIRS = []


# Firebase & Environment Keys
PAYSTACK_SECRET_KEY = os.environ.get('PAYSTACK_SECRET_KEY')
FIREBASE_STORAGE_BUCKET = os.environ.get('FIREBASE_STORAGE_BUCKET', 'membersisstant.firebasestorage.app')
FERNET_KEY = os.environ.get('FERNET_KEY') 

if not firebase_admin._apps:
    firebase_creds_json = os.environ.get('FIREBASE_CREDENTIALS_JSON')
    
    if firebase_creds_json:
        creds_dict = json.loads(firebase_creds_json)
        cred = credentials.Certificate(creds_dict)
    else:
        firebase_creds_path = os.environ.get('FIREBASE_CREDENTIALS_PATH', os.path.join(BASE_DIR, 'serviceAccountKey.json'))
        cred = credentials.Certificate(firebase_creds_path)
        
    firebase_admin.initialize_app(cred, {
        'storageBucket': FIREBASE_STORAGE_BUCKET
    })