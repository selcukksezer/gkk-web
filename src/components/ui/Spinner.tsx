// ============================================================
// Loading Spinner
// ============================================================

import { cn } from "@/lib/utils/cn";

interface SpinnerProps {
  size?: "sm" | "md" | "lg";
  className?: string;
}

const sizeClasses = {
  sm: "w-4 h-4 border-2",
  md: "w-8 h-8 border-3",
  lg: "w-12 h-12 border-4",
};

export function Spinner({ size = "md", className }: SpinnerProps) {
  return (
    <div
      className={cn(
        "rounded-full border-[var(--border-light)] border-t-[var(--accent)] animate-spin",
        sizeClasses[size],
        className
      )}
    />
  );
}

export function LoadingScreen({ message }: { message?: string }) {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen gap-4">
      <Spinner size="lg" />
      {message && (
        <p className="text-sm text-[var(--text-secondary)]">{message}</p>
      )}
    </div>
  );
}
