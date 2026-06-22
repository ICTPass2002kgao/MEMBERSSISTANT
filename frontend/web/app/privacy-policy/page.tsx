// PrivacyPolicy.jsx
import React from "react";
import Head from "next/head";

export default function PrivacyPolicy() {
  return (
    <>
      <Head>
        <title>Privacy Policy | Memberssistant</title>
        <meta
          name="description"
          content="Memberssistant Privacy Policy explaining how we collect, process, protect and manage personal information."
        />
      </Head>

      <div className="min-h-screen bg-slate-50 py-10 px-4">
        <main className="max-w-5xl mx-auto bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
          <div className="px-8 py-10 sm:px-12 sm:py-16">
            <div className="mb-12 border-b border-slate-200 pb-8">
              <h1 className="text-4xl font-black text-slate-900">
                Privacy Policy
              </h1>
              <p className="mt-4 text-sm font-semibold text-slate-500 uppercase tracking-widest">
                Last Updated: June 2026
              </p>
            </div>

            <article className="prose prose-slate prose-lg max-w-none text-slate-600">
              <p className="text-xl font-medium text-slate-700">
                Memberssistant ("we", "our", or "the Platform") respects your
                privacy and is committed to protecting your personal information.
                This Privacy Policy explains how we collect, use, store,
                protect, and share information when you use our residence
                management platform.
              </p>
              <p>
                This policy is designed to comply strictly with applicable data
                protection laws, specifically including the Protection of Personal
                Information Act (POPIA) of South Africa.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                1. Information We Collect
              </h2>
              <p>
                Depending on your interaction with Memberssistant, we may
                collect the following categories of information:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>
                  <strong>Identity Information:</strong> Name, surname,
                  student number, government identification, profile details,
                  and direct contact information.
                </li>
                <li>
                  <strong>Biometric Information:</strong> Facial recognition
                  data, biometric templates, verification records, and related
                  authentication logs utilized exclusively for secure identity
                  verification.
                </li>
                <li>
                  <strong>Medical Information:</strong> Optional health-related
                  data such as severe allergies, chronic medical conditions, emergency
                  contacts, or blood type, provided strictly on a voluntary basis.
                </li>
                <li>
                  <strong>Location Information:</strong> GPS location data, accessed
                  only when explicitly required for emergency assistance, panic features, or
                  authorized geographic platform functions.
                </li>
                <li>
                  <strong>Residence Information:</strong> Room allocations,
                  lease details, visitor logs, maintenance requests, and physical
                  access history.
                </li>
                <li>
                  <strong>Technical Information:</strong> Device identifiers,
                  application usage telemetry, authentication logs, and broader system
                  activity records.
                </li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                2. How We Use Your Information
              </h2>
              <p>
                Memberssistant processes personal information strictly for
                legitimate business and operational purposes, which include:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Executing secure identity verification through advanced biometric matching.</li>
                <li>Managing day-to-day residence operations and accommodation services.</li>
                <li>Providing immediate emergency response routing and functionality.</li>
                <li>Facilitating official communication between residents, landlords, residence staff, and authorized security personnel.</li>
                <li>Maintaining comprehensive security records and immutable access history.</li>
                <li>Analyzing telemetry to improve platform performance and overall user experience.</li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                3. Biometric Data Processing
              </h2>
              <p>
                Memberssistant leverages advanced biometric technology to provide definitive, secure
                identity verification and prevent unauthorized property access.
              </p>
              <p>
                Biometric information is legally classified as sensitive personal
                information. We process this data exclusively for the purposes of security,
                authentication, fraud prevention, and access management.
              </p>
              <p>
                We absolutely do not sell, rent, broker, or utilize biometric information for
                advertising, marketing, or any unrelated commercial purposes.
              </p>
              <p>
                Users acknowledge that while biometric verification drastically improves physical security,
                no digital security system can guarantee absolute, infallible protection against every possible highly-sophisticated threat.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                4. Medical Information & Emergency Access
              </h2>
              <p>
                Memberssistant allows users to voluntarily input medical
                information that may critically assist verified first responders during emergency situations.
              </p>
              <p>
                This medical information is heavily protected. Access is strictly restricted to
                authorized medical or security personnel, and only when there is a legitimate, triggered emergency
                event.
              </p>
              <p>
                Access to this sensitive emergency data is explicitly logged and recorded for
                security auditing, compliance, and accountability purposes.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                5. Security & Encryption Measures
              </h2>
              <p>
                Memberssistant implements robust technical and organizational security
                measures engineered to protect personal information against unauthorized access or data breaches.
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Sensitive personal and biometric information is encrypted at rest and in transit.</li>
                <li>Strict Role-Based Access Controls (RBAC) limit information visibility exclusively to authorized user roles.</li>
                <li>Multi-layered authentication systems are deployed to prevent unauthorized account access.</li>
                <li>Comprehensive security logs are actively maintained to monitor and audit critical actions performed within the platform ecosystem.</li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                6. Third-Party Service Providers
              </h2>
              <p>
                Memberssistant engages vetted, enterprise-grade third-party providers to operate
                specific technical infrastructure.
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>
                  <strong>Cloud Infrastructure:</strong> Utilized for
                  secure hosting, authentication scaling, database management, and push notifications.
                </li>
                <li>
                  <strong>Payment Gateways:</strong> Engaged to securely process
                  financial transactions. Memberssistant does not store complete payment
                  card numbers or CVV codes on our servers.
                </li>
                <li>
                  <strong>Communication Providers:</strong> Engaged for the delivery of
                  mission-critical SMS notifications, emails, and platform communications.
                </li>
              </ul>
              <p>
                These enterprise providers process information strictly according to their own rigorous
                security practices and legally binding Data Processing Agreements (DPAs).
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                7. Sharing of Information
              </h2>
              <p>
                Memberssistant unequivocally does not sell your personal information.
              </p>
              <p>Information may only be shared with the following entities:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Your specific accommodation provider or explicitly authorized residence management personnel.</li>
                <li>Verified emergency responders or private security firms during an active crisis.</li>
                <li>Technical service providers strictly necessary to operate the Platform infrastructure.</li>
                <li>Law enforcement or regulatory authorities, but only where legally mandated by a valid subpoena or court order.</li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                8. Data Retention
              </h2>
              <p>
                We retain personal information only for the duration necessary
                to fulfill operational, security, legal, and contractual obligations.
              </p>
              <p>
                When personal information is no longer legally or operationally required, we take
                immediate, mathematically secure steps to permanently delete or fully anonymize it.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                9. Your Privacy Rights
              </h2>
              <p>
                Under the Protection of Personal Information Act (POPIA) and applicable laws, you hold the following rights:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Requesting a transparent record of the specific personal information we hold about you.</li>
                <li>Requesting the immediate correction of inaccurate, outdated, or incomplete information.</li>
                <li>Requesting the deletion or destruction of your data where legally permissible and not in conflict with lease retention laws.</li>
                <li>Requesting detailed documentation regarding how your data is processed and routed.</li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                10. Account Security Responsibilities
              </h2>
              <p>
                Users bear the final responsibility for protecting their account credentials, PINs, and devices. You must immediately report any suspected unauthorized access or hardware loss to platform administration.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                11. Children's Privacy
              </h2>
              <p>
                Memberssistant is strictly intended for adult users, university students, and individuals who are legally permitted
                to enter into binding accommodation agreements and utilize unmonitored residence services.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                12. Changes To This Privacy Policy
              </h2>
              <p>
                Memberssistant reserves the right to update this Privacy Policy to reflect evolving legal or technical requirements. Users will be formally notified of significant, material changes via the Platform prior to their implementation.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                13. Contact Information
              </h2>
              <p>
                For privacy-related questions, data access requests, POPIA compliance inquiries, or security concerns, please
                contact Memberssistant directly through the official support channels
                available within the Platform dashboard.
              </p>
            </article>
          </div>
        </main>
      </div>
    </>
  );
}
