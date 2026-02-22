// ============================================================
// Button Component
// Kaynak: main_theme.tres ButtonNormal/Hover/Pressed/Disabled
// ============================================================

"use client";

import { forwardRef } from "react";
import { motion } from "framer-motion";
import { cn } from "@/lib/utils/cn";

type ButtonVariant = "primary" | "secondary" | "danger" | "ghost" | "gold";
type ButtonSize = "sm" | "md" | "lg";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  isLoading?: boolean;
  fullWidth?: boolean;
}

const variantClasses: Record<ButtonVariant, string> = {
  primary:
    "bg-[var(--accent)] hover:bg-[var(--accent-light)] active:bg-[var(--accent-dark)] text-white border-[var(--accent-light)]",
  secondary:
    "bg-[var(--bg-elevated)] hover:bg-[var(--border-default)] active:bg-[var(--bg-card)] text-[var(--text-primary)] border-[var(--border-default)]",
  danger:
    "bg-[var(--color-error)] hover:bg-red-500 active:bg-red-700 text-white border-red-400",
  ghost:
    "bg-transparent hover:bg-[var(--bg-elevated)] text-[var(--text-secondary)] border-transparent",
  gold:
    "bg-gradient-to-r from-yellow-700 to-yellow-500 hover:from-yellow-600 hover:to-yellow-400 text-black border-yellow-400",
};

const sizeClasses: Record<ButtonSize, string> = {
  sm: "px-3 py-1.5 text-xs rounded-md",
  md: "px-4 py-2 text-sm rounded-lg",
  lg: "px-6 py-3 text-base rounded-xl",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      variant = "primary",
      size = "md",
      isLoading = false,
      fullWidth = false,
      className,
      disabled,
      children,
      onClick,
      ...props
    },
    ref
  ) => {
    return (
      <motion.button
        ref={ref}
        whileTap={{ scale: disabled || isLoading ? 1 : 0.97 }}
        className={cn(
          "font-medium border transition-colors duration-150 flex items-center justify-center gap-2",
          variantClasses[variant],
          sizeClasses[size],
          fullWidth && "w-full",
          (disabled || isLoading) && "opacity-50 cursor-not-allowed",
          className
        )}
        disabled={disabled || isLoading}
        onClick={onClick}
        {...(props as React.ComponentPropsWithoutRef<typeof motion.button>)}
      >
        {isLoading && (
          <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
        )}
        {children}
      </motion.button>
    );
  }
);

Button.displayName = "Button";
