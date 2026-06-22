
// TermsAndConditions.jsx
import React from "react";
import Head from "next/head";

export default function TermsAndConditions() {
  return (
    <>
      <Head>
        <title>Terms & Conditions | Memberssistant</title>
        <meta
          name="description"
          content="Memberssistant Terms and Conditions governing the use of our residence management platform."
        />
      </Head>

      <div className="min-h-screen bg-slate-50 py-10 px-4">
        <main className="max-w-5xl mx-auto bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
          <div className="px-8 py-10 sm:px-12 sm:py-16">
            <div className="mb-12 border-b border-slate-200 pb-8">
              <h1 className="text-4xl font-black text-slate-900">
                Terms & Conditions
              </h1>
              <p className="mt-4 text-sm font-semibold text-slate-500 uppercase tracking-widest">
                Last Updated: June 2026
              </p>
            </div>

            <article className="prose prose-slate prose-lg max-w-none text-slate-600">
              <p className="text-xl font-medium text-slate-700">
                Welcome to Memberssistant. These Terms and Conditions ("Terms")
                legally govern your access to and use of the Memberssistant platform,
                mobile application, web dashboard, and all related technological services
                (collectively, the "Platform").
              </p>
              <p>
                By creating an account, accessing the Platform, submitting
                information, utilizing our security features, or interacting with any
                service provided through Memberssistant, you explicitly acknowledge that you have
                read, understood, and agreed to be bound by these Terms in their entirety.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                1. Introduction and Scope
              </h2>
              <p>
                Memberssistant is a specialized technology platform designed to streamline and secure
                residence management through digital administration, biometric security verification,
                communication utilities, emergency assistance protocols, maintenance reporting, and student accommodation oversight.
              </p>
              <p>
                <strong>Disclaimer:</strong> Memberssistant provides software infrastructure only. We do not
                assume or replace the legal, physical, or operational responsibilities of landlords, residence
                managers, private security companies, state emergency responders, medical
                professionals, or property owners.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                2. User Accounts and Registration
              </h2>
              <p>
                To access the Platform's core features, users are required to create a registered account and provide truthful, current, and accurate personal information, including but not limited to:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Full legal name and surname</li>
                <li>Valid email address and active mobile number</li>
                <li>Residence details and room allocation data</li>
                <li>Government-issued identity verification documentation</li>
              </ul>
              <p>
                You are entirely responsible for maintaining the strict confidentiality of
                your account credentials. Any activity conducted under your account is your legal responsibility. You must immediately notify
                Memberssistant of any suspected unauthorized access or security breaches.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                3. Biometric Identity Verification
              </h2>
              <p>
                Memberssistant incorporates advanced biometric technologies (such as facial
                recognition mapping) to ensure definitive identity verification and strictly enforce physical security within managed properties.
              </p>
              <p>
                By enabling biometric verification, you provide explicit consent to the
                secure collection, processing, and storage of your biometric data strictly for
                authentication, access control, and fraud prevention purposes. All processing complies with the Protection of Personal Information Act (POPIA).
              </p>
              <p>
                Any attempt to bypass, manipulate, duplicate, or digitally spoof the biometric verification systems constitutes a severe violation of these Terms and may result in immediate platform bans, eviction, and potential legal action.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                4. Digital Gate Passes and Security Access
              </h2>
              <p>
                Memberssistant generates digital access tools, including dynamic QR
                codes, digital visitor permits, and mobile verification systems.
              </p>
              <p>Users agree to the following strict security stipulations:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Gate passes and digital access codes belong exclusively to the assigned, registered user.</li>
                <li>Sharing, screenshotting, or distributing access credentials to unauthorized individuals is strictly prohibited.</li>
                <li>Attempting to tailgate or bypass physical security barriers using digital tools will result in severe disciplinary action from residence management.</li>
                <li>Final security and access decisions ultimately remain the jurisdiction of the on-site property management and private security personnel.</li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                5. Emergency Services and Panic Features
              </h2>
              <p>
                The Platform features emergency assistance utilities,
                including integrated panic buttons, live GPS location sharing, and automated emergency
                notifications dispatched to responders or management.
              </p>
              <p>
                Users acknowledge that Memberssistant acts solely as a technological conduit and absolutely cannot guarantee:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>The physical response times or dispatch metrics of external emergency personnel.</li>
                <li>Uninterrupted cellular network or Wi-Fi availability during a crisis.</li>
                <li>Pinpoint GPS accuracy, which relies heavily on your specific device hardware and environment.</li>
                <li>The operational availability of external private or state-funded responders.</li>
              </ul>
              <p>
                <strong>Strict Warning:</strong> The deliberate false activation of emergency features, abuse of panic services, or
                intentionally misleading alerts diverts critical life-saving resources. Such actions will result in immediate account termination, eviction procedures, and liability for any incurred dispatch costs.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                6. Medical Information
              </h2>
              <p>
                Users are afforded the option to voluntarily store critical medical data (e.g., blood type, severe allergies, chronic illnesses) to aid emergency responders.
              </p>
              <p>
                Memberssistant does not provide medical advice, diagnosis, or
                treatment. By utilizing this feature, you authorize the display of this data to verified responders strictly during an active, verified emergency event.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                7. Payments and Financial Services
              </h2>
              <p>
                Certain functions, penalties, or property fees (such as lost key fees, residence charges, damages, or specific in-app purchases) may require financial transactions.
              </p>
              <p>
                All payments are securely processed through vetted third-party payment
                gateways. Memberssistant acts solely as a payment facilitator for the property management. We are not
                liable for financial disputes, refund authorizations, chargebacks, or lease-related disagreements between you and your accommodation provider.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                8. Maintenance Requests and Communication
              </h2>
              <p>
                Users may submit property maintenance tickets via the Platform. All information and photographic evidence provided must be truthful and accurately depict the issue.
              </p>
              <p>
                Memberssistant serves strictly as the administrative ticketing system and explicitly does not guarantee repair timelines, vendor quality, or physical resolution, as these are managed entirely by the landlord or property managers.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                9. Acceptable Use and Prohibited Conduct
              </h2>
              <p>
                While utilizing the Platform, you strictly agree not to:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Use the Platform for any unlawful, fraudulent, malicious, or highly dangerous activities.</li>
                <li>Upload viruses, malware, trojans, or deploy scraping/bot mechanisms to extract data.</li>
                <li>Attempt unauthorized access (hacking) into other user accounts, administrative dashboards, or underlying server databases.</li>
                <li>Reverse engineer, decompile, or unlawfully copy the Platform's proprietary source code or algorithms.</li>
                <li>Harass, threaten, or abuse residence staff, property management, or other users through the Platform's communication channels.</li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                10. Data Protection and Privacy
              </h2>
              <p>
                Your privacy is paramount. Memberssistant processes personal information responsibly and
                implements high-grade technical and organizational security
                measures. Comprehensive details regarding our data practices can be found in our standalone Privacy Policy, which is incorporated by reference into these Terms.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                11. Intellectual Property
              </h2>
              <p>
                All software architecture, UI/UX designs, trademarks, logos, branding, databases,
                algorithms, and technology powering Memberssistant remain the exclusive
                intellectual property of Memberssistant (and its licensors).
              </p>
              <p>
                You are granted a limited, non-exclusive, non-transferable license to use the Platform. You may not copy, modify, distribute, sell, or reproduce any
                part of the software without explicit written legal consent from our executive team.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                12. Indemnification
              </h2>
              <p>
                You agree to indemnify, defend, and hold harmless Memberssistant, its officers, directors, employees, and affiliates from any claims, liabilities, damages, losses, or expenses (including reasonable legal fees) arising out of your violation of these Terms, your misuse of the Platform, or your violation of any third-party rights.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                13. Suspension and Termination
              </h2>
              <p>
                Memberssistant comprehensively reserves the right to suspend or permanently terminate
                your access to the Platform, without prior notice, if you:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Violate any primary or secondary provision of these Terms.</li>
                <li>Compromise or attempt to compromise the integrity of the platform's security.</li>
                <li>Misuse, spoof, or abuse emergency/security features.</li>
                <li>Are legally evicted or physically removed from the managed residence by the property owner.</li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                14. Limitation of Liability
              </h2>
              <p>
                To the absolute maximum extent permitted by South African law, Memberssistant shall
                not be held liable for any indirect, incidental, special, consequential, or punitive damages, including loss of profits, data, or physical property, resulting from:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Internet outages, hardware failures, API downtime, or software glitches.</li>
                <li>The actions, inactions, or gross negligence of third-party security or medical responders.</li>
                <li>Unauthorized physical access to your premises due to user negligence or hardware bypass.</li>
                <li>The reliance on the Platform during a life-threatening emergency.</li>
              </ul>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                15. Force Majeure
              </h2>
              <p>
                Memberssistant shall not be liable for any failure or delay in performance under these Terms due to circumstances beyond our reasonable control, including but not limited to natural disasters, acts of government, power grid failures (e.g., severe load shedding), severe network telecommunications outages, or cyber-warfare.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                16. Third-Party Services
              </h2>
              <p>
                The Platform frequently integrates with third-party ecosystems including
                payment providers, cloud hosting, SMS gateways, and physical IoT security hardware.
                These independent services operate according to their own Terms of Service and Privacy Policies, which Memberssistant does not directly control or accept liability for.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                17. Governing Law and Jurisdiction
              </h2>
              <p>
                These Terms shall be exclusively governed by and construed in accordance with the laws of the Republic of South
                Africa. Any legal disputes shall be subject to the exclusive jurisdiction of the South African courts, though both parties agree to attempt good-faith mediation prior to instituting formal litigation.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                18. Severability
              </h2>
              <p>
                If any provision of these Terms is found to be unenforceable or invalid under any applicable law, such unenforceability or invalidity shall not render these Terms unenforceable or invalid as a whole, and such provisions shall be deleted without affecting the remaining legally binding provisions herein.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                19. Changes to These Terms
              </h2>
              <p>
                Memberssistant maintains the right to update these Terms from time to time to reflect operational, legal, or regulatory changes.
                Continued use of the Platform after changes have been communicated and published means you unequivocally accept the
                updated Terms.
              </p>

              <h2 className="text-2xl font-bold text-slate-900 mt-10 mb-4">
                20. Contact Information
              </h2>
              <p>
                For questions regarding these Terms, legal disputes, or formal notices, please contact
                Memberssistant through the official support channels provided
                within the Platform or via our corporate contact protocols.
              </p>
            </article>
          </div>
        </main>
      </div>
    </>
  );
}