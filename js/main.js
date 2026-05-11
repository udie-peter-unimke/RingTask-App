// Import Firebase modules
import { initializeApp } from "https://www.gstatic.com/firebasejs/12.7.0/firebase-app.js";
import {
  getFirestore,
  collection,
  addDoc,
  doc,
  setDoc,
  serverTimestamp
} from "https://www.gstatic.com/firebasejs/12.7.0/firebase-firestore.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/12.7.0/firebase-auth.js";
import { getAnalytics, logEvent } from "https://www.gstatic.com/firebasejs/12.7.0/firebase-analytics.js";

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyDr6v2MvNpRmYK5WXDA3Ubp5lwBBW6jP7g",
  authDomain: "ringtask-a30dd.firebaseapp.com",
  projectId: "ringtask-a30dd",
  storageBucket: "ringtask-a30dd.firebasestorage.app",
  messagingSenderId: "909170843494",
  appId: "1:909170843494:web:50cb12428e0ea5480432a7",
  measurementId: "G-RRRTV82MFQ"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth(app);
const analytics = getAnalytics(app);

console.log("Firebase initialized");

// Wait for DOM
document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("waitlist-form");
  const emailInput = document.getElementById("email");
  const submitButton = form.querySelector("button[type='submit']");

  // Submit handler
  form.addEventListener("submit", async (e) => {
    e.preventDefault();

    const email = emailInput.value.trim();
    if (!isValidEmail(email)) {
      showError("Please enter a valid email address");
      return;
    }

    submitButton.disabled = true;
    submitButton.textContent = "Saving your spot...";

    try {
      const result = await submitToWaitlist(email);

      if (result.success) {
        trackEvent("waitlist_joined", { email });

        // Show simple success message below the button
        showSuccessMessage();
        submitButton.textContent = "Joined!";
      }
    } catch (error) {
      console.error("Error details:", error);

      if (error.message.includes("already exists")) {
        showError("This email is already on the waitlist!");
      } else {
        showError("Something went wrong. Please try again.");
      }

      submitButton.disabled = false;
      submitButton.textContent = "Join Waitlist";
    }
  });

  // Copy waitlist link to clipboard
  async function copyWaitlistLink() {
    const button = document.getElementById("copy-link-btn");
    const currentUrl = window.location.href;
    
    try {
      await navigator.clipboard.writeText(currentUrl);
      
      const originalHTML = button.innerHTML;
      button.classList.add("copied");
      button.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3"
            d="M5 13l4 4L19 7" />
        </svg>
        <span>Link Copied!</span>
      `;
      
      trackEvent("referral_link_copied", { url: currentUrl });
      
      setTimeout(() => {
        button.classList.remove("copied");
        button.innerHTML = originalHTML;
      }, 2000);
      
    } catch (err) {
      console.error("Failed to copy:", err);
      showError("Failed to copy link. Please try again.");
    }
  }

  // Email validation
  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  // Firestore submission (secure)
  async function submitToWaitlist(email) {
    // Option A: simple add (matches your write-only rules)
    await addDoc(collection(db, "waitlist"), {
      email,
      createdAt: serverTimestamp()
    });

    // Option B: enforce unique emails using email as document ID
    // await setDoc(doc(db, "waitlist", email), {
    //   email,
    //   createdAt: serverTimestamp()
    // });

    return { success: true };
  }

  // Error display
  function showError(message) {
    let errorEl = document.getElementById("error-message");

    if (!errorEl) {
      errorEl = document.createElement("p");
      errorEl.id = "error-message";
      errorEl.style.cssText = `
        color: #dc2626;
        font-weight: 600;
        margin-top: 15px;
        padding: 12px;
        background: #fee2e2;
        border-radius: 8px;
        font-size: 0.9rem;
      `;
      form.appendChild(errorEl);
    }

    errorEl.textContent = message;
    errorEl.style.display = "block";

    setTimeout(() => {
      errorEl.style.display = "none";
    }, 4000);
  }

  // Success message
  function showSuccessMessage() {
    let successEl = document.getElementById("success-message");

    if (!successEl) {
      successEl = document.createElement("p");
      successEl.id = "success-message";
      successEl.style.cssText = `
        color: #16a34a;
        font-weight: 600;
        margin-top: 15px;
        padding: 12px;
        background: #dcfce7;
        border-radius: 8px;
        font-size: 0.9rem;
      `;
      form.appendChild(successEl);
    }

    successEl.textContent = "You’ve been added to the waitlist!";
    successEl.style.display = "block";
  }

  // Analytics
  function trackEvent(name, data) {
    logEvent(analytics, name, data);
  }

  trackEvent("page_view", { page: "landing" });

  emailInput.addEventListener("focus", () => {
    trackEvent("email_focus", { element: "waitlist_form" });
  });
});

// Smooth scroll
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener("click", e => {
    e.preventDefault();
    const target = document.querySelector(anchor.getAttribute("href"));
    if (target) {
      target.scrollIntoView({ behavior: "smooth" });
    }
  });
});
