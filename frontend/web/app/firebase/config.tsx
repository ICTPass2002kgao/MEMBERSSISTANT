// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";  
import { getStorage } from "firebase/storage"; // 1. Add the Storage import

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyC-LvxuyDxwi_kfXmdxBOVHHguzx9_8LH4",
  authDomain: "membersisstant.firebaseapp.com",
  projectId: "membersisstant",
  storageBucket: "membersisstant.firebasestorage.app",
  messagingSenderId: "160946575033",
  appId: "1:160946575033:web:d05e364ff470d0db9bad68"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);  
const storage = getStorage(app); // 2. Initialize the Storage instance

// 3. Export storage along with app and auth
export { app, auth, storage };