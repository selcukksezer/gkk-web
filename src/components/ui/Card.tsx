// ============================================================
// Card Component — Panel/Container 
// Kaynak: main_theme.tres PanelStyle
// ============================================================

import { cn } from "@/lib/utils/cn";

interface CardProps {
  children: React.ReactNode;
  className?: string;
  variant?: "default" | "elevated" | "bordered";
  onClick?: () => void;
}

export function Card({
  children,
  className,
  variant = "default",
  onClick,
}: CardProps) {
  const variants = {
    default: "bg-[var(--bg-card)]",
    elevated: "bg-[var(--bg-elevated)] shadow-lg",
    bordered: "bg-[var(--bg-card)] border border-[var(--border-default)]",
  };

  return (
    <div
      className={cn(
        "rounded-xl p-4",
        variants[variant],
        onClick && "cursor-pointer hover:brightness-110 transition-all",
        className
      )}
      onClick={onClick}
    >
      {children}
    </div>
  );
}
