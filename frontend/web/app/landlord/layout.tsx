
"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Building2,
  Users,
  User,
  Wrench,
  CreditCard,
  LogOut,
  Bell,
  Search,
  UserCog,
  MessageCircleIcon,
  Fingerprint,
  ClipboardCheck,
  SparkleIcon,
  QrCode,
  Menu,
  X,
  Activity,
  MapIcon,
  AlertTriangle,
  Printer,
  ShieldAlert,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { apiFetch } from "../components/api";

export default function LandlordLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();

  const [landlordName, setLandlordName] = useState("Administrator");
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [isVerified, setIsVerified] = useState<boolean | null>(null);
  const [isPaymentDue, setIsPaymentDue] = useState(false);

  const [invoiceData, setInvoiceData] = useState<{
    items: { name: string; count: number }[];
    totalStudents: number;
    amountDue: number;
    issueDate: string;
    dueDate: string;
  }>({
    items: [],
    totalStudents: 0,
    amountDue: 0,
    issueDate: "",
    dueDate: "",
  });

  const RATE_PER_STUDENT = 28.0;

  const [badges, setBadges] = useState({
    maintenance: 0,
    permits: 0,
    applications: 0,
    notifications: 0,
  });

  /* ---------------------------------------------------------
     CLOSE MOBILE MENU WHEN ROUTE CHANGES
  --------------------------------------------------------- */
  useEffect(() => {
    setIsMobileMenuOpen(false);
  }, [pathname]);

  /* ---------------------------------------------------------
     ACCESS + BILLING
  --------------------------------------------------------- */
  useEffect(() => {
    const checkAccessAndBilling = async () => {
      const storedUserData = localStorage.getItem("user_data");

      if (storedUserData) {
        try {
          const parsedRaw = JSON.parse(storedUserData);
          const parsed = parsedRaw.user_data
            ? parsedRaw.user_data
            : parsedRaw;

          if (parsed.name) {
            setLandlordName(
              `${parsed.name} ${parsed.surname || ""}`.trim()
            );
          }

          if (parsed.is_verified !== undefined) {
            setIsVerified(Boolean(parsed.is_verified));
          }
        } catch (e) {}
      }

      try {
        const profile = await apiFetch("/landlords/me/");

        if (profile && (profile.id || profile.email)) {
          localStorage.setItem("user_data", JSON.stringify(profile));

          if (profile.name) {
            setLandlordName(
              `${profile.name} ${profile.surname || ""}`.trim()
            );
          }

          const verifiedStatus = profile.is_verified === true;
          setIsVerified(verifiedStatus);

          let trialExpired = false;

          if (profile.subscription_valid_until) {
            trialExpired =
              Date.now() >
              new Date(profile.subscription_valid_until).getTime();
          } else if (verifiedStatus) {
            const trialStart = new Date(
              profile.trial_start_date || Date.now()
            );

            trialExpired =
              Math.floor(
                (Date.now() - trialStart.getTime()) /
                  (1000 * 60 * 60 * 24)
              ) > 30;
          }

          if (verifiedStatus && trialExpired) {
            setIsPaymentDue(true);

            try {
              const studentsData = await apiFetch("/students/");
              const students =
                studentsData.results || studentsData || [];

              const grouped = students.reduce(
                (acc: Record<string, number>, student: any) => {
                  const accName =
                    student.accommodation_name ||
                    "Unassigned Accommodation";

                  if (!acc[accName]) {
                    acc[accName] = 0;
                  }

                  acc[accName]++;
                  return acc;
                },
                {}
              );

              const items = Object.keys(grouped).map((name) => ({
                name,
                count: grouped[name],
              }));

              const totalStudents = students.length;

              const today = new Date();

              const due = new Date(
                today.getTime() + 7 * 24 * 60 * 60 * 1000
              );

              setInvoiceData({
                items,
                totalStudents,
                amountDue: totalStudents * RATE_PER_STUDENT,
                issueDate: today.toLocaleDateString("en-ZA"),
                dueDate: due.toLocaleDateString("en-ZA"),
              });
            } catch (e) {}
          }
        }
      } catch (err) {
        if (
          err instanceof Error &&
          err.message.includes("403")
        ) {
          localStorage.clear();
          window.location.href = "/";
        }
      }
    };

    checkAccessAndBilling();
  }, [pathname]);

  /* ---------------------------------------------------------
     BADGES
  --------------------------------------------------------- */
  useEffect(() => {
    fetchBadgeCounts();

    const interval = setInterval(fetchBadgeCounts, 30000);

    return () => clearInterval(interval);
  }, []);

  const fetchBadgeCounts = async () => {
    try {
      const [
        issuesData,
        permitsData,
        studentsData,
        notificationsData,
      ] = await Promise.all([
        apiFetch("/issues/").catch(() => []),
        apiFetch("/leave-permits/").catch(() => []),
        apiFetch("/students/").catch(() => []),
        apiFetch("/notifications/").catch(() => []),
      ]);

      setBadges({
        maintenance: (
          issuesData.results ||
          issuesData ||
          []
        ).filter((i: any) => i.status === "PENDING").length,

        permits: (
          permitsData.results ||
          permitsData ||
          []
        ).filter((p: any) => p.status === "REQUESTED").length,

        applications: (
          studentsData.results ||
          studentsData ||
          []
        ).filter(
          (s: any) =>
            s.room === null &&
            !s.verification_status &&
            s.applied_accommodation_name != null
        ).length,

        notifications: (
          notificationsData.results ||
          notificationsData ||
          []
        ).filter((n: any) => n.is_read === false).length,
      });
    } catch (e) {}
  };

  /* ---------------------------------------------------------
     HELPERS
  --------------------------------------------------------- */
  const handleLogout = () => {
    localStorage.clear();
    window.location.href = "/";
  };

  const getPageTitle = () => {
    return (pathname.split("/").pop() || "dashboard").replace(
      "-",
      " "
    );
  };

  const handlePrintInvoice = () => {
    window.print();
  };

  /* ---------------------------------------------------------
     SIDEBAR ITEM
  --------------------------------------------------------- */
  const SidebarItem = ({
    icon: Icon,
    label,
    href,
    badgeCount,
  }: {
    icon: any;
    label: string;
    href: string;
    badgeCount?: number;
  }) => {
    const isActive = pathname === href;

    return (
      <Link
        href={href}
        title={isSidebarCollapsed ? label : undefined}
        className={`
          relative w-full flex items-center
          ${
            isSidebarCollapsed
              ? "justify-center p-3.5"
              : "justify-between px-4 sm:px-5 py-3.5"
          }
          rounded-xl
          transition-all duration-200
          group
          ${
            isActive
              ? "bg-blue-600 text-white shadow-md shadow-blue-600/20"
              : "text-slate-500 hover:text-blue-600 hover:bg-blue-50"
          }
        `}
      >
        <div className="flex items-center gap-3 min-w-0">
          <Icon
            size={18}
            className={`
              shrink-0
              ${
                isActive
                  ? "text-white"
                  : "text-slate-400 group-hover:text-blue-500"
              }
            `}
          />

          {!isSidebarCollapsed && (
            <span className="text-[10px] sm:text-[11px] font-bold tracking-tight uppercase truncate">
              {label}
            </span>
          )}
        </div>

        {badgeCount !== undefined && badgeCount > 0 ? (
          isSidebarCollapsed ? (
            <span className="absolute top-2 right-2 w-2 h-2 bg-rose-500 rounded-full shadow-sm shadow-rose-500/50 animate-pulse" />
          ) : (
            <span
              className={`
                shrink-0
                flex items-center justify-center
                min-w-[20px]
                h-5
                px-1.5
                rounded-lg
                text-[10px]
                font-black
                animate-in zoom-in duration-300
                ${
                  isActive
                    ? "bg-white text-blue-600"
                    : "bg-rose-500 text-white shadow-sm shadow-rose-500/30"
                }
              `}
            >
              {badgeCount > 99 ? "99+" : badgeCount}
            </span>
          )
        ) : null}
      </Link>
    );
  };

  /* ---------------------------------------------------------
     VERIFICATION SCREEN
  --------------------------------------------------------- */
  if (
    isVerified === false &&
    pathname !== "/landlord/profile"
  ) {
    return (
      <div className="min-h-screen bg-slate-50 flex items-center justify-center px-4 py-6 sm:p-6 overflow-x-hidden">
        <div
          className="
            w-full
            max-w-md
            bg-white
            rounded-[28px]
            sm:rounded-[32px]
            p-5
            sm:p-8
            shadow-2xl
            shadow-rose-900/10
            text-center
            border
            border-rose-100
          "
        >
          <div className="w-16 h-16 sm:w-20 sm:h-20 bg-rose-50 text-rose-600 rounded-full flex items-center justify-center mx-auto mb-5 sm:mb-6">
            <ShieldAlert
              size={32}
              className="sm:w-10 sm:h-10"
            />
          </div>

          <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight mb-3">
            Verification Required
          </h1>

          <p className="text-xs sm:text-sm text-slate-500 leading-relaxed font-medium mb-7 sm:mb-8">
            You are currently unverified. You have{" "}
            <strong className="text-rose-600">
              no authority
            </strong>{" "}
            to access the dashboard, manage students, or perform
            any administrative duties until your identity has
            been strictly verified.
          </p>

          <Link
            href="/landlord/profile"
            className="
              inline-flex
              items-center
              justify-center
              gap-2
              bg-blue-600
              text-white
              px-5
              py-3.5
              rounded-xl
              text-[10px]
              sm:text-xs
              font-black
              tracking-widest
              uppercase
              hover:bg-blue-700
              transition-all
              shadow-lg
              shadow-blue-500/30
              w-full
            "
          >
            <UserCog size={16} />
            Click here to verify
          </Link>
        </div>
      </div>
    );
  }

  /* ---------------------------------------------------------
     PAYMENT SCREEN
  --------------------------------------------------------- */
  if (
    isVerified === true &&
    isPaymentDue &&
    pathname !== "/landlord/profile"
  ) {
    return (
      <div className="min-h-screen bg-slate-100 flex py-4 px-3 sm:py-10 sm:px-6 lg:px-8 print:bg-white print:py-0 print:px-0 overflow-x-hidden">
        <div
          className="
            max-w-4xl
            w-full
            mx-auto
            bg-white
            rounded-2xl
            sm:rounded-3xl
            shadow-2xl
            overflow-hidden
            border
            border-slate-200
            print:shadow-none
            print:border-none
            print:rounded-none
          "
        >
          {/* INVOICE HEADER */}
          <div
            className="
              bg-slate-900
              p-5
              sm:p-8
              text-white
              flex
              flex-col
              sm:flex-row
              justify-between
              items-center
              gap-5
              sm:gap-6
              print:bg-white
              print:text-black
              print:border-b
              print:border-slate-300
            "
          >
            <div className="flex items-center justify-center sm:justify-start">
              <img
                src="/mktechcloud.png"
                alt="MK Techcloud Logo"
                className="h-12 sm:h-16 max-w-[160px] object-contain bg-white rounded-lg p-1"
              />
            </div>

            <div className="text-center sm:text-right min-w-0">
              <img
                src="/memberssistant_icon.png"
                alt="Memberssistant Logo"
                className="h-10 sm:h-12 max-w-[150px] object-contain mx-auto sm:ml-auto sm:mr-0 mb-2"
              />

              <h1 className="text-xl sm:text-2xl font-black tracking-widest uppercase">
                System Invoice
              </h1>

              <p className="text-slate-400 print:text-slate-500 text-[9px] sm:text-xs font-bold tracking-widest mt-1">
                ACCOUNT SUSPENDED - PAYMENT DUE
              </p>
            </div>
          </div>

          {/* INVOICE CONTENT */}
          <div className="p-4 sm:p-8 lg:p-12">
            {/* ALERT */}
            <div className="print:hidden mb-6 sm:mb-8 p-4 sm:p-5 bg-rose-50 border border-rose-200 rounded-2xl flex items-start gap-3 sm:gap-4 text-rose-800">
              <AlertTriangle
                size={22}
                className="shrink-0 mt-0.5"
              />

              <div className="min-w-0">
                <h3 className="font-black text-xs sm:text-sm tracking-tight mb-1">
                  Your 1-Month Free Trial Has Expired
                </h3>

                <p className="text-[11px] sm:text-xs font-medium leading-relaxed">
                  Your system access is currently locked due to
                  an outstanding balance. Please settle the
                  invoice below to instantly restore full access
                  to your accommodations and resident management
                  dashboard.
                </p>
              </div>
            </div>

            {/* BILLING INFORMATION */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 sm:gap-10 mb-8 sm:mb-10">
              <div className="min-w-0">
                <p className="text-[9px] sm:text-[10px] font-black tracking-widest text-slate-400 uppercase mb-2">
                  Billed To
                </p>

                <h3 className="font-black text-blue-950 text-base sm:text-lg break-words">
                  {landlordName}
                </h3>

                <p className="text-xs sm:text-sm font-medium text-slate-500 mt-1">
                  Registered Landlord / Administrator
                </p>
              </div>

              <div className="sm:text-right min-w-0">
                <p className="text-[9px] sm:text-[10px] font-black tracking-widest text-slate-400 uppercase mb-2">
                  Invoice Details
                </p>

                <div className="space-y-1 text-xs sm:text-sm">
                  <p className="font-bold text-slate-700">
                    Issue Date:
                    <span className="font-medium text-slate-500 ml-2">
                      {invoiceData.issueDate}
                    </span>
                  </p>

                  <p className="font-bold text-slate-700">
                    Due Date:
                    <span className="font-medium text-rose-600 ml-2">
                      {invoiceData.dueDate}
                    </span>
                  </p>

                  <p className="font-bold text-slate-700">
                    Platform Fee:
                    <span className="font-medium text-slate-500 ml-2">
                      R {RATE_PER_STUDENT.toFixed(2)} / Student
                    </span>
                  </p>
                </div>
              </div>
            </div>

            {/* STUDENT TABLE */}
            <div className="overflow-x-auto rounded-xl border border-slate-200 mb-8 sm:mb-10">
              <table className="w-full min-w-[520px] text-left">
                <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 text-[9px] sm:text-[10px] font-black uppercase tracking-widest">
                  <tr>
                    <th className="p-3 sm:p-4">
                      Accommodation Name
                    </th>

                    <th className="p-3 sm:p-4 text-center">
                      Total Students
                    </th>

                    <th className="p-3 sm:p-4 text-right">
                      Subtotal
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-slate-100">
                  {invoiceData.items.length === 0 ? (
                    <tr>
                      <td
                        colSpan={3}
                        className="p-6 text-center text-xs sm:text-sm font-medium text-slate-400"
                      >
                        No students registered yet.
                      </td>
                    </tr>
                  ) : (
                    invoiceData.items.map((item, idx) => (
                      <tr
                        key={idx}
                        className="text-xs sm:text-sm"
                      >
                        <td className="p-3 sm:p-4 font-bold text-slate-800 max-w-[220px] break-words">
                          {item.name}
                        </td>

                        <td className="p-3 sm:p-4 text-center font-medium text-slate-600">
                          {item.count}
                        </td>

                        <td className="p-3 sm:p-4 text-right font-black text-blue-900 whitespace-nowrap">
                          R{" "}
                          {(
                            item.count * RATE_PER_STUDENT
                          ).toFixed(2)}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>

                <tfoot>
                  <tr className="bg-blue-50/50">
                    <td
                      className="p-3 sm:p-4 font-black text-blue-950 text-right uppercase tracking-wider text-[9px] sm:text-xs"
                      colSpan={2}
                    >
                      Total Amount Due
                    </td>

                    <td className="p-3 sm:p-4 text-right font-black text-blue-700 text-base sm:text-lg whitespace-nowrap">
                      R {invoiceData.amountDue.toFixed(2)}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>

            {/* BANKING DETAILS */}
            <div className="bg-slate-50 rounded-2xl border border-slate-200 p-4 sm:p-6 lg:p-8">
              <h3 className="text-[10px] sm:text-xs font-black tracking-widest text-slate-800 uppercase mb-5 flex items-center gap-2">
                <CreditCard
                  size={16}
                  className="text-blue-500 shrink-0"
                />
                Banking Details for Payment
              </h3>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-x-8 sm:gap-y-4 text-xs sm:text-sm">
                {[
                  [
                    "Account Name",
                    "MK TECHCLOUD (Pty) Ltd",
                  ],
                  ["Bank", "FNB"],
                  [
                    "Account Type",
                    "FIRST BUSINESS ZERO ACCOUNT",
                  ],
                  ["Account Number", "63216882472"],
                  [
                    "Branch Name",
                    "PRESIDENT SQUARE VAAL",
                  ],
                  ["Branch Code", "252049"],
                  ["Swift Code", "FIRNZAJJ"],
                  ["Reference", landlordName],
                ].map(([label, value]) => (
                  <div
                    key={label}
                    className="flex flex-col xs:flex-row xs:justify-between gap-1 border-b border-slate-200 pb-2 min-w-0"
                  >
                    <span className="font-bold text-slate-500 shrink-0">
                      {label}
                    </span>

                    <span
                      className={`
                        font-black
                        text-right
                        break-words
                        ${
                          label === "Reference"
                            ? "text-rose-600"
                            : "text-slate-800"
                        }
                      `}
                    >
                      {value}
                    </span>
                  </div>
                ))}
              </div>

              <p className="text-[8px] sm:text-[10px] text-slate-400 mt-5 text-center uppercase tracking-widest font-bold leading-relaxed">
                Please send proof of payment to
                billing@memberssistant.com to lift the
                suspension.
              </p>
            </div>

            {/* ACTIONS */}
            <div className="print:hidden mt-6 sm:mt-8 flex flex-col-reverse sm:flex-row gap-3 sm:gap-4 justify-end">
              <button
                onClick={handleLogout}
                className="
                  w-full
                  sm:w-auto
                  px-6
                  py-3
                  rounded-xl
                  font-bold
                  text-xs
                  sm:text-sm
                  text-slate-500
                  bg-slate-100
                  hover:bg-slate-200
                  transition-colors
                  uppercase
                  tracking-wider
                "
              >
                Log Out
              </button>

              <button
                onClick={handlePrintInvoice}
                className="
                  w-full
                  sm:w-auto
                  flex
                  items-center
                  justify-center
                  gap-2
                  px-6
                  py-3
                  rounded-xl
                  font-black
                  text-xs
                  sm:text-sm
                  text-white
                  bg-blue-600
                  hover:bg-blue-700
                  transition-all
                  shadow-lg
                  shadow-blue-500/30
                  uppercase
                  tracking-widest
                "
              >
                <Printer size={18} />
                Download / Print Invoice
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  /* ---------------------------------------------------------
     MAIN LAYOUT
  --------------------------------------------------------- */
  return (
    <div className="min-h-screen w-full bg-blue-50 text-blue-950 font-sans flex overflow-x-hidden">
      {/* MOBILE OVERLAY */}
      {isMobileMenuOpen && (
        <div
          className="
            fixed
            inset-0
            bg-blue-950/30
            backdrop-blur-sm
            z-40
            lg:hidden
            animate-in
            fade-in
            duration-300
          "
          onClick={() => setIsMobileMenuOpen(false)}
        />
      )}

      {/* -----------------------------------------------------
          SIDEBAR
      ----------------------------------------------------- */}
      <aside
        className={`
          fixed
          inset-y-0
          left-0
          h-full
          flex
          flex-col
          border-r
          border-blue-100
          bg-white
          z-50
          shadow-[4px_0_24px_rgba(239,246,255,0.5)]
          transform
          transition-all
          duration-300
          ease-in-out

          w-[min(86vw,320px)]

          lg:static
          lg:translate-x-0

          ${
            isMobileMenuOpen
              ? "translate-x-0"
              : "-translate-x-full"
          }

          ${
            isSidebarCollapsed
              ? "lg:w-24"
              : "lg:w-72"
          }
        `}
      >
        {/* DESKTOP COLLAPSE BUTTON */}
        <button
          onClick={() =>
            setIsSidebarCollapsed(!isSidebarCollapsed)
          }
          className="
            hidden
            lg:flex
            absolute
            -right-3.5
            top-8
            w-7
            h-7
            bg-white
            border
            border-blue-100
            rounded-full
            items-center
            justify-center
            text-slate-400
            hover:text-blue-600
            shadow-md
            z-50
            transition-all
            hover:scale-110
          "
        >
          {isSidebarCollapsed ? (
            <ChevronRight size={16} />
          ) : (
            <ChevronLeft size={16} />
          )}
        </button>

        {/* SIDEBAR HEADER */}
        <div
          className={`
            px-5
            py-5
            sm:p-6
            lg:p-8
            flex
            items-center
            ${
              isSidebarCollapsed
                ? "lg:justify-center lg:px-0"
                : "justify-between"
            }
          `}
        >
          <div
            className={`
              flex
              items-center
              gap-3
              min-w-0
              ${
                isSidebarCollapsed
                  ? "lg:justify-center"
                  : ""
              }
            `}
          >
            <div className="w-9 h-9 bg-blue-600 rounded-xl flex items-center justify-center font-black text-white shadow-lg shadow-blue-500/30 shrink-0">
              TRC
            </div>

            {!isSidebarCollapsed && (
              <div className="whitespace-nowrap overflow-hidden min-w-0">
                <h1 className="text-sm font-black tracking-tight text-blue-950 uppercase truncate">
                  Memberssistant
                </h1>

                <p className="text-[9px] sm:text-[10px] text-blue-400 font-bold tracking-widest uppercase mt-0.5">
                  Landlord Portal
                </p>
              </div>
            )}
          </div>

          {/* MOBILE CLOSE */}
          <button
            onClick={() => setIsMobileMenuOpen(false)}
            className="
              lg:hidden
              p-2
              shrink-0
              text-slate-400
              hover:text-rose-500
              hover:bg-rose-50
              rounded-xl
              transition-all
            "
          >
            <X size={20} />
          </button>
        </div>

        {/* NAVIGATION */}
        <nav
          className={`
            flex-1
            ${
              isSidebarCollapsed
                ? "lg:px-3"
                : "px-3 sm:px-4"
            }
            space-y-1.5
            overflow-y-auto
            custom-scrollbar
            pb-6
          `}
        >
          <SidebarItem
            icon={LayoutDashboard}
            label="Overview"
            href="/landlord/dashboard"
          />

          <SidebarItem
            icon={Bell}
            label="Notifications"
            href="/landlord/notifications"
            badgeCount={badges.notifications}
          />

          <SidebarItem
            icon={Building2}
            label="Accommodations"
            href="/landlord/accommodations"
          />

          <SidebarItem
            icon={SparkleIcon}
            label="Applications"
            href="/landlord/applications"
            badgeCount={badges.applications}
          />

          {!isSidebarCollapsed ? (
            <div className="pt-4 pb-1 px-4 sm:px-5">
              <p className="text-[8px] sm:text-[9px] font-black text-slate-400 tracking-widest uppercase">
                Emergency & Medical
              </p>
            </div>
          ) : (
            <div className="pt-4 pb-1 w-full flex justify-center">
              <div className="w-4 h-[1px] bg-blue-100" />
            </div>
          )}

          <SidebarItem
            icon={Activity}
            label="Emergency Logs"
            href="/landlord/emergency-logs"
          />

          <SidebarItem
            icon={MapIcon}
            label="Res Map"
            href="/landlord/res-buildings-map"
          />

          <SidebarItem
            icon={Users}
            label="Students"
            href="/landlord/students"
          />

          <SidebarItem
            icon={UserCog}
            label="Attendants"
            href="/landlord/attendants"
          />

          <SidebarItem
            icon={Fingerprint}
            label="Students Verification"
            href="/landlord/students-verification"
          />

          <SidebarItem
            icon={Wrench}
            label="Maintenance"
            href="/landlord/maintenance"
            badgeCount={badges.maintenance}
          />

          <SidebarItem
            icon={QrCode}
            label="Gate Passes"
            href="/landlord/gate-passes"
          />

          <SidebarItem
            icon={ClipboardCheck}
            label="Exit Permits"
            href="/landlord/permits"
            badgeCount={badges.permits}
          />

          <SidebarItem
            icon={CreditCard}
            label="Finance"
            href="/landlord/finance"
          />

          <SidebarItem
            icon={MessageCircleIcon}
            label="Communication"
            href="/landlord/communication"
          />

          <SidebarItem
            icon={User}
            label="My Profile"
            href="/landlord/profile"
          />
        </nav>

        {/* LOGOUT */}
        <div className="p-3 sm:p-4 border-t border-blue-50 bg-white">
          <button
            onClick={handleLogout}
            className={`
              w-full
              flex
              items-center
              ${
                isSidebarCollapsed
                  ? "lg:justify-center"
                  : "gap-3 px-4"
              }
              py-3
              text-slate-400
              hover:text-rose-500
              hover:bg-rose-50
              rounded-xl
              transition-all
              text-[10px]
              sm:text-xs
              font-bold
            `}
          >
            <LogOut size={16} />

            {!isSidebarCollapsed && (
              <span>TERMINATE SESSION</span>
            )}
          </button>
        </div>
      </aside>

      {/* -----------------------------------------------------
          MAIN
      ----------------------------------------------------- */}
      <main
        className="
          flex-1
          h-screen
          overflow-y-auto
          overflow-x-hidden
          bg-white
          relative
          w-full
          min-w-0
        "
      >
        {/* HEADER */}
        <header
          className="
            sticky
            top-0
            z-30
            flex
            justify-between
            items-center
            gap-3
            px-3
            sm:px-5
            lg:px-8
            py-3
            sm:py-4
            lg:py-6
            backdrop-blur-xl
            bg-white/80
            border-b
            border-blue-100/50
            supports-[backdrop-filter]:bg-white/60
          "
        >
          {/* LEFT */}
          <div className="flex items-center gap-2 sm:gap-4 min-w-0">
            {/* MOBILE MENU */}
            <button
              onClick={() => setIsMobileMenuOpen(true)}
              className="
                lg:hidden
                p-2
                sm:p-2.5
                shrink-0
                bg-white
                border
                border-blue-100
                rounded-xl
                text-blue-600
                shadow-sm
                hover:bg-blue-50
                transition-all
              "
            >
              <Menu size={19} />
            </button>

            <div className="min-w-0">
              <h2
                className="
                  text-base
                  sm:text-xl
                  lg:text-2xl
                  font-black
                  tracking-tight
                  text-blue-950
                  capitalize
                  truncate
                  max-w-[150px]
                  sm:max-w-xs
                  lg:max-w-none
                "
              >
                {getPageTitle()}
              </h2>

              <p className="hidden sm:flex text-slate-400 text-[9px] lg:text-[10px] font-bold uppercase tracking-[0.15em] lg:tracking-[0.2em] mt-1 items-center gap-2">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse shrink-0" />

                System Online:

                <span className="text-blue-600 truncate max-w-[100px] lg:max-w-[180px]">
                  {landlordName}
                </span>
              </p>
            </div>
          </div>

          {/* RIGHT */}
          <div className="flex items-center gap-2 sm:gap-3 lg:gap-4 shrink-0">
            {/* DESKTOP SEARCH */}
            <div className="hidden md:block relative group">
              <Search
                className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-300"
                size={16}
              />

              <input
                type="text"
                placeholder="Global System Search..."
                className="
                  bg-blue-50/50
                  border
                  border-blue-100
                  pl-11
                  pr-4
                  py-2.5
                  rounded-xl
                  outline-none
                  w-52
                  lg:w-80
                  text-sm
                  focus:bg-white
                  focus:border-blue-400
                  transition-all
                  placeholder-blue-300
                  font-medium
                  shadow-inner
                  shadow-blue-50/50
                "
              />
            </div>

            {/* MOBILE SEARCH */}
            <button
              className="
                md:hidden
                p-2
                sm:p-2.5
                bg-white
                border
                border-blue-100
                rounded-xl
                text-blue-400
                hover:text-blue-600
                transition-all
                shadow-sm
              "
            >
              <Search size={17} />
            </button>

            {/* NOTIFICATIONS */}
            <Link
              href="/landlord/notifications"
              className="
                relative
                p-2
                sm:p-2.5
                bg-white
                border
                border-blue-100
                rounded-xl
                text-blue-400
                hover:text-blue-600
                transition-all
                shadow-sm
                block
              "
            >
              <Bell size={17} />

              {badges.notifications > 0 && (
                <span
                  className="
                    absolute
                    top-1.5
                    right-1.5
                    sm:top-2
                    sm:right-2.5
                    w-2
                    h-2
                    sm:w-2.5
                    sm:h-2.5
                    bg-rose-500
                    rounded-full
                    border-2
                    border-white
                    animate-pulse
                  "
                />
              )}
            </Link>
          </div>
        </header>

        {/* PAGE CONTENT */}
        <div
          className="
            w-full
            max-w-7xl
            mx-auto
            px-3
            py-4
            sm:px-5
            sm:py-6
            lg:px-10
            lg:py-10
          "
        >
          {children}
        </div>
      </main>
    </div>
  );
} 
