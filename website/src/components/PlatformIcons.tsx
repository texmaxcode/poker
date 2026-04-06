/**
 * Windows and macOS marks for marketing copy (generic window grid + apple silhouette).
 * Static SVGs also live in /public/icons/ for transactional email &lt;img&gt; tags.
 */

export function WindowsIcon({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M1 3h10v10H1V3zm12 0h10v10H13V3zM1 15h10v10H1V15zm12 0h10v10H13V15z" />
    </svg>
  );
}

export function MacIcon({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

/** Inline label: icon + “Windows” · icon + “macOS” */
export function PlatformWindowsMacLabel({
  className = "",
  iconClassName = "w-3.5 h-3.5 text-[#c4b8b0]",
}: {
  className?: string;
  iconClassName?: string;
}) {
  return (
    <span className={`inline-flex items-center gap-2 flex-wrap ${className}`}>
      <span className="inline-flex items-center gap-1" title="Windows">
        <WindowsIcon className={iconClassName} />
        <span>Windows</span>
      </span>
      <span className="text-[#5c5048] select-none">·</span>
      <span className="inline-flex items-center gap-1" title="macOS">
        <MacIcon className={iconClassName} />
        <span>macOS</span>
      </span>
    </span>
  );
}
